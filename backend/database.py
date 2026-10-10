"""
Cotton Guard - SQLite Knowledge Base & Retrieval-Based Advisory Engine.
Implements Class-Based Database Retrieval for Disease Diagnosis & Agronomic Management.
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
SECRET_KEY = os.environ.get("COTTON_GUARD_SECRET_KEY", "cotton-guard-prod-key-2026-auth-security-master")

def init_database(db_path: str = DB_PATH):
    """Initializes and seeds the SQLite Knowledge Base with WAL concurrency."""
    os.makedirs(os.path.dirname(os.path.abspath(db_path)), exist_ok=True)
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # Enable WAL mode for high concurrency read/write
    cursor.execute("PRAGMA journal_mode=WAL;")
    cursor.execute("PRAGMA busy_timeout=5000;")

    # Create Tables
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS diseases (
        disease_id INTEGER PRIMARY KEY AUTOINCREMENT,
        canonical_name TEXT UNIQUE NOT NULL,
        scientific_name TEXT NOT NULL,
        description TEXT NOT NULL,
        is_healthy INTEGER NOT NULL DEFAULT 0,
        favorable_conditions TEXT
    );
    """)

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS symptoms (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        disease_id INTEGER NOT NULL,
        symptom TEXT NOT NULL,
        FOREIGN KEY (disease_id) REFERENCES diseases (disease_id) ON DELETE CASCADE
    );
    """)

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS prevention (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        disease_id INTEGER NOT NULL,
        recommendation TEXT NOT NULL,
        FOREIGN KEY (disease_id) REFERENCES diseases (disease_id) ON DELETE CASCADE
    );
    """)

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS treatment (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        disease_id INTEGER NOT NULL,
        treatment_type TEXT DEFAULT 'Chemical',
        recommendation TEXT NOT NULL,
        FOREIGN KEY (disease_id) REFERENCES diseases (disease_id) ON DELETE CASCADE
    );
    """)

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS severity (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        disease_id INTEGER NOT NULL,
        severity_level INTEGER NOT NULL,
        severity_label TEXT NOT NULL,
        description TEXT NOT NULL,
        FOREIGN KEY (disease_id) REFERENCES diseases (disease_id) ON DELETE CASCADE
    );
    """)

    cursor.execute("""
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
    """)

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS password_resets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT NOT NULL,
        reset_token TEXT NOT NULL,
        expires_at TEXT NOT NULL,
        used INTEGER DEFAULT 0
    );
    """)

    cursor.execute("""
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
    """)

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

    for rec in seed_records:
        cursor.execute("""
        INSERT OR REPLACE INTO diseases (canonical_name, scientific_name, description, is_healthy, favorable_conditions)
        VALUES (?, ?, ?, ?, ?)
        """, (rec["canonical_name"], rec["scientific_name"], rec["description"], rec["is_healthy"], rec["favorable_conditions"]))
        
        disease_id = cursor.lastrowid
        # In case of REPLACE, fetch the id
        cursor.execute("SELECT disease_id FROM diseases WHERE canonical_name = ?", (rec["canonical_name"],))
        disease_id = cursor.fetchone()[0]

        # Clear existing relations
        cursor.execute("DELETE FROM symptoms WHERE disease_id = ?", (disease_id,))
        cursor.execute("DELETE FROM prevention WHERE disease_id = ?", (disease_id,))
        cursor.execute("DELETE FROM treatment WHERE disease_id = ?", (disease_id,))
        cursor.execute("DELETE FROM severity WHERE disease_id = ?", (disease_id,))

        for s in rec["symptoms"]:
            cursor.execute("INSERT INTO symptoms (disease_id, symptom) VALUES (?, ?)", (disease_id, s))

        for p in rec["prevention"]:
            cursor.execute("INSERT INTO prevention (disease_id, recommendation) VALUES (?, ?)", (disease_id, p))

        for t in rec["treatment"]:
            cursor.execute("INSERT INTO treatment (disease_id, recommendation) VALUES (?, ?)", (disease_id, t))

        cursor.execute("""
        INSERT INTO severity (disease_id, severity_level, severity_label, description)
        VALUES (?, ?, ?, ?)
        """, (disease_id, rec["severity_level"], rec["severity_label"], rec["severity_desc"]))

    conn.commit()
    conn.close()
    print(f"SQLite Knowledge Base initialized at {db_path} with {len(seed_records)} canonical conditions.")

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

def get_advisory_for_class(canonical_class: str, db_path: str = DB_PATH) -> Optional[Dict[str, Any]]:
    """
    Class-Based Database Retrieval from SQLite Knowledge Base.
    Query: SELECT ... FROM ... WHERE canonical_name = ?
    Supports alias resolution and case-insensitive lookups.
    """
    if not os.path.exists(db_path):
        init_database(db_path)

    canonical_target = resolve_canonical_class(canonical_class)

    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()

    cursor.execute("""
        SELECT disease_id, canonical_name, scientific_name, description, is_healthy, favorable_conditions
        FROM diseases
        WHERE canonical_name = ? OR LOWER(canonical_name) = LOWER(?)
    """, (canonical_target, canonical_target))
    d_row = cursor.fetchone()

    if not d_row:
        conn.close()
        return None

    disease_id = d_row["disease_id"]

    # Fetch Symptoms
    cursor.execute("SELECT symptom FROM symptoms WHERE disease_id = ? ORDER BY id ASC", (disease_id,))
    symptoms = [r["symptom"] for r in cursor.fetchall()]

    # Fetch Prevention
    cursor.execute("SELECT recommendation FROM prevention WHERE disease_id = ? ORDER BY id ASC", (disease_id,))
    prevention = [r["recommendation"] for r in cursor.fetchall()]

    # Fetch Treatment
    cursor.execute("SELECT recommendation FROM treatment WHERE disease_id = ? ORDER BY id ASC", (disease_id,))
    treatment = [r["recommendation"] for r in cursor.fetchall()]

    # Fetch Severity
    cursor.execute("SELECT severity_level, severity_label, description FROM severity WHERE disease_id = ?", (disease_id,))
    s_row = cursor.fetchone()
    severity_level = s_row["severity_level"] if s_row else 1
    severity_label = s_row["severity_label"] if s_row else "Normal"
    severity_desc = s_row["description"] if s_row else ""

    conn.close()

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

def get_all_advisories(db_path: str = DB_PATH) -> Dict[str, Any]:
    """Retrieves full advisory catalog for all canonical classes."""
    if not os.path.exists(db_path):
        init_database(db_path)

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    cursor.execute("SELECT canonical_name FROM diseases ORDER BY disease_id ASC")
    classes = [r[0] for r in cursor.fetchall()]
    conn.close()

    catalog = {}
    for c in classes:
        adv = get_advisory_for_class(c, db_path)
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
    payload_b64 = base64.urlsafe_b64encode(json.dumps(payload).encode()).decode()
    signature = hmac.new(SECRET_KEY.encode(), payload_b64.encode(), hashlib.sha256).hexdigest()
    return f"{payload_b64}.{signature}"

def verify_session_token(token: str) -> Optional[Dict[str, Any]]:
    """Verifies session token authenticity and expiration."""
    try:
        parts = token.split(".")
        if len(parts) != 2:
            return None
        payload_b64, signature = parts
        expected = hmac.new(SECRET_KEY.encode(), payload_b64.encode(), hashlib.sha256).hexdigest()
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
    db_path: str = DB_PATH
) -> Dict[str, Any]:
    """Creates a new user record in SQLite with salted password hashing."""
    if not os.path.exists(db_path):
        init_database(db_path)

    clean_email = email.strip().lower()
    user_id = f"usr_{secrets.token_hex(8)}"
    created_at = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

    pw_hash, salt = (None, None)
    if password:
        pw_hash, salt = hash_password(password)

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    try:
        cursor.execute("""
            INSERT INTO users (id, email, password_hash, salt, full_name, phone, location, latitude, longitude, role, profile_image_url, provider, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (user_id, clean_email, pw_hash, salt, full_name.strip(), phone.strip(), location.strip(), latitude, longitude, role.strip(), profile_image_url, provider, created_at))
        conn.commit()
    finally:
        conn.close()

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

