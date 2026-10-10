"""
Cotton Guard - Knowledge Base, Advisory Engine & Dual-Engine Persistence Layer.
Implements Class-Based Database Retrieval for Disease Diagnosis & Agronomic Management.
Supports both SQLite (local development & ephemeral mode) and PostgreSQL (production persistence via DATABASE_URL).
"""

import os
import sqlite3
import hashlib
import secrets
import time
import base64
import json
import hmac
from typing import Dict, Any, List, Optional, Tuple

DB_PATH = os.environ.get(
    "SQLITE_DB_PATH",
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "advisory.db")
)

_DYNAMIC_DEV_SECRET: Optional[str] = None

def get_secret_key() -> str:
    """
    Authoritative retrieval of cryptographic signing secret.
    In production: strictly requires COTTON_GUARD_SECRET_KEY in environment and fails safely if absent or insecure.
    In development/testing: generates an ephemeral secure random 256-bit secret if unset.
    """
    global _DYNAMIC_DEV_SECRET
    env = os.environ.get("ENVIRONMENT", os.environ.get("ENV", "development")).strip().lower()
    configured = os.environ.get("COTTON_GUARD_SECRET_KEY", "").strip()

    if env in ["production", "prod"]:
        if not configured or configured == "cotton-guard-prod-key-2026-auth-security-master" or len(configured) < 32:
            raise RuntimeError(
                "CRITICAL SECURITY CONFIGURATION ERROR: COTTON_GUARD_SECRET_KEY environment variable "
                "is required in production (min 32 characters) and must not use an insecure default."
            )
        return configured

    if configured and configured != "cotton-guard-prod-key-2026-auth-security-master":
        return configured

    if _DYNAMIC_DEV_SECRET is None:
        _DYNAMIC_DEV_SECRET = secrets.token_hex(32)
    return _DYNAMIC_DEV_SECRET


def get_engine_config(db_path: Optional[str] = None, db_url: Optional[str] = None) -> Tuple[str, str]:
    """
    Determines active database engine ('sqlite' or 'postgres') and connection target.
    Priority:
    1. Explicit db_url argument starting with postgres:// or postgresql://
    2. Explicit db_path argument starting with postgres:// or postgresql://
    3. Custom db_path (different from default DB_PATH) -> SQLite on that custom path
    4. DATABASE_URL environment variable starting with postgres:// or postgresql://
    5. Default local SQLite file at DB_PATH
    """
    if db_url and (db_url.startswith("postgresql://") or db_url.startswith("postgres://")):
        return "postgres", db_url

    if db_path and (db_path.startswith("postgresql://") or db_path.startswith("postgres://")):
        return "postgres", db_path

    if db_path is not None and db_path != DB_PATH:
        return "sqlite", db_path

    env_url = os.environ.get("DATABASE_URL", "").strip()
    if env_url.startswith("postgresql://") or env_url.startswith("postgres://"):
        return "postgres", env_url

    return "sqlite", db_path or DB_PATH


class DatabaseConnection:
    """
    Context manager providing unified database access across SQLite and PostgreSQL (psycopg2).
    Automatically maps parameter placeholders ('?' -> '%s' for Postgres),
    normalizes dictionary cursors, and commits/rollbacks transactions safely.
    """
    def __init__(self, db_path: str = DB_PATH, db_url: Optional[str] = None):
        self.engine, self.target = get_engine_config(db_path, db_url)
        self.conn = None
        self.cursor = None

    def __enter__(self):
        if self.engine == "postgres":
            import psycopg2
            import psycopg2.extras
            self.conn = psycopg2.connect(self.target)
            self.cursor = self.conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        else:
            if self.target != ":memory:":
                os.makedirs(os.path.dirname(os.path.abspath(self.target)), exist_ok=True)
            self.conn = sqlite3.connect(self.target)
            self.conn.row_factory = sqlite3.Row
            self.cursor = self.conn.cursor()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        if self.conn:
            try:
                if exc_type is None:
                    self.conn.commit()
                else:
                    self.conn.rollback()
            finally:
                if self.cursor:
                    try:
                        self.cursor.close()
                    except Exception:
                        pass
                self.conn.close()

    def _prepare_sql(self, sql: str) -> str:
        if self.engine == "postgres":
            return sql.replace("?", "%s")
        return sql

    def execute(self, sql: str, params: tuple = ()):
        prep_sql = self._prepare_sql(sql)
        self.cursor.execute(prep_sql, params)
        return self.cursor

    def fetchone(self) -> Optional[Dict[str, Any]]:
        row = self.cursor.fetchone()
        if row is None:
            return None
        return dict(row)

    def fetchall(self) -> List[Dict[str, Any]]:
        rows = self.cursor.fetchall()
        return [dict(r) for r in rows]

    @property
    def rowcount(self) -> int:
        return self.cursor.rowcount if self.cursor else 0

    def execute_insert(self, sql: str, params: tuple = (), returning_col: Optional[str] = None) -> Any:
        """
        Executes INSERT query and returns generated primary key.
        PostgreSQL appends 'RETURNING <col>', SQLite retrieves cursor.lastrowid.
        """
        if self.engine == "postgres":
            sql_clean = sql.strip().rstrip(";")
            if returning_col and "RETURNING" not in sql_clean.upper():
                sql_clean = f"{sql_clean} RETURNING {returning_col}"
            prep_sql = self._prepare_sql(sql_clean)
            self.cursor.execute(prep_sql, params)
            if returning_col:
                row = self.cursor.fetchone()
                if row:
                    return row[returning_col] if isinstance(row, dict) else row[0]
            return None
        else:
            self.cursor.execute(sql, params)
            return self.cursor.lastrowid


