#!/usr/bin/env bash
set -e

# 1. Create persistent directories on RunPod /workspace
mkdir -p /workspace/ollama/models \
         /workspace/openwebui \
         /workspace/comfyui/models/checkpoints \
         /workspace/comfyui/models/loras \
         /workspace/comfyui/models/vae \
         /workspace/comfyui/output

# Map ComfyUI model and output directories to /workspace
cat <<EOF > /opt/comfyui/extra_model_paths.yaml
runpod_workspace:
    base_path: /workspace/comfyui/
    checkpoints: models/checkpoints/
    loras: models/loras/
    vae: models/vae/
EOF

rm -rf /opt/comfyui/output && ln -s /workspace/comfyui/output /opt/comfyui/output

# 2. RTX 3090 (24 GB) VRAM handoff & optimization flags
export OLLAMA_BASE_URL="http://127.0.0.1:11434"
export OLLAMA_KEEP_ALIVE="30s"
export OLLAMA_FLASH_ATTENTION="1"
export OLLAMA_KV_CACHE_TYPE="q8_0"

# 3. Zero-setup Open WebUI <-> ComfyUI wiring (uses built-in SD/SDXL workflow automatically)
export ENABLE_IMAGE_GENERATION="True"
export IMAGE_GENERATION_ENGINE="comfyui"
export COMFYUI_BASE_URL="http://127.0.0.1:8188"
export IMAGE_GENERATION_MODEL="${IMAGE_GENERATION_MODEL:-model.safetensors}"
export IMAGE_SIZE="${IMAGE_SIZE:-1024x1024}"
export IMAGE_STEPS="${IMAGE_STEPS:-25}"
export ENABLE_SIGNUP="True"

# Optional: load a custom ComfyUI workflow JSON if placed in /workspace/workflow_api.json
if [ -f /workspace/workflow_api.json ]; then
  export COMFYUI_WORKFLOW="$(cat /workspace/workflow_api.json)"
fi

# 4. Background provisioning for uncensored LLM & diffusion checkpoint
provision_models() {
  until curl -sf http://127.0.0 >/dev/null; do
    sleep 2
  done

  IFS=',' read -ra MODELS <<< "${OLLAMA_AUTOPULL_MODELS:-huihui_ai/qwen2.5-abliterate:14b}"
  for model in "${MODELS[@]}"; do
    model=$(echo "$model" | xargs)
    if [ -n "$model" ]; then
      echo "[Provisioner] Pulling Ollama model: $model"
      ollama pull "$model"
    fi
  done

  TARGET_CKPT="/workspace/comfyui/models/checkpoints/${IMAGE_GENERATION_MODEL}"
  if [ -n "$CHECKPOINT_URL" ] && [ ! -f "$TARGET_CKPT" ]; then
    echo "[Provisioner] Downloading ComfyUI checkpoint to $TARGET_CKPT"
    wget -q --show-progress -O "$TARGET_CKPT" "$CHECKPOINT_URL"
  fi
}

provision_models &

# 5. Start supervisord in foreground
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
