ARG WORKER_CUDA_VERSION=12.1.0
ARG BASE_IMAGE_VERSION=1.0.0preview
FROM runpod/worker-vllm:base-${BASE_IMAGE_VERSION}-cuda${WORKER_CUDA_VERSION} AS vllm-base
RUN apt-get update -y \
    && apt-get install -y python3-pip
# Install Python dependencies
COPY builder/requirements.txt /requirements.txt

RUN --mount=type=cache,target=/root/.cache/pip \
    python3 -m pip install --upgrade pip && \
    python3 -m pip install --upgrade -r /requirements.txt
# Setup for Option 2: Building the Image with the Model included
ARG MODEL_NAME="mistralai/Mistral-7B-Instruct-v0.2"
ARG TOKENIZER_NAME="mistralai/Mistral-7B-Instruct-v0.2"
ARG BASE_PATH="/runpod-volume"
ARG QUANTIZATION=""
ARG MODEL_REVISION=""
ARG TOKENIZER_REVISION=""
ARG MAX_NUM_SEQS=200
ARG SCHEDULER_DELAY_FACTOR=0.1
ARG MAX_MODEL_LEN=512
ENV MODEL_NAME=$MODEL_NAME \
    MODEL_REVISION=$MODEL_REVISION \
    TOKENIZER_NAME=$TOKENIZER_NAME \
    TOKENIZER_REVISION=$TOKENIZER_REVISION \
    BASE_PATH=$BASE_PATH \
    QUANTIZATION=$QUANTIZATION \
    HF_DATASETS_CACHE="${BASE_PATH}/huggingface-cache/datasets" \
    HUGGINGFACE_HUB_CACHE="${BASE_PATH}/huggingface-cache/hub" \
    HF_HOME="${BASE_PATH}/huggingface-cache/hub" \
    HF_HUB_ENABLE_HF_TRANSFER=1 \
    MAX_NUM_SEQS=$MAX_NUM_SEQS \
    SCHEDULER_DELAY_FACTOR=$SCHEDULER_DELAY_FACTOR \
    MAX_MODEL_LEN=$MAX_MODEL_LEN
ENV PYTHONPATH="/:/vllm-workspace"
COPY src/download_model.py /download_model.py
RUN --mount=type=secret,id=HF_TOKEN,required=false \
    if [ -f /run/secrets/HF_TOKEN ]; then \
        export HF_TOKEN=$(cat /run/secrets/HF_TOKEN); \
    fi && \
    if [ -n "$MODEL_NAME" ]; then \
        python3 /download_model.py; \
    fi
# Add source files

COPY src /src
# Remove download_model.py
RUN rm /download_model.py
# Start the handler
CMD ["python3", "/src/handler.py"]
