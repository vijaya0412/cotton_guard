# 09 — Deployment & Cloud Infrastructure

This document provides a comprehensive technical overview of the containerization, cloud deployment architecture, free-tier hosting limits, and zero-budget operational strategy for **Cotton Guard**.

---

## 1. Cloud Infrastructure Architecture

Cotton Guard is deployed on a zero-budget cloud architecture leveraging free-tier hosting platforms:

```mermaid
flowchart TD
    subgraph Clients["Mobile Client Layer"]
        ANDROID["Cotton Guard Android App<br/>(com.cottonguard.app.cottonguard)"]
    end

    subgraph Hosting["Primary Cloud Host (Render.com)"]
        EDGE["Render Ingress & TLS Termination<br/>(https://cotton-guard.onrender.com)"]
        CONTAINER["Docker Linux Container (UID 1000)<br/>(512 MB RAM, Port 7860)"]
        FASTAPI["FastAPI Backend (Uvicorn)<br/>+ ONNX Runtime (CPU)"]
    end

    subgraph Database["External Cloud Persistence (Neon)"]
        NEON[("Neon Serverless PostgreSQL<br/>(DATABASE_URL via TLS)")]
    end

    subgraph Fallback["Alternate Cloud Host (Hugging Face Spaces)"]
        HF_SPACE["Docker Space (Port 7860)<br/>(2 vCPU, 16 GB RAM Free Tier)"]
    end

    ANDROID -->|HTTPS /api/v1| EDGE
    EDGE --> CONTAINER
    CONTAINER --> FASTAPI
    FASTAPI -->|psycopg2-binary (TLS)| NEON
    FASTAPI -.->|Ephemeral Fallback| LOCAL_DB[("Local SQLite /var/data/advisory.db")]
    ANDROID -.->|Optional Secondary Target| HF_SPACE
```

---

## 2. Dockerfile Specification

The production image is built using [`Dockerfile`](file:///E:/project/kushi/Dockerfile) optimized for non-root execution and minimal image size:

```dockerfile
# Cotton Guard AI Inference Server - Production Dockerfile
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

# Create non-root user with UID 1000 matching container hosting standards
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

# Create data directories and ensure ownership by user 1000
RUN mkdir -p /var/data /var/backups && \
    chown -R 1000:1000 /app /var/data /var/backups && \
    chmod -R 775 /var/data /var/backups

# Production defaults
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
```

---

## 3. Hugging Face Spaces & Render Hosting Comparison

| Architectural Feature | Render.com Web Services (Active) | Hugging Face Spaces (Compatible) |
| :--- | :--- | :--- |
| **Hosting Mode** | Web Service (Docker container) | Docker Space |
| **Public Endpoint** | `https://cotton-guard.onrender.com` | `https://{user}-{space}.hf.space` |
| **Exposed Port** | Binds to `$PORT` (7860 or 10000) | Strictly expects port `7860` |
| **Free CPU Allocation** | 0.1 vCPU (shared) | 2 vCPU (dedicated) |
| **Free RAM Limit** | **512 MB RAM** | **16 GB RAM** |
| **Inactivity Spin-Down** | Spins down after 15 min of inactivity | Sleeps after 48h of inactivity |
| **Cold-Start Latency** | 30 to 50 seconds | 10 to 20 seconds |
| **Persistent Storage** | Ephemeral (cleared on restart) | Ephemeral (unless persistent disk attached) |
| **Database Solution** | External Neon PostgreSQL via `DATABASE_URL` | External Neon PostgreSQL via `DATABASE_URL` |
| **README Metadata** | Standard markdown | Requires YAML frontmatter (`app_port: 7860`) |

---

## 4. Resource Budget & Memory Footprint

Because free-tier hosting imposes strict memory constraints (512 MB on Render):

```
┌────────────────────────────────────────────────────────┐
│ 512 MB RAM Free Tier Budget (Render.com)               │
├────────────────────────────┬───────────────────────────┤
│ Component                  │ Memory Allocation         │
├────────────────────────────┼───────────────────────────┤
│ Linux OS & Python Runtime  │ ~60 MB                    │
│ FastAPI + Uvicorn Core     │ ~50 MB                    │
│ ONNX Runtime Engine (Model)│ ~180 MB                   │
│ Preprocessing Buffers      │ ~30 MB                    │
│ Operational Headroom       │ ~192 MB (Safe Buffer)     │
└────────────────────────────┴───────────────────────────┘
```

### Memory Management Optimizations
1. **Headless OpenCV**: Uses `opencv-python-headless` (omits heavy X11/GUI libraries).
2. **Dynamic Unloading**: The administrative endpoint `POST /api/v1/admin/service/stop` sets `ORT_SESSION = None` and triggers `gc.collect()`, releasing ~180 MB of RAM during low-utilization windows.
3. **Streamed Upload Parsing**: Raw image files are capped at 15 MB and processed directly in memory without disk writes.

---

## 5. Docker Exclusion Rules ([`.dockerignore`](file:///E:/project/kushi/.dockerignore))

To keep container build times under 2 minutes and prevent credential leaks:
- Excludes multi-gigabyte raw datasets (`/dataset/`, `/scratch/`, `*.pt`, `*.keras`).
- Excludes Android build outputs (`/build/`, `/android/.gradle/`, `*.apk`).
- Excludes local environment files (`.env`, `.env.*`) and local databases (`*.db`, `*.sqlite`).
- Copies only `backend/`, `ml/`, and authoritative ONNX models into the container image.
