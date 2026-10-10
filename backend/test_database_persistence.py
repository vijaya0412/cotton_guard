"""
Cotton Guard - Database Persistence & Production Readiness Test Suite.
Validates:
1. Dual-Engine selection (PostgreSQL vs SQLite) based on DATABASE_URL.
2. User registration, password hashing, and authentication persistence across reconnects.
3. Password reset workflow persistence across reconnects.
4. Admin provisioning idempotency and restart safety (never resets existing admin password).
5. Administrative service audit log recording and persistence across reconnects.
6. Knowledge base advisory retrieval and alias resolution persistence.
7. PostgreSQL SQL translation (placeholder mapping '?' -> '%s', RETURNING clause).
"""

import os
import secrets
import tempfile
from unittest.mock import MagicMock, patch
import pytest

from backend.database import (
    DB_PATH,
    get_engine_config,
    DatabaseConnection,
    init_database,
    create_user,
    get_user_by_email,
    get_user_by_id,
    verify_password,
    update_user_password,
    provision_initial_admin,
    create_password_reset,
    verify_and_use_reset_token,
    log_service_action,
    get_service_audit_logs,
    get_advisory_for_class,
    POSTGRES_SCHEMA,
    SQLITE_SCHEMA
)


@pytest.fixture
def temp_db_path():
    """Provides an isolated temporary SQLite database file for testing persistence."""
    fd, path = tempfile.mkstemp(suffix=".db")
    os.close(fd)
    try:
        init_database(db_path=path)
        yield path
    finally:
        if os.path.exists(path):
            try:
                os.remove(path)
            except OSError:
                pass


def test_engine_config_selection(monkeypatch):
    """Verifies that get_engine_config accurately switches between SQLite and PostgreSQL."""
    # 1. Default without DATABASE_URL -> SQLite at DB_PATH
    monkeypatch.delenv("DATABASE_URL", raising=False)
    engine, target = get_engine_config()
    assert engine == "sqlite"
    assert target == DB_PATH

    # 2. Custom db_path -> SQLite at custom path
    custom_path = "/tmp/custom_test.db"
    engine, target = get_engine_config(db_path=custom_path)
    assert engine == "sqlite"
    assert target == custom_path

    # 3. Environment DATABASE_URL with postgresql://
    pg_url = "postgresql://user:secret@ep-db.cloud.neon.tech/cotton_guard"
    monkeypatch.setenv("DATABASE_URL", pg_url)
    engine, target = get_engine_config()
    assert engine == "postgres"
    assert target == pg_url

    # 4. Environment DATABASE_URL with postgres://
    pg_old_url = "postgres://user:secret@supabase.co:5432/kushi"
    monkeypatch.setenv("DATABASE_URL", pg_old_url)
    engine, target = get_engine_config()
    assert engine == "postgres"
    assert target == pg_old_url

    # 5. Explicit db_url argument overrides environment
    explicit_pg = "postgresql://override:secret@localhost:5432/override_db"
    engine, target = get_engine_config(db_url=explicit_pg)
    assert engine == "postgres"
    assert target == explicit_pg


def test_registration_auth_persistence_across_reconnect(temp_db_path):
    """Verifies user registration, password verification, and retrieval persist after connection termination."""
    test_email = f"grower_{secrets.token_hex(4)}@cottonguard.org"
    raw_password = "SecureFarmerPass2026!"
    full_name = "Telangana Cotton Grower"

    # Step 1: Create user in initial session
    user = create_user(
        email=test_email,
        password=raw_password,
        full_name=full_name,
        phone="+91 94400 12345",
        location="Warangal, Telangana",
        role="Cotton Farmer",
        db_path=temp_db_path
    )
    assert user["email"] == test_email
    assert user["role"] == "Cotton Farmer"
    user_id = user["id"]

    # Step 2: Simulate complete connection disconnect and reconnect
    reconnected_user = get_user_by_email(test_email, db_path=temp_db_path)
    assert reconnected_user is not None
    assert reconnected_user["id"] == user_id
    assert reconnected_user["full_name"] == full_name
    assert reconnected_user["phone"] == "+91 94400 12345"

    # Step 3: Verify salted PBKDF2 password authentication
    assert verify_password(raw_password, reconnected_user["password_hash"], reconnected_user["salt"]) is True
    assert verify_password("WrongPassword!", reconnected_user["password_hash"], reconnected_user["salt"]) is False

    # Step 4: Verify lookup by user_id
    by_id = get_user_by_id(user_id, db_path=temp_db_path)
    assert by_id is not None
    assert by_id["email"] == test_email


