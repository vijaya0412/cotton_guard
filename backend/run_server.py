"""
Server runner script for Cotton Guard FastAPI Service.
Binds to 0.0.0.0:8000 so both local emulators (10.0.2.2:8000) and physical Android devices (LAN IP:8000) can connect.
"""

import os
import sys
import uvicorn

if __name__ == "__main__":
    host = os.environ.get("HOST", "0.0.0.0")
    port = int(os.environ.get("PORT", "7860"))
    print(f"[Cotton Guard] Starting FastAPI service on {host}:{port}...")
    backend_dir = os.path.dirname(os.path.abspath(__file__))
    if backend_dir not in sys.path:
        sys.path.insert(0, backend_dir)
    parent_dir = os.path.dirname(backend_dir)
    if parent_dir not in sys.path:
        sys.path.insert(0, parent_dir)
    uvicorn.run("backend.main:app", host=host, port=port, reload=False)