# DDL Schema Definitions
SQLITE_SCHEMA = [
    "PRAGMA journal_mode=WAL;",
    "PRAGMA busy_timeout=5000;",
    """
    CREATE TABLE IF NOT EXISTS diseases (
        disease_id INTEGER PRIMARY KEY AUTOINCREMENT,
        canonical_name TEXT UNIQUE NOT NULL,
        scientific_name TEXT NOT NULL,
        description TEXT NOT NULL,
        is_healthy INTEGER NOT NULL DEFAULT 0,
        favorable_conditions TEXT
    );
    """,
    """
    CREATE TABLE IF NOT EXISTS symptoms (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        disease_id INTEGER NOT NULL,
        symptom TEXT NOT NULL,
        FOREIGN KEY (disease_id) REFERENCES diseases (disease_id) ON DELETE CASCADE
    );
    """,
    """
    CREATE TABLE IF NOT EXISTS prevention (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        disease_id INTEGER NOT NULL,
        recommendation TEXT NOT NULL,
        FOREIGN KEY (disease_id) REFERENCES diseases (disease_id) ON DELETE CASCADE
    );
    """,
    """
    CREATE TABLE IF NOT EXISTS treatment (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        disease_id INTEGER NOT NULL,
        treatment_type TEXT DEFAULT 'Chemical',
        recommendation TEXT NOT NULL,
        FOREIGN KEY (disease_id) REFERENCES diseases (disease_id) ON DELETE CASCADE
    );
    """,
    """
    CREATE TABLE IF NOT EXISTS severity (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        disease_id INTEGER NOT NULL,
        severity_level INTEGER NOT NULL,
        severity_label TEXT NOT NULL,
        description TEXT NOT NULL,
        FOREIGN KEY (disease_id) REFERENCES diseases (disease_id) ON DELETE CASCADE
    );
    """,
    """
    CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        email TEXT UNIQUE NOT NULL,
        password_hash TEXT,
        salt TEXT,
        full_name TEXT NOT NULL,
        phone TEXT DEFAULT '',
        location TEXT DEFAULT 'Warangal, Telangana',
        latitude REAL,
        longitude REAL,
        role TEXT DEFAULT 'Cotton Farmer',
        profile_image_url TEXT,
        provider TEXT DEFAULT 'email',
        created_at TEXT NOT NULL
    );
    """,
    """
    CREATE TABLE IF NOT EXISTS password_resets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT NOT NULL,
        reset_token TEXT NOT NULL,
        expires_at TEXT NOT NULL,
        used INTEGER DEFAULT 0
    );
    """,
    """
    CREATE TABLE IF NOT EXISTS service_audit_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp TEXT NOT NULL,
        admin_email TEXT NOT NULL,
        action TEXT NOT NULL,
        prior_state TEXT NOT NULL,
        new_state TEXT NOT NULL,
        ip_address TEXT DEFAULT '',
        details TEXT DEFAULT ''
    );
    """
]

POSTGRES_SCHEMA = [
    """
    CREATE TABLE IF NOT EXISTS diseases (
        disease_id SERIAL PRIMARY KEY,
        canonical_name TEXT UNIQUE NOT NULL,
        scientific_name TEXT NOT NULL,
        description TEXT NOT NULL,
        is_healthy INTEGER NOT NULL DEFAULT 0,
        favorable_conditions TEXT
    );
    """,
    """
    CREATE TABLE IF NOT EXISTS symptoms (
        id SERIAL PRIMARY KEY,
        disease_id INTEGER NOT NULL REFERENCES diseases (disease_id) ON DELETE CASCADE,
        symptom TEXT NOT NULL
    );
    """,
    """
    CREATE TABLE IF NOT EXISTS prevention (
        id SERIAL PRIMARY KEY,
        disease_id INTEGER NOT NULL REFERENCES diseases (disease_id) ON DELETE CASCADE,
        recommendation TEXT NOT NULL
    );
    """,
    """
    CREATE TABLE IF NOT EXISTS treatment (
        id SERIAL PRIMARY KEY,
        disease_id INTEGER NOT NULL REFERENCES diseases (disease_id) ON DELETE CASCADE,
        treatment_type TEXT DEFAULT 'Chemical',
        recommendation TEXT NOT NULL
    );
    """,
    """
    CREATE TABLE IF NOT EXISTS severity (
        id SERIAL PRIMARY KEY,
        disease_id INTEGER NOT NULL REFERENCES diseases (disease_id) ON DELETE CASCADE,
        severity_level INTEGER NOT NULL,
        severity_label TEXT NOT NULL,
        description TEXT NOT NULL
    );
    """,
    """
    CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        email TEXT UNIQUE NOT NULL,
        password_hash TEXT,
        salt TEXT,
        full_name TEXT NOT NULL,
        phone TEXT DEFAULT '',
        location TEXT DEFAULT 'Warangal, Telangana',
        latitude REAL,
        longitude REAL,
        role TEXT DEFAULT 'Cotton Farmer',
        profile_image_url TEXT,
        provider TEXT DEFAULT 'email',
        created_at TEXT NOT NULL
    );
    """,
    """
    CREATE TABLE IF NOT EXISTS password_resets (
        id SERIAL PRIMARY KEY,
        email TEXT NOT NULL,
        reset_token TEXT NOT NULL,
        expires_at TEXT NOT NULL,
        used INTEGER DEFAULT 0
    );
    """,
    """
    CREATE TABLE IF NOT EXISTS service_audit_logs (
        id SERIAL PRIMARY KEY,
        timestamp TEXT NOT NULL,
        admin_email TEXT NOT NULL,
        action TEXT NOT NULL,
        prior_state TEXT NOT NULL,
        new_state TEXT NOT NULL,
        ip_address TEXT DEFAULT '',
        details TEXT DEFAULT ''
    );
    """
]


