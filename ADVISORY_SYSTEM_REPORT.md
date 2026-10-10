# Cotton Guard - Retrieval-Based Agronomic Advisory System Report

## 1. Executive Summary & Specification Alignment

| Academic Parameter | System Implementation |
| :--- | :--- |
| **Project Name** | AI Based Smart Plant Disease Detection & Advisory System (**Cotton Guard**) |
| **Domain** | Cotton Leaf Disease Detection and Agronomic Advisory |
| **Advisory Method** | **Retrieval-Based Advisory** |
| **Knowledge Base** | **SQLite Database** (`backend/advisory.db`) |
| **Retrieval Technique** | **Class-Based Database Retrieval** (`canonical_name = ?`) |
| **Integrated Engine** | FastAPI Backend (`backend/main.py`) + Flutter Mobile Client (`DiagnosisResultScreen`) |
| **Supported Canonical Conditions** | 7 Canonical Classes (6 pathological/physiological + 1 healthy) |

---

## 2. SQLite Database Schema Architecture

The knowledge base is implemented using a relational SQLite schema designed for normalization, referential integrity, and efficient indexed lookups.

```sql
-- 1. Master Disease and Condition Table
CREATE TABLE IF NOT EXISTS diseases (
    disease_id INTEGER PRIMARY KEY AUTOINCREMENT,
    canonical_name TEXT UNIQUE NOT NULL,
    scientific_name TEXT NOT NULL,
    description TEXT NOT NULL,
    is_healthy INTEGER NOT NULL DEFAULT 0,
    favorable_conditions TEXT
);

-- 2. Diagnostic Symptoms Table (1-to-Many)
CREATE TABLE IF NOT EXISTS symptoms (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    disease_id INTEGER NOT NULL,
    symptom TEXT NOT NULL,
    FOREIGN KEY (disease_id) REFERENCES diseases (disease_id) ON DELETE CASCADE
);

-- 3. Prophylactic & Field Sanitation Prevention Table (1-to-Many)
CREATE TABLE IF NOT EXISTS prevention (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    disease_id INTEGER NOT NULL,
    recommendation TEXT NOT NULL,
    FOREIGN KEY (disease_id) REFERENCES diseases (disease_id) ON DELETE CASCADE
);

-- 4. Therapeutic Chemical & Cultural Treatment Table (1-to-Many)
CREATE TABLE IF NOT EXISTS treatment (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    disease_id INTEGER NOT NULL,
    treatment_type TEXT DEFAULT 'Chemical',
    recommendation TEXT NOT NULL,
    FOREIGN KEY (disease_id) REFERENCES diseases (disease_id) ON DELETE CASCADE
);

-- 5. Severity Stratification Table (1-to-1)
CREATE TABLE IF NOT EXISTS severity (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    disease_id INTEGER NOT NULL,
    severity_level INTEGER NOT NULL,
    severity_label TEXT NOT NULL,
    description TEXT NOT NULL,
    FOREIGN KEY (disease_id) REFERENCES diseases (disease_id) ON DELETE CASCADE
);
```

---

## 3. Canonical Knowledge Base Content & Agronomic Corpus

All 7 canonical conditions are seeded with verified agronomic, pathological, and pest management data aligned with ICAR-CICR (Central Institute for Cotton Research) recommendations:

### 1. Healthy Leaf (`Gossypium hirsutum L.`)
- **Severity**: Level 1 — None (Healthy)
- **Favorable Conditions**: Balanced soil fertility, optimal moisture (field capacity 60-70%), temperature 25-32°C.
- **Key Symptoms**: Uniform green lamina, intact leaf margins, no curling/fasciation, absence of honeydew or lesions.
- **Prevention**: Spacing (90x60 cm or 105x60 cm), split NPK fertilization (120:60:60 kg/ha in 3 split doses), yellow sticky traps (10-15/acre).
- **Treatment / Prophylaxis**: Prophylactic neem oil (1500 ppm @ 2-3 mL/L); no therapeutic chemical bactericides required.

### 2. Bacterial Blight (`Xanthomonas citri pv. malvacearum`)
- **Severity**: Level 3 — Moderate to High
- **Favorable Conditions**: Relative humidity >85%, temperatures 28-32°C, splashing rain/overhead irrigation.
- **Key Symptoms**: Angular water-soaked lesions bounded by veinlets, dark brown/black necrotic spots, systemic vein blight ('black arm'), premature defoliation.
- **Prevention**: Acid delinting (100 mL H2SO4/kg seed), seed treatment with Streptocycline (100 mg/L), certified resistant hybrids.
- **Treatment**: Foliar spray of Copper Oxychloride 50 WP @ 2.5 g/L + Streptocycline @ 100 mg/L (1 g in 10 L water); repeat after 12-15 days if humid conditions persist.

### 3. Cotton Leaf Curl Virus (`Begomovirus` / CLCuV)
- **Severity**: Level 4 — High to Critical
- **Favorable Conditions**: High whitefly (*Bemisia tabaci*) vector density, hot dry weather followed by monsoon flushes, presence of weed alternate hosts.
- **Key Symptoms**: Upward/downward leaf curling, thickening/darkening of main and secondary veins, enations (leafy outgrowths under leaf), severe plant stunting.
- **Prevention**: Eradicate alternate weed hosts (*Parthenium*, *Abutilon*, *Sida*) from bunds; install yellow sticky traps @ 20/acre; sow within regional window.
- **Treatment / Vector Control**: Diafenthiuron 50% WP @ 1.25 g/L or Pyriproxyfen 10% EC @ 2 mL/L; for nymphs: Spiromesifen 22.9% SC @ 1 mL/L or Flonicamid 50 WG @ 0.4 g/L; rogue out infected plants in first 45 DAS.

