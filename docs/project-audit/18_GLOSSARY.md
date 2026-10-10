# 18 — Comprehensive Technical & Agronomic Glossary

This glossary defines the key agronomic, machine learning, security, and architectural terms used throughout the **Cotton Guard** codebase.

---

## 1. Agronomic & Botanical Terminology

| Term | Agronomic Definition | Context in Cotton Guard |
| :--- | :--- | :--- |
| **Bacterial Blight** | Foliar disease caused by *Xanthomonas citri pv. malvacearum* causing angular water-soaked leaf lesions bounded by veins and black arm stem necrosis. | Canonical Class 0; treated with Copper Oxychloride + Streptocycline. |
| **Cotton Leaf Curl Virus (CLCuV)** | Whitefly-transmitted begomovirus resulting in upward leaf curling, vein thickening, enation, and stunting. | Canonical Class 1; treated by controlling whitefly vectors with Diafenthiuron. |
| **Healthy Leaf** | Normal vigorous foliage of *Gossypium hirsutum* displaying uniform chlorophyll and zero necrotic lesions. | Canonical Class 2; baseline reference indicating no chemical sprays required. |
| **Herbicide Growth Damage** | Physiological phytotoxicity induced by spray drift or residual soil concentrations of hormone-type herbicides (e.g. 2,4-D). | Canonical Class 3; abiotic damage; treated with foliar nutrient sprays. |
| **Leaf Hopper / Jassids** | Sucking pest (*Amrasca biguttula biguttula*) that injects toxic saliva while feeding, causing leaf margin yellowing. | Canonical Class 4; treated with Flonicamid or Dinotefuran at ETL. |
| **Hopper Burn** | Necrotic browning, curling, and drying of leaf margins caused by heavy feeding of jassid nymphs. | Distinct diagnostic feature of Leaf Hopper damage. |
| **Leaf Reddening** | Physiological condition where leaves synthesize red anthocyanin pigments due to magnesium deficiency, waterlogging, or cold. | Canonical Class 5; reversible with foliar Magnesium Sulphate (1%) + Urea (1%). |
| **Leaf Variegation** | Non-infectious genetic or plastid chimera anomaly producing cream, white, or pale yellow geometric sectors on leaves. | Canonical Class 6; benign condition requiring zero chemical intervention. |
| **Enation** | Abnormal leaf-like foliar outgrowths developing on the underside of veins. | Diagnostic hallmark of Cotton Leaf Curl Virus infection. |
| **Economic Threshold Level (ETL)** | The pest population density at which management measures must be initiated to prevent reaching an economic injury level. | Used in advisory logic (e.g. 1–2 jassids per leaf before applying insecticide). |
| **Krishi Vigyan Kendra (KVK)** | Agricultural Science Center in India providing field testing, vocational training, and farmer extension services. | Recommended contact when the AI flags diagnostic uncertainty. |

---

## 2. Machine Learning & Computer Vision Terminology

| Term | Technical Definition | Implementation in Cotton Guard |
| :--- | :--- | :--- |
| **CBAM** | Convolutional Block Attention Module: sequentially infers attention maps along channel and spatial dimensions. | Implemented in [`ml/cbam.py`](file:///E:/project/kushi/ml/cbam.py); focuses model on subtle lesion patterns. |
| **CIELAB Color Space** | A color space modeled on human perception comprising $L^*$ (Luminance), $a^*$ (Green-Red), and $b^*$ (Blue-Yellow). | Used in [`ml/preprocessing.py`](file:///E:/project/kushi/ml/preprocessing.py) for hue-preserving contrast enhancement. |
| **CLAHE** | Contrast-Limited Adaptive Histogram Equalization: computes local histogram equalization while clipping excessive noise. | Equalizes the $L^*$ channel (`clipLimit=2.0`, `tileGridSize=(8, 8)`). |
| **MobileNetV3-Large** | Lightweight convolutional neural network optimized for mobile and CPU execution using Hard-Swish and inverted bottlenecks. | Core feature extractor backbone generating 960 channels. |
| **ONNX Runtime** | High-performance inference engine for Open Neural Network Exchange formats, executing cross-platform models. | Used in [`backend/main.py`](file:///E:/project/kushi/backend/main.py) via `CPUExecutionProvider` for sub-20ms inference. |
| **Laplacian Variance** | Statistical measure of edge definition used to detect camera blur. | Thresholded at $\ge 15.0$ in [`ml/cotton_gate.py`](file:///E:/project/kushi/ml/cotton_gate.py) to reject out-of-focus images. |
| **Botanical HSV Mask** | Multi-chromatic color filter isolating chlorophyll green, chlorotic yellow, anthocyanin red, and necrotic brown pixels. | Rejects images with $< 15\%$ foliage coverage as non-cotton subjects. |
| **Uncertainty Margin** | Difference in predicted probability between the top diagnosis and the second candidate class. | If top-1 confidence $< 0.55$ or margin $< 0.12$, triggers agronomic safety mode. |

---

## 3. Backend, Security & Cloud Terminology

| Term | Definition | Role in Cotton Guard |
| :--- | :--- | :--- |
| **FastAPI** | Modern, high-performance web framework for building APIs with Python based on standard Python type hints. | Powers the entire Cotton Guard backend service in [`backend/main.py`](file:///E:/project/kushi/backend/main.py). |
| **PBKDF2-HMAC-SHA256** | Password-Based Key Derivation Function 2 with HMAC-SHA256 pseudorandom function and salt. | Hashes passwords with 100,000 rounds in [`backend/database.py`](file:///E:/project/kushi/backend/database.py). |
| **Constant-Time Comparison** | String comparison algorithm whose execution time is independent of input character matches. | Implemented via `secrets.compare_digest` to prevent timing attacks. |
| **Dual-Engine Persistence** | Architectural pattern enabling runtime switching between database backends without changing query code. | Connects to PostgreSQL via `DATABASE_URL` or SQLite via `advisory.db`. |
| **Neon PostgreSQL** | Serverless cloud PostgreSQL platform separating compute and storage with auto-suspend capabilities. | Cloud database engine preserving farmer accounts across container restarts. |
| **UID 1000 Execution** | Running a Linux container under an unprivileged user ID rather than root. | Implemented in [`Dockerfile`](file:///E:/project/kushi/Dockerfile) (`USER 1000`) for cloud container compliance. |
| **Render Web Services** | Cloud platform hosting web applications and Docker containers with automatic TLS termination. | Current production host at `https://cotton-guard.onrender.com`. |
| **Hugging Face Spaces** | Hosting platform for machine learning applications supporting CPU and GPU Docker containers. | Secondary hosting target compatible with port 7860 and UID 1000. |
| **SharedPreferences** | Android key-value storage framework persisted to XML files on device storage. | Persists session tokens, local scan history, and user settings on the client. |