def init_database(db_path: str = DB_PATH, db_url: Optional[str] = None):
    """Initializes schema and seeds Canonical Knowledge Base with idempotency across engines."""
    engine, target = get_engine_config(db_path, db_url)

    # Seed Data for 7 Canonical Classes
    seed_records = [
        {
            "canonical_name": "Healthy Leaf",
            "scientific_name": "Gossypium hirsutum L.",
            "description": "Vigorously growing cotton foliage free of pathogenic lesions, necrotic spotting, or vector feeding marks.",
            "is_healthy": 1,
            "favorable_conditions": "Balanced soil fertility, optimal soil moisture (field capacity 60-70%), and temperature between 25-32°C.",
            "symptoms": [
                "Uniform green chlorophyll pigmentation across leaf lamina",
                "Intact leaf margins and absence of downward/upward curling",
                "Normal petiole elongation without epinasty or fasciations",
                "Absence of insect honeydew, sooty mold, or necrotic angular spots"
            ],
            "prevention": [
                "Maintain recommended crop spacing (90x60 cm or 105x60 cm for Bt hybrids).",
                "Implement balanced NPK fertilization (120:60:60 kg/ha in 3 split doses).",
                "Monitor crops weekly using yellow sticky traps (10-15 per acre) for early vector detection."
            ],
            "treatment": [
                "No therapeutic chemical or bactericidal spray required.",
                "Apply prophylactic neem oil (1500 ppm @ 2-3 mL/L) during early vegetative flush.",
                "Ensure timely inter-cultivation and clean field borders."
            ],
            "severity_level": 1,
            "severity_label": "None (Healthy)",
            "severity_desc": "No crop damage or pathogenic threat detected. Maintain routine agronomic practices."
        },
        {
            "canonical_name": "Bacterial Blight",
            "scientific_name": "Xanthomonas citri pv. malvacearum (Smith)",
            "description": "Destructive bacterial foliar pathogen causing angular water-soaked leaf spots, vein blight, and black arm stem necrosis.",
            "is_healthy": 0,
            "favorable_conditions": "High relative humidity (>85%), warm temperatures (28-32°C), and splashing rain or sprinkler irrigation.",
            "symptoms": [
                "Small angular water-soaked leaf spots strictly bounded by veinlets",
                "Lesions turn dark brown to black and necrotic on upper leaf surface",
                "Systemic vein blight progressing down the petiole ('black arm' phase)",
                "Premature defoliation and boll infection with dark greasy spots"
            ],
            "prevention": [
                "Delint planting seeds with commercial sulphuric acid (100 mL/kg seed).",
                "Seed soaking with Streptocycline (100 mg/L) for 2 hours before sowing.",
                "Plant certified resistant Bt cultivars (e.g. resistant G. hirsutum hybrids).",
                "Avoid overhead sprinkler irrigation that facilitates bacterial splash dispersal."
            ],
            "treatment": [
                "Foliar spray of Copper Oxychloride 50 WP @ 2.5 g/L + Streptocycline @ 100 mg/L (1 g in 10 L water) at first spot onset.",
                "Repeat bactericidal spray after 12-15 days if humid or cloudy weather persists.",
                "Collect and burn infected shed leaves and plant residues to break inoculum cycle."
            ],
            "severity_level": 3,
            "severity_label": "Moderate to High",
            "severity_desc": "Bacterial inoculum spreads rapidly during rain. Prompt therapeutic bactericidal intervention required."
        },
        {
            "canonical_name": "Cotton Leaf Curl Virus",
            "scientific_name": "Cotton Leaf Curl Multan Virus (CLCuV) / Begomovirus",
            "description": "Devastating whitefly-transmitted virus causing severe leaf deformation, upward/downward curling, vein enation, and stunting.",
            "is_healthy": 0,
            "favorable_conditions": "High whitefly (Bemisia tabaci) populations, hot dry weather followed by monsoon flushes, presence of weed alternate hosts.",
            "symptoms": [
                "Upward or downward rolling and curling of terminal young leaves",
                "Thickening and darkening of main and secondary leaf veins",
                "Enation: cup-shaped leafy foliar outgrowths on underside of leaves",
                "Severe plant stunting, shortened internodes, and significant reduction in boll formation"
            ],
            "prevention": [
                "Eradicate alternate weed hosts (Parthenium hysterophorus, Abutilon indicum, Sida cordifolia) from field bunds.",
                "Grow certified CLCuV-tolerant hybrids recommended for your regional agricultural zone.",
                "Install yellow sticky traps @ 20/acre to monitor and trap adult whitefly vectors.",
                "Avoid late sowing; complete planting within the recommended agro-climatic window."
            ],
            "treatment": [
                "Target vector whiteflies: Spray Diafenthiuron 50% WP @ 1.25 g/L or Pyriproxyfen 10% EC @ 2 mL/L.",
                "For high whitefly nymph pressure: Apply Spiromesifen 22.9% SC @ 1 mL/L or Flonicamid 50 WG @ 0.4 g/L.",
                "Rogue out and bury severely stunted and deformed infected plants in the first 45 days after sowing."
            ],
            "severity_level": 4,
            "severity_label": "High to Critical",
            "severity_desc": "Viral infection cannot be cured once systemic. Immediate vector containment is critical to prevent field-wide epidemic."
        },
        {
            "canonical_name": "Herbicide Growth Damage",
            "scientific_name": "Non-Pathogenic Chemical Phytotoxicity (2,4-D / Glyphosate Drift)",
            "description": "Foliar physiological malformations caused by spray drift or soil residual toxicity from hormone-type selective or non-selective herbicides.",
            "is_healthy": 0,
            "favorable_conditions": "Herbicide application in adjacent fields during windy conditions (>10 km/h) or using contaminated spray equipment.",
            "symptoms": [
                "Leaf cupping, severe strapping, and elongation into 'strap' or 'duck-foot' patterns",
                "Parallel vein development and puckering of leaf blade",
                "Stem twisting, epinasty, and severe distortion of emerging apical terminals",
                "Chlorotic leaf yellowing and temporary cessation of terminal vegetative growth"
            ],
            "prevention": [
                "Never spray hormone herbicides (2,4-D, dicamba, triclopyr) anywhere near broadleaf cotton crops.",
                "Dedicate exclusive separate spray tanks and nozzles for herbicides and insecticides/fungicides.",
                "Use drift reduction nozzles and low pressure (<2 bar) when spraying near cotton field margins.",
                "Install physical vegetative barrier rows (e.g. sorghum or maize border rows)."
            ],
            "treatment": [
                "Foliar spray of 19:19:19 water-soluble fertilizer @ 5 g/L + Gibberellic Acid (GA3 @ 10-20 ppm) to stimulate recovery.",
                "Apply humic acid (12% @ 3 mL/L) with light furrow irrigation to support root vigor and flush toxins.",
                "Avoid additional systemic pesticide stress until plants produce two sets of normal recovery leaves."
            ],
            "severity_level": 3,
            "severity_label": "Moderate",
            "severity_desc": "Abiotic injury. Plants often recover if terminal growing point survived drift exposure."
        },
        {
            "canonical_name": "Leaf Hopper / Jassids",
            "scientific_name": "Amrasca biguttula biguttula (Ishida)",
            "description": "Major sucking pest causing leaf hopper burn, marginal chlorosis, downward leaf cupping, and necrotic marginal drying.",
            "is_healthy": 0,
            "favorable_conditions": "Warm humid weather (25-30°C, RH 70-85%), excessive vegetative succulence induced by heavy nitrogen fertilizer.",
            "symptoms": [
                "Downward cupping and curling of leaf margins ('inverted cup' appearance)",
                "Marginal leaf yellowing starting at leaf tips and edges",
                "Progression to brick-red marginal burn ('hopper burn') and necrotic edge browning",
                "Tiny greenish-yellow wedge-shaped nymphs running diagonally on leaf underside"
            ],
            "prevention": [
                "Plant hairy/pubescent cotton cultivars which offer natural resistance to jassid oviposition.",
                "Seed treatment with Imidacloprid 70 WS @ 7 g/kg or Thiamethoxam 70 WS @ 4 g/kg seed.",
                "Avoid excessive split doses of urea/nitrogen that create tender succulent leaves.",
                "Encourage predatory chrysoperla and ladybird beetles by maintaining flowering border crops."
            ],
            "treatment": [
                "At Economic Threshold Level (ETL: 1-2 jassids/leaf): Spray Flonicamid 50 WG @ 0.3-0.4 g/L.",
                "Alternative effective option: Spray Dinotefuran 20% SG @ 0.3 g/L or Thiamethoxam 25 WG @ 0.25 g/L.",
                "Organic option: Spray Neem oil (10,000 ppm @ 2 mL/L) or NSKE 5% upon early nymph appearance."
            ],
            "severity_level": 3,
            "severity_label": "Moderate to High",
            "severity_desc": "Severe hopper burn can reduce photosynthetic area by up to 50%. ETL-guided insecticidal spray advised."
        },
        {
            "canonical_name": "Leaf Reddening",
            "scientific_name": "Physiological Anthocyanosis & Nutrient Deficiency",
            "description": "Premature physiological reddening of cotton leaves triggered by magnesium/nitrogen deficiency, cold stress, and waterlogging.",
            "is_healthy": 0,
            "favorable_conditions": "Sudden temperature drops in October-November, soil waterlogging, high boll load causing carbohydrate mobilization, light sandy soils.",
            "symptoms": [
                "Interveinal leaf tissue turns bronze then deep purplish-red while main veins remain greenish",
                "Symptoms begin on older lower leaves and progress upward during peak boll development",
                "Leaves turn brittle, curl downwards, and shed prematurely",
                "Reduced boll size and poor seed-cotton lint maturation"
            ],
            "prevention": [
                "Ensure proper soil drainage to avoid root hypoxia and root rot during late monsoons.",
                "Incorporate organic manure / FYM @ 5 tonnes/acre to enhance nutrient buffering capacity.",
                "Basal soil application of Magnesium Sulphate @ 10-15 kg/acre in light and red chalka soils.",
                "Ensure timely split application of nitrogen and potassium up to peak flowering stage."
            ],
            "treatment": [
                "Foliar spray of 1% Magnesium Sulphate (MgSO4 @ 10 g/L) + 1% Urea (10 g/L) at first reddening onset.",
                "Repeat foliar spray after 10-12 days during boll development stage.",
                "Apply Potassium Nitrate (13:0:45 @ 10 g/L) to supply readily assimilable nitrogen and potassium."
            ],
            "severity_level": 2,
            "severity_label": "Mild to Moderate",
            "severity_desc": "Physiological condition. Reversible if foliar magnesium and nitrogen are supplied before leaf brittleness."
        },
        {
            "canonical_name": "Leaf Variegation",
            "scientific_name": "Genetic & Physiological Chlorosis / Chimera",
            "description": "Non-pathogenic genetic sectoral variegation characterized by sharp white, cream, or pale-yellow patches interspersed with green leaf tissue.",
            "is_healthy": 0,
            "favorable_conditions": "Genetic mutation in plastid DNA, hybrid chimera expression, or localized micronutrient (Zinc/Iron) metabolic blocks.",
            "symptoms": [
                "Sharp geometric or sectoral white/cream/yellow patches on leaf surface",
                "Absence of necrotic margins, bacterial water-soaking, or vector feeding punctures",
                "Symptom localized to specific branches or individual leaves without spreading to adjacent plants",
                "Normal leaf turgor and normal vegetative growth on unaffected green sectors"
            ],
            "prevention": [
                "Use certified hybrid cotton seed lots from verified seed breeders.",
                "Test soil micronutrient status; apply Zinc Sulphate @ 10 kg/acre if zinc deficiency is confirmed.",
                "No quarantine or isolation measures required since the condition is non-infectious."
            ],
            "treatment": [
                "No bactericidal, fungicidal, or insecticidal chemical treatment is required.",
                "If accompanied by interveinal yellowing: Foliar spray of Chelated Micronutrient Mixture @ 1.5 g/L.",
                "Continue standard fertilization and irrigation; monitor plant for general boll setting."
            ],
            "severity_level": 1,
            "severity_label": "Low",
            "severity_desc": "Benign non-infectious foliar anomaly. No crop loss expected under standard agronomic management."
        }
    ]

    with DatabaseConnection(db_path=db_path, db_url=db_url) as db:
        schema = SQLITE_SCHEMA if db.engine == "sqlite" else POSTGRES_SCHEMA
        for statement in schema:
            db.execute(statement)

        for rec in seed_records:
            db.execute("""
            INSERT INTO diseases (canonical_name, scientific_name, description, is_healthy, favorable_conditions)
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT (canonical_name) DO UPDATE SET
                scientific_name = EXCLUDED.scientific_name,
                description = EXCLUDED.description,
                is_healthy = EXCLUDED.is_healthy,
                favorable_conditions = EXCLUDED.favorable_conditions
            """, (rec["canonical_name"], rec["scientific_name"], rec["description"], rec["is_healthy"], rec["favorable_conditions"]))

            db.execute("SELECT disease_id FROM diseases WHERE canonical_name = ?", (rec["canonical_name"],))
            d_row = db.fetchone()
            disease_id = d_row["disease_id"]

            # Clear and refresh relations
            db.execute("DELETE FROM symptoms WHERE disease_id = ?", (disease_id,))
            db.execute("DELETE FROM prevention WHERE disease_id = ?", (disease_id,))
            db.execute("DELETE FROM treatment WHERE disease_id = ?", (disease_id,))
            db.execute("DELETE FROM severity WHERE disease_id = ?", (disease_id,))

            for s in rec["symptoms"]:
                db.execute("INSERT INTO symptoms (disease_id, symptom) VALUES (?, ?)", (disease_id, s))

            for p in rec["prevention"]:
                db.execute("INSERT INTO prevention (disease_id, recommendation) VALUES (?, ?)", (disease_id, p))

            for t in rec["treatment"]:
                db.execute("INSERT INTO treatment (disease_id, recommendation) VALUES (?, ?)", (disease_id, t))

            db.execute("""
            INSERT INTO severity (disease_id, severity_level, severity_label, description)
            VALUES (?, ?, ?, ?)
            """, (disease_id, rec["severity_level"], rec["severity_label"], rec["severity_desc"]))

    print(f"[{engine.upper()}] Knowledge Base initialized at {target} with {len(seed_records)} canonical conditions.")

    # Validate secret key policy early on startup
    env = os.environ.get("ENVIRONMENT", os.environ.get("ENV", "development")).strip().lower()
    if env in ["production", "prod"]:
        get_secret_key()

    # Automatically provision designated administrator if credentials configured
    provision_initial_admin(db_path=db_path, db_url=db_url)


