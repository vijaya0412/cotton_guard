# 11 — Features Inventory & End-to-End User Flows

This document details the functional feature inventory and user journeys implemented in the **Cotton Guard** application.

---

## 1. Complete Feature Inventory

| Module | Feature Name | Description | Key Source Files |
| :--- | :--- | :--- | :--- |
| **Scanning & AI** | **Camera Viewfinder** | Responsive viewfinder with animated corner brackets, crop guides, and non-overlapping action buttons. | [`lib/screens/scan/scan_screen.dart`](file:///E:/project/kushi/lib/screens/scan/scan_screen.dart) |
| **Scanning & AI** | **Image Confirmation** | Pre-upload review screen enabling farmers to verify focus or retake before calling AI API. | [`lib/screens/scan/image_preview_screen.dart`](file:///E:/project/kushi/lib/screens/scan/image_preview_screen.dart) |
| **Scanning & AI** | **Real-Time Analysis Animation** | Multi-phase animated scanning reticle with live status feedback during inference. | [`lib/screens/scan/ai_analysis_screen.dart`](file:///E:/project/kushi/lib/screens/scan/ai_analysis_screen.dart) |
| **Scanning & AI** | **Comprehensive Diagnosis** | Common name, scientific name, confidence meter, severity pill, and favorable weather triggers. | [`lib/screens/scan/diagnosis_result_screen.dart`](file:///E:/project/kushi/lib/screens/scan/diagnosis_result_screen.dart) |
| **Scanning & AI** | **Tabbed Agronomic Guidance** | Structured separation between Botanical Symptoms, Chemical Cures, and Organic/Prevention practices. | [`lib/screens/scan/diagnosis_result_screen.dart`](file:///E:/project/kushi/lib/screens/scan/diagnosis_result_screen.dart) |
| **Crop History** | **Local Scan Caching** | Persistent client-side archive of past scans with thumbnail images, dates, and diagnoses. | [`lib/screens/history/history_screen.dart`](file:///E:/project/kushi/lib/screens/history/history_screen.dart) |
| **Crop History** | **History Filtering & Search** | Instant text search and tabs for All Scans, Diseased, and Healthy leaves. | [`lib/screens/history/history_screen.dart`](file:///E:/project/kushi/lib/screens/history/history_screen.dart) |
| **Crop History** | **Historical Report Re-Inspection** | Re-opens archived diagnosis reports with complete chemical and organic advisories intact. | [`lib/screens/history/history_detail_screen.dart`](file:///E:/project/kushi/lib/screens/history/history_detail_screen.dart) |
| **Crop Health** | **Crop Health Insights** | Visual breakdown of overall crop health, diseased vs healthy ratios, and common disease frequencies. | [`lib/screens/insights/insights_screen.dart`](file:///E:/project/kushi/lib/screens/insights/insights_screen.dart) |
| **Reference** | **Disease Library Grid** | Clean visual catalog of the 7 canonical cotton foliar conditions without distracting severity tags. | [`lib/screens/disease_library/disease_library_screen.dart`](file:///E:/project/kushi/lib/screens/disease_library/disease_library_screen.dart) |
| **Reference** | **Agronomic Disease Profiles** | Deep encyclopedia entry for each disease covering biology, spread mechanisms, and controls. | [`lib/screens/disease_library/disease_detail_screen.dart`](file:///E:/project/kushi/lib/screens/disease_library/disease_detail_screen.dart) |
| **Advisory** | **Agronomic Care Guides** | General field management guides: Irrigation stages, split nitrogen schedules, sticky trap IPM, weed sanitation. | [`lib/screens/advisory/advisory_screen.dart`](file:///E:/project/kushi/lib/screens/advisory/advisory_screen.dart) |
| **Geography** | **Pan-India District Database** | Fast searchable picker covering 780+ districts across 28 states and 8 UTs with GPS coordinates. | [`lib/widgets/location_picker_sheet.dart`](file:///E:/project/kushi/lib/widgets/location_picker_sheet.dart) |
| **Weather** | **Open-Meteo Integration** | Live temperature, humidity, wind, rain probability, and localized crop disease risk alerts. | [`lib/services/weather_service.dart`](file:///E:/project/kushi/lib/services/weather_service.dart) |
| **Auth & Profile** | **Secure Farmer Sign-In** | Salted PBKDF2 email/password authentication and Google OAuth 2.0 integration. | [`lib/screens/auth/login_screen.dart`](file:///E:/project/kushi/lib/screens/auth/login_screen.dart) |
| **Auth & Profile** | **Farmer Profile Management** | Edit full name, contact phone, home district, and select profile picture stored locally. | [`lib/screens/profile/profile_screen.dart`](file:///E:/project/kushi/lib/screens/profile/profile_screen.dart) |
| **Settings** | **Server Connection Switcher** | Switch between Cloud Render, Android Emulator (10.0.2.2), Localhost, or custom IP with ping tests. | [`lib/screens/settings/server_connection_screen.dart`](file:///E:/project/kushi/lib/screens/settings/server_connection_screen.dart) |
| **Settings** | **Server Diagnostics** | Real-time display of round-trip latency, ONNX engine status, uptime, and supported classes. | [`lib/screens/settings/server_diagnostics_screen.dart`](file:///E:/project/kushi/lib/screens/settings/server_diagnostics_screen.dart) |
| **Admin** | **Service Control Panel** | Authenticated admin panel to start/stop the inference service and inspect audit logs. | [`lib/screens/settings/admin_control_screen.dart`](file:///E:/project/kushi/lib/screens/settings/admin_control_screen.dart) |

---

## 2. User Journey 1: Leaf Scanning & Disease Diagnosis

```mermaid
flowchart TD
    START(["Farmer opens Cotton Guard"]) --> HOME["Home Dashboard Screen"]
    HOME -->|Tap Bottom Nav Scan Tab or Action Button| SCAN["ScanScreen (Viewfinder Active)"]
    
    SCAN -->|Tap 'Take Photo'| CAM["Device Camera Captures Leaf"]
    SCAN -->|Tap 'Gallery'| GAL["Photo Gallery Image Selected"]
    
    CAM --> PREVIEW["ImagePreviewScreen<br/>(Review Image Focus)"]
    GAL --> PREVIEW
    
    PREVIEW -->|Tap 'Retake'| SCAN
    PREVIEW -->|Tap 'Analyze with AI'| ANALYSIS["AIAnalysisScreen<br/>(Laser Scanning Animation)"]
    
    ANALYSIS --> API_CALL{"POST /api/v1/predict<br/>(45s Timeout)"}
    
    API_CALL -->|HTTP 422: POOR_QUALITY| ERR_Q["Display Quality Dialog<br/>(Blurry / Dark / Glare)"]
    API_CALL -->|HTTP 422: NON_COTTON| ERR_C["Display Domain Dialog<br/>(Non-plant / Non-cotton)"]
    API_CALL -->|Timeout / Network Error| ERR_NET["Display Connection Error<br/>(Retain Image, Tap to Retry)"]
    
    ERR_Q --> PREVIEW
    ERR_C --> PREVIEW
    ERR_NET --> PREVIEW
    
    API_CALL -->|HTTP 200: Success| DIAGNOSIS["DiagnosisResultScreen<br/>(Display Disease & Cures)"]
    
    DIAGNOSIS --> AUTO_SAVE["Auto-Save to Scan History<br/>(SharedPreferences)"]
    DIAGNOSIS --> TABS{"Inspect Agronomic Guidance"}
    
    TABS --> TAB_SYM["Botanical Symptoms"]
    TABS --> TAB_CHEM["Chemical Cures & Dosages"]
    TABS --> TAB_ORG["Organic & Preventive Controls"]
```

---

## 3. User Journey 2: Farmer Onboarding & Authentication

```mermaid
flowchart TD
    BOOT(["App Boots"]) --> SPLASH["SplashScreen<br/>(Bootstrap SharedPreferences)"]
    
    SPLASH --> CHECK_FIRST{"Is First App Launch?"}
    CHECK_FIRST -->|Yes| ONBOARD["OnboardingScreen<br/>(3 Feature Slides)"]
    ONBOARD --> LOGIN["LoginScreen"]
    
    CHECK_FIRST -->|No| CHECK_AUTH{"Has Stored Auth Token?"}
    CHECK_AUTH -->|Yes| MAIN["MainNavigationShell<br/>(HomeDashboardScreen)"]
    CHECK_AUTH -->|No| LOGIN
    
    LOGIN --> AUTH_CHOICE{"Authentication Method"}
    
    AUTH_CHOICE -->|Email & Password| SUBMIT_EMAIL["POST /api/v1/auth/login"]
    AUTH_CHOICE -->|Google Sign-In| SUBMIT_GOOGLE["POST /api/v1/auth/google<br/>(Verified ID Token)"]
    AUTH_CHOICE -->|New Farmer| SIGNUP["SignupScreen<br/>(Name, Email, District)"]
    
    SIGNUP --> SUBMIT_REG["POST /api/v1/auth/register<br/>(Assigned: Cotton Farmer)"]
    
    SUBMIT_EMAIL -->|200 OK| SAVE_SESSION["Save Token & Profile<br/>in SharedPreferences"]
    SUBMIT_GOOGLE -->|200 OK| SAVE_SESSION
    SUBMIT_REG -->|200 OK| SAVE_SESSION
    
    SAVE_SESSION --> MAIN
```

---

## 4. User Journey 3: Historical Review & Crop Analytics

```mermaid
flowchart TD
    DASH["HomeDashboardScreen"] --> NAV_HIST["Tap History Tab"]
    NAV_HIST --> HIST_SCREEN["HistoryScreen<br/>(Loads SharedPreferences Cache)"]
    
    HIST_SCREEN --> SEARCH["Filter by Condition Name<br/>or Tab: All / Diseased / Healthy"]
    HIST_SCREEN --> SELECT_RECORD["Tap on History Card"]
    
    SELECT_RECORD --> DETAIL["HistoryDetailScreen<br/>(Displays Cached Leaf Image & Diagnosis)"]
    DETAIL --> BACK["Return to History"]
    
    HIST_SCREEN --> INSIGHTS_BTN["Tap 'Crop Insights'"]
    INSIGHTS_BTN --> INSIGHTS["InsightsScreen<br/>(Displays Health Ratio Pie Chart & Total Stats)"]
```

---

## 5. User Journey 4: Administrative Service Control

```mermaid
flowchart TD
    PROFILE["ProfileScreen (Admin User)"] --> ADMIN_BTN["Tap 'Admin Control Center'"]
    ADMIN_BTN --> ADMIN_SCREEN["AdminControlScreen"]
    
    ADMIN_SCREEN --> GET_STATE["GET /api/v1/admin/service/state<br/>(Sends Bearer Token or X-Admin-Key)"]
    GET_STATE --> DISPLAY_STATE["Displays Status: RUNNING / STOPPED<br/>+ Memory State + Recent 10 Audit Logs"]
    
    DISPLAY_STATE --> ACTION{"Admin Action"}
    
    ACTION -->|Tap 'Stop Service'| POST_STOP["POST /api/v1/admin/service/stop"]
    POST_STOP --> UNLOAD["Server sets ORT_SESSION=None<br/>and runs gc.collect()"]
    UNLOAD --> LOG_STOP["Record in service_audit_logs"]
    LOG_STOP --> DISPLAY_STATE
    
    ACTION -->|Tap 'Start Service'| POST_START["POST /api/v1/admin/service/start"]
    POST_START --> RELOAD["Server reloads ONNX session into RAM"]
    RELOAD --> LOG_START["Record in service_audit_logs"]
    LOG_START --> DISPLAY_STATE
```
