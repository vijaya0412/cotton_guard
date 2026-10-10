# 02 — Project Structure & Complete File Guide

This document maps the entire physical directory tree of **Cotton Guard** (`E:\project\kushi`) and provides a detailed breakdown of each subsystem, folder, and critical file.

---

## 1. Annotated Repository Directory Tree

```
E:\project\kushi
├── .dockerignore                     # Docker build exclusion rules (prevents local leaks)
├── .env.example                      # Sanitized environment variable template
├── .gitignore                        # Git exclusions for secrets, *.db, checkpoints, and builds
├── analysis_options.yaml             # Dart static analyzer configuration (flutter_lints)
├── Dockerfile                        # Multi-stage production container definition (Port 7860)
├── docker-compose.yml                # Multi-service local container orchestrator
├── pubspec.yaml                      # Flutter dependencies, SDK constraints & asset declarations
├── pubspec.lock                      # Exact resolved versions of all Dart packages
├── pytest.ini                        # Pytest configuration and root directory discovery
├── README.md                         # Project documentation and Hugging Face Space metadata
│
├── android/                          # Android Platform Integration
│   ├── app/
│   │   ├── build.gradle.kts          # Android build settings (namespace, Java 17, min/target SDK)
│   │   └── src/main/
│   │       ├── AndroidManifest.xml   # Permissions (Camera, Internet) and MainActivity
│   │       └── res/xml/
│   │           └── network_security_config.xml # Cleartext HTTP policy for local dev
│   └── build.gradle.kts              # Root Android project configuration
│
├── assets/                           # Application Static Media
│   ├── images/                       # Branding logos, background textures, illustration SVGs
│   └── diseases/                     # High-resolution reference imagery for 7 canonical classes
│       ├── bacterial_blight/         # Authentic leaf samples for Bacterial Blight
│       ├── curl_virus/               # Authentic leaf samples for Cotton Leaf Curl Virus
│       ├── healthy_leaf/             # Authentic leaf samples for Healthy Foliage
│       ├── herbicide_damage/         # Authentic leaf samples for Herbicide Phytotoxicity
│       ├── leaf_hopper_jassids/      # Authentic leaf samples for Jassids Hopper Burn
│       ├── leaf_reddening/           # Authentic leaf samples for Physiological Reddening
│       └── leaf_variegation/         # Authentic leaf samples for Genetic Variegation
│
├── backend/                          # FastAPI Backend & Inference Server
│   ├── database.py                   # Dual PostgreSQL/SQLite engine & Knowledge Base seeding
│   ├── main.py                       # FastAPI application entrypoint, endpoints, and CORS
│   ├── provision_admin.py            # CLI script for idempotent administrator provisioning
│   ├── requirements.txt              # Pinned Python production dependencies
│   ├── run_server.py                 # ASGI runner script binding host and port
│   ├── service_state.py              # In-memory service state coordinator and callbacks
│   ├── test_api.py                   # Pytest suite: Endpoints, validation gates, prediction
│   ├── test_auth.py                  # Pytest suite: Registration, login, password hashing
│   ├── test_database_persistence.py  # Pytest suite: Dual-engine SQLite & Postgres persistence
│   ├── test_security_regression.py   # Pytest suite: RBAC enforcement, fail-closed policy
│   └── test_service_state.py         # Pytest suite: Service start/stop lifecycle and logs
│
├── lib/                              # Flutter Mobile Application Source Code
│   ├── main.dart                     # Flutter application entrypoint and provider bootloader
│   │
│   ├── constants/                    # Application Design Tokens & Canonical Constants
│   │   ├── api_constants.dart        # Endpoints, timeout durations, and URL normalization
│   │   ├── app_colors.dart           # Dark theme color palette (greens, dark slates, accents)
│   │   ├── app_motion.dart           # Animation durations and easing curves
│   │   ├── app_spacing.dart          # Padding, margins, and border radii constants
│   │   ├── app_theme.dart            # Material 3 ThemeData definition
│   │   ├── app_typography.dart       # Heading, body, and label text styling rules
│   │   ├── canonical_classes.dart    # 7 canonical disease class constants and UI metadata
│   │   └── cotton_assets.dart        # Static asset path bindings
│   │
│   ├── controllers/                  # State Management Controllers (ChangeNotifier)
│   │   ├── auth_controller.dart      # User session, login, signup, and logout state
│   │   ├── connection_controller.dart# Server connectivity, ping latency, and offline state
│   │   ├── history_controller.dart   # Scanned records cache, statistics, and persistence
│   │   └── theme_controller.dart     # Dark/light UI mode preferences
│   │
│   ├── data/                         # Local Seed Data & Geographical Databases
│   │   ├── indian_locations.dart     # Quick district selector model
│   │   └── india_states_districts.dart# Comprehensive database of 780+ Indian districts
│   │
│   ├── models/                       # Data Transfer Objects & Serialization Models
│   │   ├── prediction_result.dart    # AI inference output, confidence, symptoms, treatments
│   │   ├── scan_record.dart          # Persisted user scan entity with timestamp and image
│   │   ├── server_health.dart        # Server uptime, model state, and latency metrics
│   │   ├── user_profile.dart         # Authenticated farmer profile data model
│   │   └── weather_data.dart         # Weather metrics parsed from Open-Meteo
│   │
│   ├── screens/                      # UI Screens & Navigational Flows
│   │   ├── home_dashboard_screen.dart# Main dashboard with weather, actions, recent scans
│   │   ├── main_navigation_shell.dart# Bottom navigation bar holding 4 core destination tabs
│   │   ├── onboarding_screen.dart    # First-launch onboarding walkthrough
│   │   ├── splash_screen.dart        # Animated splash screen and session preloader
│   │   │
│   │   ├── advisory/                 # Agronomic Advisory Screens
│   │   │   └── advisory_screen.dart  # Comprehensive disease management guide
│   │   │
│   │   ├── auth/                     # Authentication Screens
│   │   │   ├── forgot_password_screen.dart # Password reset initiation and recovery
│   │   │   ├── login_screen.dart     # Email/password and Google Sign-In interface
│   │   │   └── signup_screen.dart    # Farmer registration interface
│   │   │
│   │   ├── disease_library/          # Disease Reference Screens
│   │   │   ├── disease_detail_screen.dart  # Detailed agronomic profile for single disease
│   │   │   └── disease_library_screen.dart # 7-condition visual catalog grid
│   │   │
│   │   ├── history/                  # Historical Scans
│   │   │   ├── history_detail_screen.dart  # Re-inspection of past diagnosis report
│   │   │   └── history_screen.dart   # Filterable list of previous leaf diagnoses
│   │   │
│   │   ├── insights/                 # Analytics & Crop Health Insights
│   │   │   └── insights_screen.dart  # Distribution charts of healthy vs diseased scans
│   │   │
│   │   ├── profile/                  # Farmer Profile Management
│   │   │   └── profile_screen.dart   # Profile details, district selector, avatar updater
│   │   │
│   │   ├── scan/                     # Leaf Scanning & AI Diagnostic Pipeline
│   │   │   ├── ai_analysis_screen.dart     # Scanning animation & progress indicator
│   │   │   ├── diagnosis_result_screen.dart# Full diagnostic report & chemical/organic cures
│   │   │   ├── image_preview_screen.dart   # Frame confirmation before sending to AI
│   │   │   └── scan_screen.dart      # Live viewfinder, gallery import & camera controls
│   │   │
│   │   └── settings/                 # App & Server Configuration
│   │       ├── admin_control_screen.dart   # Protected start/stop service control panel
│   │       ├── server_connection_screen.dart# Cloud/Localhost/Custom IP switcher
│   │       ├── server_diagnostics_screen.dart# Real-time latency and server state inspector
│   │       └── settings_screen.dart  # General preferences and cache management
│   │
│   ├── services/                     # Business Logic & External Integrations
│   │   ├── api_service.dart          # HTTP client for inference, health, and advisories
│   │   ├── google_auth_service.dart  # Google Play Services sign-in handler
│   │   ├── indian_time_service.dart  # IST greeting and timestamp utility
│   │   ├── profile_image_service.dart# Local file saving for farmer profile avatars
│   │   ├── storage_service.dart      # SharedPreferences wrapper for tokens, urls, history
│   │   └── weather_service.dart      # Free Open-Meteo REST API consumer
│   │
│   └── widgets/                      # Reusable UI Components
│       ├── custom_button.dart        # Elevated gradient action buttons
│       ├── empty_state_view.dart     # Clean fallback when history or lists are empty
│       ├── error_state_view.dart     # Retry button and error explanation card
│       ├── glass_card.dart           # Translucent glassmorphic container
│       ├── location_picker_sheet.dart# Bottom modal for choosing Indian state and district
│       ├── scan_animation_view.dart  # Laser scanning bar animation over leaf preview
│       ├── status_badge.dart         # Connected/Offline and disease severity pill
│       └── user_avatar.dart          # Circular avatar with fallback initials
│
├── ml/                               # Machine Learning Architecture & Models
│   ├── cbam.py                       # Convolutional Block Attention Module implementation
│   ├── classes.py                    # 7 canonical classes, folder mappings, agronomic facts
│   ├── cotton_gate.py                # 4-stage quality, exposure, blur, and botanical gate
│   ├── evaluate_production_model.py  # Scientific benchmark script evaluating test set
│   ├── preprocessing.py              # CIELAB-CLAHE and ImageNet tensor normalizer
│   ├── production_model_evaluation.json # Raw benchmark output on 322 test images
│   ├── quality_gate.py               # Legacy image quality validation rules
│   └── models/
│       ├── cotton_guard_model.onnx   # Production ONNX model (17.3 MB, 5.4M parameters)
│       └── cotton_guard_model.pt     # PyTorch master checkpoint (17.5 MB)
│
├── test/                             # Automated Test Suites
│   ├── test_ml_pipeline.py           # Pytest suite for ML tensors, gate, ONNX, and DB
│   └── widget_test.dart              # Flutter test suite: 20 unit and widget test cases
│
└── docs/                             # Project Documentation
    └── project-audit/                # Authoritative Technical Audit & Documentation Suite
```