# Common disease aliases mapped to canonical names
CLASS_ALIASES = {
    "bacterial_blight": "Bacterial Blight",
    "bacterial blight": "Bacterial Blight",
    "curl_virus": "Cotton Leaf Curl Virus",
    "curl virus": "Cotton Leaf Curl Virus",
    "cotton leaf curl virus": "Cotton Leaf Curl Virus",
    "cotton leaf curl": "Cotton Leaf Curl Virus",
    "healthy_leaf": "Healthy Leaf",
    "healthy leaf": "Healthy Leaf",
    "healthy": "Healthy Leaf",
    "herbicide_damage": "Herbicide Growth Damage",
    "herbicide growth damage": "Herbicide Growth Damage",
    "herbicide damage": "Herbicide Growth Damage",
    "leaf_hopper_jassids": "Leaf Hopper / Jassids",
    "leaf hopper / jassids": "Leaf Hopper / Jassids",
    "leaf hopper jassids": "Leaf Hopper / Jassids",
    "jassids": "Leaf Hopper / Jassids",
    "leaf hopper": "Leaf Hopper / Jassids",
    "leaf_reddening": "Leaf Reddening",
    "leaf reddening": "Leaf Reddening",
    "leaf redding": "Leaf Reddening",
    "leaf_redding": "Leaf Reddening",
    "leaf_variegation": "Leaf Variegation",
    "leaf variegation": "Leaf Variegation",
    "variegation": "Leaf Variegation",
}

