"""
Cotton Guard - Comprehensive Security Regression Test Suite.
Verifies Priority 1 security hardening:
1. Self-assigned privileged admin roles are strictly prohibited during public registration.
2. All public self-registered users receive the 'Cotton Farmer' role.
3. All admin endpoints fail closed when unauthenticated (no dev_admin bypass).
4. Invalid admin API keys and non-admin Bearer tokens are rejected with HTTP 403.
5. Missing or insecure signing secrets fail startup safely in production (RuntimeError).
6. Secure first-admin provisioning succeeds and allows authorized access via Bearer token.
"""

import os
import secrets
import pytest
from fastapi.testclient import TestClient

from backend.main import app
from backend.database import (
    init_database,
    get_secret_key,
    provision_initial_admin,
    get_user_by_email,
    create_user
)

TEST_API_KEY = "test-secret-admin-key-2026-verified"

@pytest.fixture(scope="module")
def client():
    os.environ["ADMIN_API_KEY"] = TEST_API_KEY
    init_database()
    return TestClient(app)

def test_self_assigned_admin_roles_prohibited(client):
    """Attack vector: Malicious user tries to self-register as System Admin or Admin."""
    for evil_role in ["System Admin", "Admin", "Administrator", "Super Admin", "system admin"]:
        resp = client.post("/api/v1/auth/register", json={
            "email": f"attacker_{secrets.token_hex(4)}@evil.com",
            "password": "AttackerPassword123!",
            "full_name": "Malicious Caller",
            "role": evil_role
        })
        assert resp.status_code == 403
        assert "prohibited" in resp.json()["detail"].lower()

def test_all_self_registered_users_receive_cotton_farmer_role(client):
    """Legitimate registration: Role is always assigned as 'Cotton Farmer'."""
    test_email = f"farmer_{secrets.token_hex(4)}@cottonguard.org"
    resp = client.post("/api/v1/auth/register", json={
        "email": test_email,
        "password": "FarmerPassword123!",
        "full_name": "Genuine Farmer",
        "role": "Cotton Specialist"
    })
    assert resp.status_code == 200
    user_data = resp.json()["user"]
    assert user_data["role"] == "Cotton Farmer"

    # Verify directly from database row
    db_user = get_user_by_email(test_email)
    assert db_user is not None
    assert db_user["role"] == "Cotton Farmer"

def test_unauthenticated_admin_endpoints_fail_closed(client):
    """Ensures no unauthenticated development bypass exists on admin plane."""
    admin_paths_get = [
        "/api/v1/admin/service/state",
        "/api/v1/admin/service/logs",
        "/admin/service/state",
        "/admin/service/logs"
    ]
    for path in admin_paths_get:
        resp = client.get(path)
        assert resp.status_code == 403
        assert "administrator privilege required" in resp.json()["detail"].lower()

    admin_paths_post = [
        "/api/v1/admin/service/start",
        "/api/v1/admin/service/stop",
        "/admin/service/start",
        "/admin/service/stop"
    ]
    for path in admin_paths_post:
        resp = client.post(path)
        assert resp.status_code == 403
        assert "administrator privilege required" in resp.json()["detail"].lower()

def test_invalid_admin_credentials_rejected(client):
    """Requests with wrong key or non-admin Bearer token must be rejected."""
    # 1. Invalid X-Admin-Key
    resp_bad_key = client.get(
        "/api/v1/admin/service/state",
        headers={"X-Admin-Key": "wrong-key-attempt"}
    )
    assert resp_bad_key.status_code == 403

    # 2. Bearer token of standard farmer user
    farmer_email = f"farmer_{secrets.token_hex(4)}@cottonguard.org"
    reg = client.post("/api/v1/auth/register", json={
        "email": farmer_email,
        "password": "FarmerPassword123!",
        "full_name": "Standard Farmer"
    })
    farmer_token = reg.json()["token"]

    resp_farmer_token = client.get(
        "/api/v1/admin/service/state",
        headers={"Authorization": f"Bearer {farmer_token}"}
    )
    assert resp_farmer_token.status_code == 403

def test_production_missing_secret_fails_safely(monkeypatch):
    """In production, missing or default signing key must raise RuntimeError."""
    monkeypatch.setenv("ENVIRONMENT", "production")

    # Empty key
    monkeypatch.setenv("COTTON_GUARD_SECRET_KEY", "")
    with pytest.raises(RuntimeError) as exc_info:
        get_secret_key()
    assert "COTTON_GUARD_SECRET_KEY" in str(exc_info.value)

    # Insecure default key from git
    monkeypatch.setenv("COTTON_GUARD_SECRET_KEY", "cotton-guard-prod-key-2026-auth-security-master")
    with pytest.raises(RuntimeError) as exc_info:
        get_secret_key()
    assert "insecure default" in str(exc_info.value)

    # Key too short (<32 chars)
    monkeypatch.setenv("COTTON_GUARD_SECRET_KEY", "short-secret")
    with pytest.raises(RuntimeError) as exc_info:
        get_secret_key()
    assert "min 32 characters" in str(exc_info.value)

    # Valid production key succeeds
    valid_key = secrets.token_hex(32)
    monkeypatch.setenv("COTTON_GUARD_SECRET_KEY", valid_key)
    assert get_secret_key() == valid_key

def test_secure_first_admin_provisioning_and_access(client, monkeypatch):
    """Verifies headless/CLI admin provisioning and Bearer token admin authorization."""
    admin_email = f"head_admin_{secrets.token_hex(4)}@cottonguard.org"
    admin_pw = "SecureMasterAdmin2026!"

    # Provision first administrator
    provisioned = provision_initial_admin(
        admin_email=admin_email,
        admin_password=admin_pw,
        full_name="Lead Agronomist Admin"
    )
    assert provisioned is not None
    assert provisioned["role"] == "System Admin"
    assert provisioned["email"] == admin_email

    # Sign in as administrator
    login_resp = client.post("/api/v1/auth/login", json={
        "email": admin_email,
        "password": admin_pw
    })
    assert login_resp.status_code == 200
    admin_token = login_resp.json()["token"]

    # Configure ADMIN_EMAIL to match
    monkeypatch.setenv("ADMIN_EMAIL", admin_email)

    # Access admin control plane with admin Bearer token
    state_resp = client.get(
        "/api/v1/admin/service/state",
        headers={"Authorization": f"Bearer {admin_token}"}
    )
    assert state_resp.status_code == 200
    data = state_resp.json()
    assert data["success"] is True
    assert data["admin_caller"] == admin_email