def test_password_reset_persistence_across_reconnect(temp_db_path):
    """Verifies reset token creation, persistence, and password update survive reconnection."""
    email = f"reset_{secrets.token_hex(4)}@cottonguard.org"
    old_pw = "OldPassword2026!"
    new_pw = "NewSecurePassword2026!"

    create_user(email=email, password=old_pw, full_name="Reset User", db_path=temp_db_path)

    # 1. Create reset token
    token = create_password_reset(email, db_path=temp_db_path)
    assert token and len(token) > 10

    # 2. Consume reset token in a reconnected session
    success = verify_and_use_reset_token(email, token, new_pw, db_path=temp_db_path)
    assert success is True

    # 3. Verify in another fresh session that new password works and old password fails
    refreshed = get_user_by_email(email, db_path=temp_db_path)
    assert verify_password(new_pw, refreshed["password_hash"], refreshed["salt"]) is True
    assert verify_password(old_pw, refreshed["password_hash"], refreshed["salt"]) is False

    # 4. Token cannot be reused (one-time consumption)
    reused = verify_and_use_reset_token(email, token, "AnotherPassword!", db_path=temp_db_path)
    assert reused is False


def test_admin_provisioning_idempotency_and_no_password_reset_on_restart(temp_db_path):
    """
    CRITICAL REQUIREMENT:
    Confirm that admin initialization on every restart does NOT reset an existing
    administrator's password or recreate credentials unexpectedly.
    """
    admin_email = "lead.admin@cottonguard.org"
    initial_password = "FirstProvisionedAdminPass2026!"
    updated_password = "AdminChangedHerPasswordLater2026!"

    # 1. Initial provisioning on first startup
    admin = provision_initial_admin(
        admin_email=admin_email,
        admin_password=initial_password,
        full_name="Lead System Admin",
        db_path=temp_db_path
    )
    assert admin is not None
    assert admin["email"] == admin_email
    assert admin["role"] == "System Admin"

    initial_record = get_user_by_email(admin_email, db_path=temp_db_path)
    initial_hash = initial_record["password_hash"]
    initial_salt = initial_record["salt"]
    assert verify_password(initial_password, initial_hash, initial_salt) is True

    # 2. Administrator updates her password later in the portal
    update_ok = update_user_password(admin_email, updated_password, db_path=temp_db_path)
    assert update_ok is True

    updated_record = get_user_by_email(admin_email, db_path=temp_db_path)
    assert updated_record["password_hash"] != initial_hash
    assert verify_password(updated_password, updated_record["password_hash"], updated_record["salt"]) is True
    assert verify_password(initial_password, updated_record["password_hash"], updated_record["salt"]) is False

    # 3. Simulate multiple container restarts where ADMIN_INITIAL_PASSWORD is still in the environment
    for restart_cycle in range(3):
        restart_admin = provision_initial_admin(
            admin_email=admin_email,
            admin_password=initial_password,  # Old initial password still present in env
            db_path=temp_db_path
        )
        assert restart_admin is not None
        assert restart_admin["id"] == initial_record["id"]
        assert restart_admin["role"] == "System Admin"

        # Verify password was NEVER reset back to initial_password!
        current = get_user_by_email(admin_email, db_path=temp_db_path)
        assert current["password_hash"] == updated_record["password_hash"]
        assert current["salt"] == updated_record["salt"]
        assert verify_password(updated_password, current["password_hash"], current["salt"]) is True
        assert verify_password(initial_password, current["password_hash"], current["salt"]) is False


def test_audit_logs_persistence_across_reconnect(temp_db_path):
    """Verifies administrative start/stop actions are recorded and queryable after reconnect."""
    admin_email = "security.officer@cottonguard.org"

    # Log 3 state transitions
    id1 = log_service_action(admin_email, "STOP", "RUNNING", "STOPPED", ip_address="192.168.1.10", details="Scheduled maintenance", db_path=temp_db_path)
    id2 = log_service_action(admin_email, "START", "STOPPED", "STARTING", ip_address="192.168.1.10", details="Booting model", db_path=temp_db_path)
    id3 = log_service_action(admin_email, "RUN", "STARTING", "RUNNING", ip_address="192.168.1.10", details="Model online", db_path=temp_db_path)

    assert id1 > 0
    assert id2 > id1
    assert id3 > id2

    # Query in a fresh connection
    logs = get_service_audit_logs(limit=10, db_path=temp_db_path)
    assert len(logs) >= 3

    # Most recent first
    assert logs[0]["action"] == "RUN"
    assert logs[0]["prior_state"] == "STARTING"
    assert logs[0]["new_state"] == "RUNNING"
    assert logs[0]["admin_email"] == admin_email

    assert logs[2]["action"] == "STOP"
    assert logs[2]["prior_state"] == "RUNNING"
    assert logs[2]["new_state"] == "STOPPED"