def resolve_canonical_class(query_name: str) -> str:
    """Resolves arbitrary disease alias, folder slug, or typo to canonical class name."""
    clean = query_name.strip()
    return CLASS_ALIASES.get(clean.lower(), clean)

def get_advisory_for_class(
    canonical_class: str,
    db_path: str = DB_PATH,
    db_url: Optional[str] = None
) -> Optional[Dict[str, Any]]:
    """
    Class-Based Database Retrieval from Knowledge Base.
    Query: SELECT ... FROM ... WHERE canonical_name = ?
    Supports alias resolution and case-insensitive lookups across SQLite and PostgreSQL.
    """
    engine, target = get_engine_config(db_path, db_url)
    if engine == "sqlite" and target != ":memory:" and not os.path.exists(target):
        init_database(db_path=db_path, db_url=db_url)

    canonical_target = resolve_canonical_class(canonical_class)

    with DatabaseConnection(db_path=db_path, db_url=db_url) as db:
        db.execute("""
            SELECT disease_id, canonical_name, scientific_name, description, is_healthy, favorable_conditions
            FROM diseases
            WHERE canonical_name = ? OR LOWER(canonical_name) = LOWER(?)
        """, (canonical_target, canonical_target))
        d_row = db.fetchone()

        if not d_row:
            return None

        disease_id = d_row["disease_id"]

        # Fetch Symptoms
        db.execute("SELECT symptom FROM symptoms WHERE disease_id = ? ORDER BY id ASC", (disease_id,))
        symptoms = [r["symptom"] for r in db.fetchall()]

        # Fetch Prevention
        db.execute("SELECT recommendation FROM prevention WHERE disease_id = ? ORDER BY id ASC", (disease_id,))
        prevention = [r["recommendation"] for r in db.fetchall()]

        # Fetch Treatment
        db.execute("SELECT recommendation FROM treatment WHERE disease_id = ? ORDER BY id ASC", (disease_id,))
        treatment = [r["recommendation"] for r in db.fetchall()]

        # Fetch Severity
        db.execute("SELECT severity_level, severity_label, description FROM severity WHERE disease_id = ?", (disease_id,))
        s_row = db.fetchone()
        severity_level = s_row["severity_level"] if s_row else 1
        severity_label = s_row["severity_label"] if s_row else "Normal"
        severity_desc = s_row["description"] if s_row else ""

        return {
            "disease_id": disease_id,
            "canonical_name": d_row["canonical_name"],
            "scientific_name": d_row["scientific_name"],
            "summary": d_row["description"],
            "is_healthy": bool(d_row["is_healthy"]),
            "favorable_conditions": d_row["favorable_conditions"],
            "severity": severity_label,
            "severity_level": severity_level,
            "severity_desc": severity_desc,
            "symptoms": symptoms,
            "prevention": prevention,
            "treatment": treatment,
            "advisory": treatment  # Backward compatibility
        }