---

## 2. Critical File Responsibilities

### Core Backend & Machine Learning

1. **[`backend/main.py`](file:///E:/project/kushi/backend/main.py)**:
   - Sets up FastAPI instance with CORS middleware.
   - Initialises database schema on startup via [`init_database()`](file:///E:/project/kushi/backend/database.py#L333).
   - Loads ONNX runtime session via [`load_inference_session()`](file:///E:/project/kushi/backend/main.py#L106).
   - Exposes REST endpoints: `/api/v1/health`, `/api/v1/predict`, `/api/v1/advisory/all`, `/api/v1/disease/{class_name}`, `/api/v1/fields`, `/api/v1/auth/*`, and `/api/v1/admin/*`.
   - Coordinates multi-stage input validation before passing images to inference engine.

2. **[`backend/database.py`](file:///E:/project/kushi/backend/database.py)**:
   - Provides [`DatabaseConnection`](file:///E:/project/kushi/backend/database.py#L76-L160) context manager abstracting SQLite and PostgreSQL.
   - Implements SQL translation (`?` to `%s`) and `INSERT ... RETURNING id`.
   - Seeds all 7 canonical disease records, symptoms, treatments, prevention, and severity definitions.
   - Manages user accounts with PBKDF2-HMAC-SHA256 password hashing.
   - Creates and validates HMAC-SHA256 signed session tokens.
   - Implements idempotent admin provisioning (`provision_initial_admin()`).

3. **[`ml/cotton_gate.py`](file:///E:/project/kushi/ml/cotton_gate.py)**:
   - **Stage 1**: Enforces byte limit (200 B to 15 MB), valid image format (JPEG, PNG, WEBP), and minimum dimensions ($150 \times 150$).
   - **Stage 2**: Evaluates exposure (mean brightness $30.0 \le \mu \le 245.0$) and sharpness (Laplacian variance $\ge 15.0$).
   - **Stage 3**: Validates biological foliage presence using an HSV chromatic mask ($\ge 15\%$ coverage) and checks texture energy ($\ge 10.0$).
   - **Stage 4**: Detects prediction uncertainty (confidence $< 0.55$ or top-1 vs top-2 margin $< 0.12$).

4. **[`ml/preprocessing.py`](file:///E:/project/kushi/ml/preprocessing.py)**:
   - Resizes input image to $224 \times 224$ pixels.
   - Converts RGB image to CIELAB color space.
   - Applies Contrast-Limited Adaptive Histogram Equalization (CLAHE) with `clipLimit=2.0` and `tileGridSize=(8, 8)` to the Luminance (L) channel.
   - Converts back to RGB and normalizes pixel intensities using ImageNet mean (`[0.485, 0.456, 0.406]`) and standard deviation (`[0.229, 0.224, 0.225]`).
   - Supports both `NCHW` and `NHWC` memory layouts.

---

### Core Flutter Client

1. **[`lib/screens/scan/scan_screen.dart`](file:///E:/project/kushi/lib/screens/scan/scan_screen.dart)**:
   - Houses the responsive scanning viewfinder enclosed in a `LayoutBuilder` (clamped between 250px and 310px height).
   - Features animated green corner brackets, leaf alignment reticle, and instruction badge.
   - Separates "Take Photo" and "Gallery" action buttons by an 18px margin, preventing button collisions across small and large Android devices.

2. **[`lib/screens/scan/ai_analysis_screen.dart`](file:///E:/project/kushi/lib/screens/scan/ai_analysis_screen.dart)**:
   - Renders a futuristic scanning beam moving across the selected leaf.
   - Displays real-time status steps: "Analyzing leaf geometry...", "Checking botanical markers...", "Classifying condition...".
   - Executes the network call to [`ApiService.predictDisease()`](file:///E:/project/kushi/lib/services/api_service.dart#L88).
   - Navigates seamlessly to [`DiagnosisResultScreen`](file:///E:/project/kushi/lib/screens/scan/diagnosis_result_screen.dart) upon receiving diagnosis.

3. **[`lib/screens/scan/diagnosis_result_screen.dart`](file:///E:/project/kushi/lib/screens/scan/diagnosis_result_screen.dart)**:
   - Displays disease title, scientific name, severity pill, and visual confidence bar.
   - Presents tabbed agronomic guidance:
     - **Symptoms**: Bulleted botanical indicators.
     - **Chemical Cure**: Recommended agrochemical formulations and dosages.
     - **Organic & Preventive**: Cultural management practices, neem applications, and sticky trap advice.
   - Automatically saves the diagnosis into local history via [`HistoryController`](file:///E:/project/kushi/lib/controllers/history_controller.dart).

4. **[`lib/constants/api_constants.dart`](file:///E:/project/kushi/lib/constants/api_constants.dart)**:
   - Defines production default base URL: `https://cotton-guard.onrender.com/api/v1`.
   - Configures connection timeout (45 seconds) and request timeout (60 seconds) to handle free-tier cloud cold starts.
   - Implements [`normalizeBaseUrl()`](file:///E:/project/kushi/lib/constants/api_constants.dart#L59) which automatically upgrades cloud domains to HTTPS while allowing unencrypted HTTP for local development IPs (e.g., `10.0.2.2`, `127.0.0.1`, LAN subnets).