def get_user_by_email(email: str, db_path: str = DB_PATH) -> Optional[Dict[str, Any]]:
    """Retrieves user record by email address."""
    if not os.path.exists(db_path):
        init_database(db_path)

    clean_email = email.strip().lower()
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()

    cursor.execute("SELECT * FROM users WHERE LOWER(email) = ?", (clean_email,))
    row = cursor.fetchone()
    conn.close()

    if not row:
        return None
    return dict(row)

def get_user_by_id(user_id: str, db_path: str = DB_PATH) -> Optional[Dict[str, Any]]:
    """Retrieves user record by ID."""
    if not os.path.exists(db_path):
        init_database(db_path)

    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()

    cursor.execute("SELECT * FROM users WHERE id = ?", (user_id,))
    row = cursor.fetchone()
    conn.close()

    if not row:
        return None
    return dict(row)

def update_user_password(email: str, new_password: str, db_path: str = DB_PATH) -> bool:
    """Updates user password with fresh salt and hash."""
    clean_email = email.strip().lower()
    pw_hash, salt = hash_password(new_password)

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    cursor.execute("""
        UPDATE users SET password_hash = ?, salt = ? WHERE LOWER(email) = ?
    """, (pw_hash, salt, clean_email))
    updated = cursor.rowcount > 0
    conn.commit()
    conn.close()
    return updated