def get_all_advisories(db_path: str = DB_PATH, db_url: Optional[str] = None) -> Dict[str, Any]:
    """Retrieves full advisory catalog for all canonical classes."""
    engine, target = get_engine_config(db_path, db_url)
    if engine == "sqlite" and target != ":memory:" and not os.path.exists(target):
        init_database(db_path=db_path, db_url=db_url)

    with DatabaseConnection(db_path=db_path, db_url=db_url) as db:
        db.execute("SELECT canonical_name FROM diseases ORDER BY disease_id ASC")
        classes = [r["canonical_name"] for r in db.fetchall()]

    catalog = {}
    for c in classes:
        adv = get_advisory_for_class(c, db_path=db_path, db_url=db_url)
        if adv:
            catalog[c] = adv
    return catalog

# ==============================================================================
# SECURE USER AUTHENTICATION & SESSION MANAGEMENT
# ==============================================================================

def hash_password(password: str, salt: Optional[str] = None) -> Tuple[str, str]:
    """Generates PBKDF2-HMAC-SHA256 hash with 100,000 iterations and 128-bit salt."""
    if not salt:
        salt = secrets.token_hex(16)
    pw_hash = hashlib.pbkdf2_hmac(
        'sha256',
        password.encode('utf-8'),
        salt.encode('utf-8'),
        100000
    ).hex()
    return pw_hash, salt

