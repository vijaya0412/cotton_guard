# Cotton Guard AI Inference Server - Production Dockerfile for Hugging Face Spaces
FROM python:3.12-slim

# Prevent Python from writing .pyc files and enable unbuffered output
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Install minimal OS dependencies for OpenCV headless, SQLite, Pillow, and health check
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1 \
    libglib2.0-0 \
    sqlite3 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user with UID 1000 matching Hugging Face Spaces runtime
RUN useradd -m -u 1000 user
ENV HOME=/home/user \
    PATH=/home/user/.local/bin:$PATH

WORKDIR /app

# Install Python requirements
COPY backend/requirements.txt /app/backend/requirements.txt
RUN pip install --no-cache-dir -r /app/backend/requirements.txt

# Copy application modules
COPY backend /app/backend
COPY ml /app/ml

# Create data and backup directories and ensure full ownership by non-root user 1000
RUN mkdir -p /var/data /var/backups && \
    chown -R 1000:1000 /app /var/data /var/backups && \
    chmod -R 775 /var/data /var/backups

# Production defaults for Hugging Face Spaces
ENV PORT=7860
ENV HOST=0.0.0.0
ENV SQLITE_DB_PATH=/var/data/advisory.db
ENV ONNX_MODEL_PATH=/app/ml/models/cotton_guard_model.onnx

EXPOSE 7860

# Run container as non-root user
USER 1000

# Health check against production endpoint on port 7860
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD curl -f http://localhost:7860/api/v1/health || exit 1

CMD ["python", "backend/run_server.py"]
