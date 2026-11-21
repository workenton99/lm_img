FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    OLLAMA_HOST=0.0.0.0:11434 \
    OLLAMA_MODELS=/workspace/ollama/models \
    DATA_DIR=/workspace/openwebui \
    PORT=8080

# 1. Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.11 python3.11-venv python3-pip \
    git curl wget ca-certificates supervisor \
    ffmpeg libgl1 libglib2.0-0 zstd jq \
    && rm -rf /var/lib/apt/lists/*

# 2. Install Ollama
RUN curl -fsSL https://ollama.com/install.sh | sh

# 3. Install ComfyUI in an isolated virtual environment
RUN git clone --depth 1 https://github.com/Comfy-Org/ComfyUI /opt/comfyui && \
    python3.11 -m venv /opt/comfyui/venv && \
    /opt/comfyui/venv/bin/pip install --no-cache-dir --upgrade pip && \
    /opt/comfyui/venv/bin/pip install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128/ && \
    /opt/comfyui/venv/bin/pip install --no-cache-dir -r /opt/comfyui/requirements.txt

# 4. Install Open WebUI in an isolated virtual environment
RUN python3.11 -m venv /opt/openwebui/venv && \
    /opt/openwebui/venv/bin/pip install --no-cache-dir --upgrade pip && \
    /opt/openwebui/venv/bin/pip install --no-cache-dir open-webui

# 5. Copy process manager and boot script
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8080 8188 11434

ENTRYPOINT ["/entrypoint.sh"]