def verify_password(password: str, pw_hash: str, salt: str) -> bool:
    """Verifies candidate password using constant-time string comparison."""
    candidate_hash, _ = hash_password(password, salt)
    return secrets.compare_digest(candidate_hash, pw_hash)

def generate_session_token(user_id: str, email: str) -> str:
    """Generates cryptographic HMAC-SHA256 signed session token."""
    payload = {
        "uid": user_id,
        "email": email,
        "exp": int(time.time()) + 30 * 86400  # 30 days validity
    }
    secret = get_secret_key()
    payload_b64 = base64.urlsafe_b64encode(json.dumps(payload).encode()).decode()
    signature = hmac.new(secret.encode(), payload_b64.encode(), hashlib.sha256).hexdigest()
    return f"{payload_b64}.{signature}"

def verify_session_token(token: str) -> Optional[Dict[str, Any]]:
    """Verifies session token authenticity and expiration."""
    try:
        parts = token.split(".")
        if len(parts) != 2:
            return None
        payload_b64, signature = parts
        secret = get_secret_key()
        expected = hmac.new(secret.encode(), payload_b64.encode(), hashlib.sha256).hexdigest()
        if not secrets.compare_digest(signature, expected):
            return None
        payload = json.loads(base64.urlsafe_b64decode(payload_b64.encode()).decode())
        if payload.get("exp", 0) < time.time():
            return None
        return payload
    except Exception:
        return None

