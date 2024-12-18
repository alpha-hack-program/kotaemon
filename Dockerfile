# Lite version
FROM python:3.10-slim AS lite

# Common dependencies
RUN apt-get update -qqy && \
    apt-get install -y --no-install-recommends \
      ssh \
      git \
      gcc \
      g++ \
      poppler-utils \
      libpoppler-dev \
      unzip \
      curl \
      cargo

# Setup args
ARG TARGETPLATFORM
ARG TARGETARCH

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PYTHONIOENCODING=UTF-8
ENV TARGETARCH=${TARGETARCH}

# Create working directory
WORKDIR /app

# ALPHA: Adjust permissions for OpenShift's random user ID
RUN mkdir -p /app/libs && \
    mkdir -p /app/scripts && \
    chmod -R g+rwX /app && \
    chown -R 1001:0 /app

# Download pdfjs
COPY scripts/download_pdfjs.sh /app/scripts/download_pdfjs.sh
RUN chmod +x /app/scripts/download_pdfjs.sh
ENV PDFJS_PREBUILT_DIR="/app/libs/ktem/ktem/assets/prebuilt/pdfjs-dist"
RUN bash scripts/download_pdfjs.sh $PDFJS_PREBUILT_DIR

# Copy contents
COPY . /app
COPY .env.example /app/.env

# ALPHA: Adjust permissions after copying files
RUN chmod -R g+rwX /app && chown -R 1001:0 /app

# Install pip packages
RUN pip install -e "libs/kotaemon" \
    && pip install -e "libs/ktem" \
    && pip install "pdfservices-sdk@git+https://github.com/niallcm/pdfservices-python-sdk.git@bump-and-unfreeze-requirements"

RUN if [ "$TARGETARCH" = "amd64" ]; then pip install "graphrag<=0.3.6" future; fi

# ALPHA: we need kubernetes
RUN pip install kubernetes

# Clean up
RUN apt-get autoremove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf ~/.cache

CMD ["python", "app.py"]

# Full version
FROM lite AS full

# Additional dependencies for full version
RUN apt-get update -qqy && \
    apt-get install -y --no-install-recommends \
    tesseract-ocr \
    tesseract-ocr-jpn \
    libsm6 \
    libxext6 \
    libreoffice \
    ffmpeg \
    libmagic-dev

# Install torch and torchvision for unstructured
RUN pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu

# Install additional pip packages
RUN pip install -e "libs/kotaemon[adv]" \
    && pip install unstructured[all-docs]

# Install lightRAG
ENV USE_LIGHTRAG=true
RUN pip install aioboto3 nano-vectordb ollama xxhash "lightrag-hku<=0.0.8"

RUN pip install "docling<=2.5.2"

# Clean up
RUN apt-get autoremove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf ~/.cache

# Create required directories and set environment variables
RUN mkdir -p /app/nltk_data && chmod -R g+rwX /app/nltk_data
ENV NLTK_DATA=/app/nltk_data

# Download nltk packages as required for unstructured
# RUN python -c "from unstructured.nlp.tokenize import _download_nltk_packages_if_not_present; _download_nltk_packages_if_not_present()"
RUN python -m nltk.downloader averaged_perceptron_tagger_eng punkt_tab

# Set the working directory permissions to allow any assigned user
RUN chown -R 1001:0 /app && chmod -R g+rwX /app

CMD ["python", "app.py"]
