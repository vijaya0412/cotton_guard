"""
Cotton Guard - Service State & Administrator Control Plane Automated Test Suite.
Verifies:
1. Health endpoint reflects service state accurately.
2. Admin control endpoints (/admin/service/state, /start, /stop, /logs).
3. Service STOPPED state rejects predictions with HTTP 503.
4. Service STARTING/RUNNING transition restores inference capability.
5. Audit logs are persisted in SQLite across state transitions.
6. Authorization guards reject unauthorized or unauthenticated requests.
"""

import os
import io
import pytest
from PIL import Image
from fastapi.testclient import TestClient

from backend.main import app
from backend.service_state import service_state, ServiceState
from backend.database import init_database

TEST_ADMIN_KEY = "test-cotton-guard-secure-admin-key-2026"

@pytest.fixture(scope="module")
def client():
    os.environ["ADMIN_API_KEY"] = TEST_ADMIN_KEY
    init_database()
    return TestClient(app)

@pytest.fixture
def admin_headers():
    return {"X-Admin-Key": TEST_ADMIN_KEY}

def test_initial_health_and_service_state(client):
    # Ensure initially RUNNING
    resp = client.get("/api/v1/health")
    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "CONNECTED"
    assert data["disease_model_ready"] is True
    assert data["model_loaded"] is True

def test_admin_unauthenticated_requests_fail_closed(client):
    # Every admin endpoint must strictly reject unauthenticated requests with HTTP 403
    for path in [
        "/api/v1/admin/service/state",
        "/api/v1/admin/service/logs"
    ]:
        resp = client.get(path)
        assert resp.status_code == 403
        assert "administrator privilege required" in resp.json()["detail"].lower()

    for path in [
        "/api/v1/admin/service/start",
        "/api/v1/admin/service/stop"
    ]:
        resp = client.post(path)
        assert resp.status_code == 403
        assert "administrator privilege required" in resp.json()["detail"].lower()

def test_admin_get_state(client, admin_headers):
    resp = client.get("/api/v1/admin/service/state", headers=admin_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["success"] is True
    assert "service_status" in data
    assert data["service_status"]["is_running"] is True

def test_admin_stop_and_start_lifecycle(client, admin_headers):
    # 1. Stop service with valid admin credentials
    stop_resp = client.post("/api/v1/admin/service/stop", headers=admin_headers)
    assert stop_resp.status_code == 200
    stop_data = stop_resp.json()
    assert stop_data["success"] is True
    assert stop_data["state"] == "STOPPED"

    # 2. Verify health reports STOPPED
    health_resp = client.get("/api/v1/health")
    assert health_resp.status_code == 200
    health_data = health_resp.json()
    assert health_data["status"] == "STOPPED"
    assert health_data["disease_model_ready"] is False

    # 3. Verify predict endpoint returns HTTP 503
    fake_img = io.BytesIO()
    Image.new("RGB", (224, 224), color=(34, 139, 34)).save(fake_img, format="JPEG")
    fake_img.seek(0)

    pred_resp = client.post(
        "/api/v1/predict",
        files={"file": ("leaf.jpg", fake_img.getvalue(), "image/jpeg")}
    )
    assert pred_resp.status_code == 503
    assert "paused by the administrator" in pred_resp.json()["detail"].lower()

    # 4. Start service again with valid admin credentials
    start_resp = client.post("/api/v1/admin/service/start", headers=admin_headers)
    assert start_resp.status_code == 200
    start_data = start_resp.json()
    assert start_data["success"] is True
    assert start_data["state"] == "RUNNING"

    # 5. Verify health is restored to CONNECTED
    health_after = client.get("/api/v1/health")
    assert health_after.status_code == 200
    assert health_after.json()["status"] == "CONNECTED"
    assert health_after.json()["disease_model_ready"] is True

def test_admin_audit_logs_retrieval(client, admin_headers):
    resp = client.get("/api/v1/admin/service/logs", headers=admin_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["success"] is True
    assert "logs" in data
    assert len(data["logs"]) >= 2  # Stop and Start logged
    actions = [l["action"] for l in data["logs"]]
    assert "STOP_SERVICE" in actions
    assert "START_SERVICE" in actions