def create_user(
    email: str,
    password: Optional[str],
    full_name: str,
    phone: str = "",
    location: str = "Warangal, Telangana",
    latitude: Optional[float] = None,
    longitude: Optional[float] = None,
    role: str = "Cotton Farmer",
    profile_image_url: Optional[str] = None,
    provider: str = "email",
    db_path: str = DB_PATH,
    db_url: Optional[str] = None
) -> Dict[str, Any]:
    """Creates a new user record with salted password hashing."""
    engine, target = get_engine_config(db_path, db_url)
    if engine == "sqlite" and target != ":memory:" and not os.path.exists(target):
        init_database(db_path=db_path, db_url=db_url)

    clean_email = email.strip().lower()
    user_id = f"usr_{secrets.token_hex(8)}"
    created_at = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

    pw_hash, salt = (None, None)
    if password:
        pw_hash, salt = hash_password(password)

    with DatabaseConnection(db_path=db_path, db_url=db_url) as db:
        db.execute("""
            INSERT INTO users (id, email, password_hash, salt, full_name, phone, location, latitude, longitude, role, profile_image_url, provider, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (user_id, clean_email, pw_hash, salt, full_name.strip(), phone.strip(), location.strip(), latitude, longitude, role.strip(), profile_image_url, provider, created_at))

    return {
        "id": user_id,
        "email": clean_email,
        "full_name": full_name.strip(),
        "phone": phone.strip(),
        "location": location.strip(),
        "latitude": latitude,
        "longitude": longitude,
        "role": role.strip(),
        "profile_image_url": profile_image_url,
        "provider": provider,
        "created_at": created_at
    }

def get_user_by_email(email: str, db_path: str = DB_PATH, db_url: Optional[str] = None) -> Optional[Dict[str, Any]]:
    """Retrieves user record by email address."""
    engine, target = get_engine_config(db_path, db_url)
    if engine == "sqlite" and target != ":memory:" and not os.path.exists(target):
        init_database(db_path=db_path, db_url=db_url)

    clean_email = email.strip().lower()
    with DatabaseConnection(db_path=db_path, db_url=db_url) as db:
        db.execute("SELECT * FROM users WHERE LOWER(email) = ?", (clean_email,))
        return db.fetchone()

def get_user_by_id(user_id: str, db_path: str = DB_PATH, db_url: Optional[str] = None) -> Optional[Dict[str, Any]]:
    """Retrieves user record by ID."""
    engine, target = get_engine_config(db_path, db_url)
    if engine == "sqlite" and target != ":memory:" and not os.path.exists(target):
        init_database(db_path=db_path, db_url=db_url)

    with DatabaseConnection(db_path=db_path, db_url=db_url) as db:
        db.execute("SELECT * FROM users WHERE id = ?", (user_id,))
        return db.fetchone()

def update_user_password(email: str, new_password: str, db_path: str = DB_PATH, db_url: Optional[str] = None) -> bool:
    """Updates user password with fresh salt and hash."""
    clean_email = email.strip().lower()
    pw_hash, salt = hash_password(new_password)

    with DatabaseConnection(db_path=db_path, db_url=db_url) as db:
        db.execute("""
            UPDATE users SET password_hash = ?, salt = ? WHERE LOWER(email) = ?
        """, (pw_hash, salt, clean_email))
        return db.rowcount > 0

def create_or_get_google_user(
    email: str,
    full_name: str,
    photo_url: Optional[str] = None,
    db_path: str = DB_PATH,
    db_url: Optional[str] = None
) -> Dict[str, Any]:
    """Retrieves or creates user authenticated via Google OAuth."""
    existing = get_user_by_email(email, db_path=db_path, db_url=db_url)
    if existing:
        if photo_url and existing.get("profile_image_url") != photo_url:
            with DatabaseConnection(db_path=db_path, db_url=db_url) as db:
                db.execute("UPDATE users SET profile_image_url = ? WHERE id = ?", (photo_url, existing["id"]))
            existing["profile_image_url"] = photo_url
        return existing

    return create_user(
        email=email,
        password=None,
        full_name=full_name,
        role="Cotton Farmer",
        profile_image_url=photo_url,
        provider="google",
        db_path=db_path,
        db_url=db_url
    )

def provision_initial_admin(
    admin_email: Optional[str] = None,
    admin_password: Optional[str] = None,
    full_name: str = "System Administrator",
    db_path: str = DB_PATH,
    db_url: Optional[str] = None
) -> Optional[Dict[str, Any]]:
    """
    Secure first-admin provisioning routine.
    Provisions or promotes the designated administrator from environment variables or explicit parameters.
    Never exposes admin creation to unauthenticated public self-registration.
    CRITICAL: Never resets or overwrites an existing administrator's password on restart.
    """
    target_email = (admin_email or os.environ.get("ADMIN_EMAIL", "")).strip().lower()
    target_password = admin_password or os.environ.get("ADMIN_INITIAL_PASSWORD", "")

    if not target_email or "@" not in target_email:
        return None

    existing = get_user_by_email(target_email, db_path=db_path, db_url=db_url)
    if existing:
        # If user exists, ensure role is upgraded to System Admin without touching password
        if existing.get("role") not in ["System Admin", "Admin"]:
            with DatabaseConnection(db_path=db_path, db_url=db_url) as db:
                db.execute("UPDATE users SET role = 'System Admin' WHERE id = ?", (existing["id"],))
            existing["role"] = "System Admin"
            print(f"[CottonGuard Security] Existing user {target_email} promoted to System Admin.")
        return existing

    if not target_password:
        return None

    user = create_user(
        email=target_email,
        password=target_password,
        full_name=full_name,
        role="System Admin",
        provider="provisioned",
        db_path=db_path,
        db_url=db_url
    )
    print(f"[CottonGuard Security] First admin account securely provisioned for {target_email}.")
    return user

def create_password_reset(email: str, db_path: str = DB_PATH, db_url: Optional[str] = None) -> str:
    """Generates password reset token valid for 1 hour."""
    clean_email = email.strip().lower()
    token = secrets.token_urlsafe(24)
    expires_at = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(time.time() + 3600))

    with DatabaseConnection(db_path=db_path, db_url=db_url) as db:
        db.execute("""
            INSERT INTO password_resets (email, reset_token, expires_at, used)
            VALUES (?, ?, ?, 0)
        """, (clean_email, token, expires_at))
    return token

def verify_and_use_reset_token(
    email: str,
    token: str,
    new_password: str,
    db_path: str = DB_PATH,
    db_url: Optional[str] = None
) -> bool:
    """Verifies reset token validity, updates password, and consumes token."""
    clean_email = email.strip().lower()
    now_iso = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

    with DatabaseConnection(db_path=db_path, db_url=db_url) as db:
        db.execute("""
            SELECT id FROM password_resets
            WHERE LOWER(email) = ? AND reset_token = ? AND used = 0 AND expires_at > ?
        """, (clean_email, token.strip(), now_iso))
        row = db.fetchone()

        if not row:
            return False

        reset_id = row["id"]
        db.execute("UPDATE password_resets SET used = 1 WHERE id = ?", (reset_id,))

    return update_user_password(clean_email, new_password, db_path=db_path, db_url=db_url)

def log_service_action(
    admin_email: str,
    action: str,
    prior_state: str,
    new_state: str,
    ip_address: str = "",
    details: str = "",
    db_path: str = DB_PATH,
    db_url: Optional[str] = None
) -> int:
    """Records an administrative start/stop service state change in database."""
    engine, target = get_engine_config(db_path, db_url)
    if engine == "sqlite" and target != ":memory:" and not os.path.exists(target):
        init_database(db_path=db_path, db_url=db_url)

    ts = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    with DatabaseConnection(db_path=db_path, db_url=db_url) as db:
        log_id = db.execute_insert("""
            INSERT INTO service_audit_logs (timestamp, admin_email, action, prior_state, new_state, ip_address, details)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """, (ts, admin_email.strip().lower(), action, prior_state, new_state, ip_address, details), returning_col="id")
    return int(log_id) if log_id else 0

def get_service_audit_logs(
    limit: int = 50,
    db_path: str = DB_PATH,
    db_url: Optional[str] = None
) -> List[Dict[str, Any]]:
    """Retrieves recent administrative service state audit logs."""
    engine, target = get_engine_config(db_path, db_url)
    if engine == "sqlite" and target != ":memory:" and not os.path.exists(target):
        init_database(db_path=db_path, db_url=db_url)

    with DatabaseConnection(db_path=db_path, db_url=db_url) as db:
        db.execute("""
            SELECT * FROM service_audit_logs
            ORDER BY id DESC
            LIMIT ?
        """, (limit,))
        return db.fetchall()

if __name__ == "__main__":
    init_database()
    sample = get_advisory_for_class("Bacterial Blight")
    print("\nSample Retrieval for 'Bacterial Blight':")
    print(sample)