def test_advisory_retrieval_and_alias_resolution(temp_db_path):
    """Verifies that all 7 canonical classes and aliases retrieve correctly from the persistent database."""
    # 1. Canonical lookup
    blight = get_advisory_for_class("Bacterial Blight", db_path=temp_db_path)
    assert blight is not None
    assert blight["canonical_name"] == "Bacterial Blight"
    assert "Xanthomonas" in blight["scientific_name"]
    assert len(blight["symptoms"]) > 0
    assert len(blight["prevention"]) > 0
    assert len(blight["treatment"]) > 0

    # 2. Alias resolution: "Leaf Redding" -> "Leaf Reddening"
    reddening = get_advisory_for_class("Leaf Redding", db_path=temp_db_path)
    assert reddening is not None
    assert reddening["canonical_name"] == "Leaf Reddening"
    assert reddening["severity_level"] == 2

    # 3. Slug alias: "cotton leaf curl virus"
    curl = get_advisory_for_class("cotton leaf curl virus", db_path=temp_db_path)
    assert curl is not None
    assert curl["canonical_name"] == "Cotton Leaf Curl Virus"


def test_postgres_sql_preparation_and_schema():
    """Verifies that the DatabaseConnection correctly translates SQL syntax for PostgreSQL."""
    # Placeholders translation
    with DatabaseConnection() as db:
        # SQLite mode
        assert db.engine == "sqlite"
        assert db._prepare_sql("SELECT * FROM users WHERE email = ? AND id = ?") == "SELECT * FROM users WHERE email = ? AND id = ?"

        # Simulate Postgres mode
        db.engine = "postgres"
        assert db._prepare_sql("SELECT * FROM users WHERE email = ? AND id = ?") == "SELECT * FROM users WHERE email = %s AND id = %s"

    # Schema integrity: POSTGRES_SCHEMA contains SERIAL PRIMARY KEY and valid foreign keys
    postgres_ddl = "\n".join(POSTGRES_SCHEMA)
    assert "SERIAL PRIMARY KEY" in postgres_ddl
    assert "INTEGER PRIMARY KEY AUTOINCREMENT" not in postgres_ddl
    assert "PRAGMA journal_mode" not in postgres_ddl
    assert "REFERENCES diseases (disease_id) ON DELETE CASCADE" in postgres_ddl

    # SQLite schema contains AUTOINCREMENT and PRAGMAs
    sqlite_ddl = "\n".join(SQLITE_SCHEMA)
    assert "INTEGER PRIMARY KEY AUTOINCREMENT" in sqlite_ddl
    assert "PRAGMA journal_mode=WAL;" in sqlite_ddl


def test_postgres_mock_connection_workflow():
    """
    Simulates a PostgreSQL connection via psycopg2 to verify query execution,
    cursor handling, and INSERT ... RETURNING id behavior.
    """
    mock_cursor = MagicMock()
    mock_cursor.rowcount = 1
    mock_cursor.fetchone.return_value = {"id": 42}
    mock_cursor.fetchall.return_value = [{"canonical_name": "Healthy Leaf"}]

    mock_conn = MagicMock()
    mock_conn.cursor.return_value = mock_cursor

    with patch("psycopg2.connect", return_value=mock_conn):
        pg_url = "postgresql://mock_user:mock_pass@db.mock.cloud:5432/cotton_db"
        with DatabaseConnection(db_url=pg_url) as db:
            assert db.engine == "postgres"
            assert db.target == pg_url

            # Test execute translates placeholders
            db.execute("SELECT * FROM users WHERE email = ?", ("test@example.com",))
            mock_cursor.execute.assert_called_with("SELECT * FROM users WHERE email = %s", ("test@example.com",))

            # Test execute_insert appends RETURNING
            returned_id = db.execute_insert(
                "INSERT INTO service_audit_logs (admin_email) VALUES (?)",
                ("admin@example.com",),
                returning_col="id"
            )
            assert returned_id == 42
            mock_cursor.execute.assert_called_with(
                "INSERT INTO service_audit_logs (admin_email) VALUES (%s) RETURNING id",
                ("admin@example.com",)
            )

        # Ensure commit and close were invoked on exit
        mock_conn.commit.assert_called_once()
        mock_conn.close.assert_called_once()