### 4. Herbicide Growth Damage (`Non-Pathogenic Phytotoxicity`)
- **Severity**: Level 3 — Moderate (Abiotic)
- **Favorable Conditions**: Adjacent 2,4-D / glyphosate spraying during windy periods (>10 km/h) or contaminated spray equipment.
- **Key Symptoms**: Leaf strapping into 'duck-foot' patterns, parallel vein crowding, petiole epinasty, chlorosis, cessation of apical terminal elongation.
- **Prevention**: Zero hormone herbicide applications near broadleaf cotton; dedicated herbicide spray tanks; vegetative barrier rows (sorghum/maize).
- **Treatment**: Foliar spray of 19:19:19 water-soluble fertilizer @ 5 g/L + Gibberellic Acid (GA3 @ 10-20 ppm); humic acid (12% @ 3 mL/L) with light furrow irrigation.

### 5. Leaf Hopper / Jassids (`Amrasca biguttula biguttula`)
- **Severity**: Level 3 — Moderate to High
- **Favorable Conditions**: Warm humid weather (25-30°C, RH 70-85%), excessive vegetative succulence from heavy nitrogen.
- **Key Symptoms**: Downward cupping ('inverted cup' appearance), marginal chlorosis, progressing to brick-red marginal burn ('hopper burn') and necrosis.
- **Prevention**: Pubescent/hairy cultivars; seed treatment with Imidacloprid 70 WS @ 7 g/kg or Thiamethoxam 70 WS @ 4 g/kg; avoid excessive urea splits.
- **Treatment**: At ETL (1-2 jassids/leaf): Flonicamid 50 WG @ 0.3-0.4 g/L, Dinotefuran 20% SG @ 0.3 g/L, or Thiamethoxam 25 WG @ 0.25 g/L; organic: Neem oil (10,000 ppm @ 2 mL/L).

### 6. Leaf Reddening (`Physiological Anthocyanosis & Nutrient Deficiency`)
- **Severity**: Level 2 — Mild to Moderate (Physiological)
- **Favorable Conditions**: Sudden temperature drops in October-November, soil waterlogging, excessive boll load, light sandy soils.
- **Key Symptoms**: Interveinal leaf tissue turns bronze to deep purplish-red while main veins remain green; lower leaves affected first; brittle leaves.
- **Prevention**: Proper soil drainage; FYM/compost @ 5 tonnes/acre; basal Magnesium Sulphate @ 10-15 kg/acre in light soils; timely nitrogen/potassium splits.
- **Treatment**: Foliar spray of 1% Magnesium Sulphate (MgSO4 @ 10 g/L) + 1% Urea (10 g/L) at first reddening; repeat after 10-12 days; Potassium Nitrate (13:0:45 @ 10 g/L).

### 7. Leaf Variegation (`Genetic & Physiological Chlorosis / Chimera`)
- **Severity**: Level 1 — Low (Benign)
- **Favorable Conditions**: Somatic genetic mutation in plastid DNA, hybrid chimera expression, or localized micronutrient metabolic blocks.
- **Key Symptoms**: Sharp geometric white/cream/pale-yellow patches; no necrotic edges; localized to specific branch or leaf without spreading.
- **Prevention**: Certified seed lots; soil micronutrient testing; apply Zinc Sulphate @ 10 kg/acre if zinc deficiency exists.
- **Treatment**: No pesticides required; if accompanied by interveinal chlorosis, foliar spray of Chelated Micronutrient Mixture @ 1.5 g/L.

---

## 4. Class-Based Database Retrieval Implementation

The retrieval engine queries SQLite using the canonical prediction output as the lookup key:

```python
def get_advisory_for_class(canonical_class: str, db_path: str = DB_PATH) -> Optional[Dict[str, Any]]:
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()

    cursor.execute("""
        SELECT disease_id, canonical_name, scientific_name, description, is_healthy, favorable_conditions
        FROM diseases
        WHERE canonical_name = ?
    """, (canonical_class,))
    d_row = cursor.fetchone()
    if not d_row:
        conn.close()
        return None

    disease_id = d_row["disease_id"]
    # Retrieve relational symptoms, prevention, treatment, severity
    cursor.execute("SELECT symptom FROM symptoms WHERE disease_id = ? ORDER BY id ASC", (disease_id,))
    symptoms = [r["symptom"] for r in cursor.fetchall()]
    ...
```

---

## 5. End-to-End API Integration & Verification

All three primary advisory-dependent API routes query the SQLite knowledge base:

1. `POST /api/v1/predict`:
   - Executes Attention-Based CNN inference with Hybrid CLAHE.
   - Extracts `predicted_class`.
   - Executes `get_advisory_for_class(predicted_class)`.
   - Injects structured agronomic metadata (`severity`, `symptoms`, `treatment`, `prevention`, `favorable_conditions`) into the JSON response with `"knowledge_base": "SQLite (advisory.db)"`.

2. `GET /api/v1/advisory/all`:
   - Executes `get_all_advisories()`.
   - Returns full catalog for all 7 canonical classes dynamically from SQLite.

3. `GET /api/v1/disease/{class_name}`:
   - Queries `get_advisory_for_class(target_class)` directly from SQLite.
   - Handles URL slug paths and special characters (`Leaf Hopper / Jassids`).

---

## 6. Mobile Client UI Presentation

In Flutter:
- `DiagnosisResultScreen` dynamically consumes the retrieved JSON payload and renders:
  - Color-coded severity badge (Healthy = Green, Moderate = Amber, High/Critical = Red).
  - Identified symptoms in bulleted bio-metric cards.
  - Therapeutic chemical management & spray dosages with verification checkmarks.
  - Preventive cultural practices & field sanitation guidelines.
  - Agronomic conditions favorable for disease development.
