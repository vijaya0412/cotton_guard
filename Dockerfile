# Cotton Guard AI Inference Server - Production Dockerfile
FROM python:3.12-slim

# Prevent Python from writing .pyc files and enable unbuffered output
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Install minimal OS dependencies for OpenCV headless and Pillow
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1 \
    libglib2.0-0 \
    sqlite3 \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Python requirements
COPY backend/requirements.txt /app/backend/requirements.txt
RUN pip install --no-cache-dir -r /app/backend/requirements.txt

# Copy application modules
COPY backend /app/backend
COPY ml /app/ml

# Create persistent data and backup directories with open permissions for non-root runtimes
RUN mkdir -p /var/data /var/backups && chmod 777 /var/data /var/backups


# Production defaults
ENV PORT=8000
ENV HOST=0.0.0.0
ENV SQLITE_DB_PATH=/var/data/advisory.db
ENV ONNX_MODEL_PATH=/app/ml/models/cotton_guard_model.onnx

EXPOSE 8000

# Health check against production endpoint
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8000/api/v1/health || exit 1

CMD ["python", "backend/run_server.py"]