def create_or_get_google_user(
    email: str,
    full_name: str,
    photo_url: Optional[str] = None,
    db_path: str = DB_PATH
) -> Dict[str, Any]:
    """Retrieves or creates user authenticated via Google OAuth."""
    existing = get_user_by_email(email, db_path)
    if existing:
        # Update profile image if newly provided
        if photo_url and existing.get("profile_image_url") != photo_url:
            conn = sqlite3.connect(db_path)
            cursor = conn.cursor()
            cursor.execute("UPDATE users SET profile_image_url = ? WHERE id = ?", (photo_url, existing["id"]))
            conn.commit()
            conn.close()
            existing["profile_image_url"] = photo_url
        return existing

    return create_user(
        email=email,
        password=None,
        full_name=full_name,
        profile_image_url=photo_url,
        provider="google",
        db_path=db_path
    )

def create_password_reset(email: str, db_path: str = DB_PATH) -> str:
    """Generates password reset token valid for 1 hour."""
    clean_email = email.strip().lower()
    token = secrets.token_urlsafe(24)
    expires_at = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(time.time() + 3600))

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    cursor.execute("""
        INSERT INTO password_resets (email, reset_token, expires_at, used)
        VALUES (?, ?, ?, 0)
    """, (clean_email, token, expires_at))
    conn.commit()
    conn.close()
    return token

def verify_and_use_reset_token(email: str, token: str, new_password: str, db_path: str = DB_PATH) -> bool:
    """Verifies reset token validity, updates password, and consumes token."""
    clean_email = email.strip().lower()
    now_iso = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    cursor.execute("""
        SELECT id FROM password_resets
        WHERE LOWER(email) = ? AND reset_token = ? AND used = 0 AND expires_at > ?
    """, (clean_email, token.strip(), now_iso))
    row = cursor.fetchone()

    if not row:
        conn.close()
        return False

    reset_id = row[0]
    cursor.execute("UPDATE password_resets SET used = 1 WHERE id = ?", (reset_id,))
    conn.commit()
    conn.close()

    return update_user_password(clean_email, new_password, db_path)

def log_service_action(
    admin_email: str,
    action: str,
    prior_state: str,
    new_state: str,
    ip_address: str = "",
    details: str = "",
    db_path: str = DB_PATH
) -> int:
    """Records an administrative start/stop service state change in SQLite."""
    if not os.path.exists(db_path):
        init_database(db_path)

    ts = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    cursor.execute("""
        INSERT INTO service_audit_logs (timestamp, admin_email, action, prior_state, new_state, ip_address, details)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    """, (ts, admin_email.strip().lower(), action, prior_state, new_state, ip_address, details))
    conn.commit()
    log_id = cursor.lastrowid
    conn.close()
    return log_id or 0

def get_service_audit_logs(limit: int = 50, db_path: str = DB_PATH) -> List[Dict[str, Any]]:
    """Retrieves recent administrative service state audit logs."""
    if not os.path.exists(db_path):
        init_database(db_path)

    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    cursor.execute("""
        SELECT * FROM service_audit_logs
        ORDER BY id DESC
        LIMIT ?
    """, (limit,))
    rows = cursor.fetchall()
    conn.close()
    return [dict(r) for r in rows]

if __name__ == "__main__":
    init_database()
    sample = get_advisory_for_class("Bacterial Blight")
    print("\nSample Retrieval for 'Bacterial Blight':")
    print(sample)

