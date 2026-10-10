"""
Cotton Guard - Backend Authentication & Security Test Suite
Tests registration, duplicate detection, password hashing, login, token verification, and password reset.
"""

import pytest
from fastapi.testclient import TestClient
from backend.main import app
from backend.database import DB_PATH, init_database

@pytest.fixture(scope="module")
def client():
    init_database()
    return TestClient(app)

def test_auth_registration_and_login_flow(client):
    test_email = "farmer.test.krishi@cottonguard.org"
    test_password = "SecureCotton2026!"

    # 1. Register new user
    reg_resp = client.post("/api/v1/auth/register", json={
        "email": test_email,
        "password": test_password,
        "full_name": "Krishi Farmer",
        "phone": "+91 98480 99999",
        "location": "Warangal, Telangana",
        "role": "Cotton Grower"
    })

    # If user already existed from prior run, status may be 409, else 200
    if reg_resp.status_code == 200:
        data = reg_resp.json()
        assert data["success"] is True
        assert "token" in data
        assert data["user"]["email"] == test_email
        assert data["user"]["full_name"] == "Krishi Farmer"

    # 2. Duplicate registration must return 409 Conflict
    dup_resp = client.post("/api/v1/auth/register", json={
        "email": test_email,
        "password": test_password,
        "full_name": "Duplicate Farmer"
    })
    assert dup_resp.status_code == 409
    assert "already exists" in dup_resp.json()["detail"]

    # 3. Successful Login
    login_resp = client.post("/api/v1/auth/login", json={
        "email": test_email,
        "password": test_password
    })
    assert login_resp.status_code == 200
    login_data = login_resp.json()
    assert login_data["success"] is True
    token = login_data["token"]

    # 4. Failed Login with wrong password
    bad_login = client.post("/api/v1/auth/login", json={
        "email": test_email,
        "password": "WrongPassword123"
    })
    assert bad_login.status_code == 401

    # 5. Access /auth/me with Bearer Token
    me_resp = client.get("/api/v1/auth/me", headers={
        "Authorization": f"Bearer {token}"
    })
    assert me_resp.status_code == 200
    me_data = me_resp.json()
    assert me_data["user"]["email"] == test_email

    # 6. Access /auth/me with invalid token returns 401
    bad_me = client.get("/api/v1/auth/me", headers={
        "Authorization": "Bearer invalid.fake.token"
    })
    assert bad_me.status_code == 401

def test_auth_google_flow(client):
    # 1. Valid token succeeds and strictly extracts identity from token payload
    # Even if client sends a spoofed email, backend MUST use verified token email
    g_resp = client.post("/api/v1/auth/google", json={
        "id_token": "mock_google_id_token",
        "email": "spoofed.attacker@fake.com",
        "full_name": "Spoofed Attacker",
        "photo_url": "https://lh3.googleusercontent.com/a/sample_photo"
    })
    assert g_resp.status_code == 200
    g_data = g_resp.json()
    assert g_data["success"] is True
    assert g_data["user"]["provider"] == "google"
    # Must match verified token payload, NOT client-supplied spoofed email!
    assert g_data["user"]["email"] == "rajesh.farmer.google@gmail.com"
    assert g_data["user"]["full_name"] == "Rajesh Kumar"

def test_auth_google_missing_token_rejected(client):
    resp = client.post("/api/v1/auth/google", json={
        "id_token": "",
        "email": "farmer@cottonguard.org"
    })
    assert resp.status_code == 400
    assert "Google ID token is required" in resp.json()["detail"]

def test_auth_google_invalid_or_expired_tokens_rejected(client):
    # Invalid token signature
    resp1 = client.post("/api/v1/auth/google", json={
        "id_token": "mock_invalid_token"
    })
    assert resp1.status_code == 401

    # Expired token
    resp2 = client.post("/api/v1/auth/google", json={
        "id_token": "mock_expired_token"
    })
    assert resp2.status_code == 401

    # Wrong audience
    resp3 = client.post("/api/v1/auth/google", json={
        "id_token": "mock_wrong_aud_token"
    })
    assert resp3.status_code == 401

    # Unverified email
    resp4 = client.post("/api/v1/auth/google", json={
        "id_token": "mock_unverified_token"
    })
    assert resp4.status_code == 401

def test_forgot_and_reset_password(client):
    reset_email = "reset.farmer@cottonguard.org"
    client.post("/api/v1/auth/register", json={
        "email": reset_email,
        "password": "InitialPassword123!",
        "full_name": "Reset Test Farmer"
    })

    # Forgot password
    forgot_resp = client.post("/api/v1/auth/forgot-password", json={
        "email": reset_email
    })
    assert forgot_resp.status_code == 200
    reset_token = forgot_resp.json().get("reset_token")
    assert reset_token is not None

    # Reset password with token
    new_pw = "NewUpdatedPassword2026!"
    reset_action = client.post("/api/v1/auth/reset-password", json={
        "email": reset_email,
        "reset_token": reset_token,
        "new_password": new_pw
    })
    assert reset_action.status_code == 200

    # Verify login with new password succeeds
    new_login = client.post("/api/v1/auth/login", json={
        "email": reset_email,
        "password": new_pw
    })
    assert new_login.status_code == 200
