# 16 — End-to-End Execution Flows & Sequence Traces

This document provides detailed sequence diagrams and technical execution traces for the critical operational flows within **Cotton Guard**.

---

## Flow A: Cold-Start Request Lifecycle (Free-Tier Cloud Recovery)

```mermaid
sequenceDiagram
    autonumber
    actor Farmer as Cotton Farmer
    participant App as Mobile App
    participant Edge as Render Edge Gateway
    participant Container as Docker Container
    participant Backend as FastAPI / Uvicorn
    participant ONNX as ONNX Runtime
    participant DB as Neon PostgreSQL

    Farmer->>App: Tap "Analyze with AI"
    App->>App: Start 45s connection timer
    App->>Edge: POST /api/v1/predict (multipart)
    
    rect rgb(30, 20, 20)
        Note over Edge,Container: Container Cold Start (~30-40s)
        Edge->>Container: Spin up suspended Docker container
        Container->>Backend: Boot Uvicorn on 0.0.0.0:7860
        Backend->>DB: Connect via DATABASE_URL & run init_database()
        DB-->>Backend: Connection established (SSL)
        Backend->>ONNX: load_inference_session() (Load cotton_guard_model.onnx)
        ONNX-->>Backend: Session READY
        Backend-->>Edge: Container listener active on port 7860
    end
    
    Edge->>Backend: Forward queued POST /api/v1/predict request
    Backend->>Backend: Process image through 5-stage pipeline
    Backend-->>Edge: HTTP 200 OK (Prediction Result)
    Edge-->>App: Forward response
    App->>App: Cancel 45s timer & display DiagnosisResultScreen
    App-->>Farmer: Present diagnosis & agronomic spray advice
```

---

## Flow B: Normal Leaf Scanning & Prediction Sequence

```mermaid
sequenceDiagram
    autonumber
    actor Farmer as Cotton Farmer
    participant Viewfinder as ScanScreen
    participant Preview as ImagePreviewScreen
    participant Analysis as AIAnalysisScreen
    participant Api as ApiService
    participant Gate as CottonDomainGate
    participant ML as ONNX Runtime Engine
    participant DB as Knowledge Base
    participant Storage as SharedPreferences

    Farmer->>Viewfinder: Point camera & tap "Take Photo"
    Viewfinder->>Preview: Pass captured file path
    Farmer->>Preview: Tap "Analyze with AI"
    Preview->>Analysis: Transition to scanning animation
    Analysis->>Api: predictDisease(imageBytes, fileName)
    
    Api->>Gate: validate_file_payload()
    Gate-->>Api: Byte length (200B-15MB) & format valid
    
    Api->>Gate: evaluate_quality_and_domain()
    Gate-->>Api: Brightness OK, Blur score >= 15, Foliage >= 15%
    
    Api->>ML: Run preprocess_image() (CIELAB-CLAHE) & Inference
    ML-->>Api: Logits -> Softmax probabilities (Top-1: 98.5%)
    
    Api->>Gate: evaluate_prediction_uncertainty()
    Gate-->>Api: Prediction confident (margin > 0.12)
    
    Api->>DB: get_advisory_for_class("Bacterial Blight")
    DB-->>Api: Return symptoms, chemical treatments, prevention
    
    Api-->>Analysis: Return PredictionResult
    Analysis->>Storage: Serialize & save ScanRecord into history
    Analysis->>Farmer: Navigate to DiagnosisResultScreen
```

---

## Flow C: Rejected Low-Quality & Non-Plant Scan Handling

```mermaid
sequenceDiagram
    autonumber
    actor Farmer as Cotton Farmer
    participant App as Mobile App
    participant Backend as FastAPI Server
    participant Gate as CottonDomainGate

    Farmer->>App: Captures blurry or non-plant image
    Farmer->>App: Taps "Analyze with AI"
    App->>Backend: POST /api/v1/predict
    
    Backend->>Gate: evaluate_quality_and_domain(image)
    
    alt Image is Blurry (Sharpness < 15.0)
        Gate-->>Backend: quality_passed: false (code: "POOR_QUALITY")
        Backend-->>App: HTTP 422 {code: "POOR_QUALITY", message: "Image is blurry..."}
        App-->>Farmer: Show Dialog: "Blurry Image. Hold camera steady and tap to focus."
    else Image is Non-Plant (Foliage Coverage < 15%)
        Gate-->>Backend: is_cotton_leaf: false (code: "NON_COTTON")
        Backend-->>App: HTTP 422 {code: "NON_COTTON", message: "Non-plant detected..."}
        App-->>Farmer: Show Dialog: "Unsupported Subject. Center a cotton leaf in frame."
    end
    
    Note over App,Farmer: User's image is retained in preview; zero re-capture friction
    Farmer->>App: Re-aligns camera and retries
```

---

## Flow D: Administrative Service Lifecycle & Memory Management

```mermaid
sequenceDiagram
    autonumber
    actor Admin as System Administrator
    participant Screen as AdminControlScreen
    participant Backend as FastAPI Server
    participant State as ServiceState Coordinator
    participant RAM as Server Memory (RAM)
    participant Logs as service_audit_logs Table

    Admin->>Screen: Open Admin Control Center
    Screen->>Backend: GET /api/v1/admin/service/state (Bearer Token)
    Backend-->>Screen: State: RUNNING, Model: Loaded (~180 MB RAM)
    
    Admin->>Screen: Tap "Pause Inference Engine"
    Screen->>Backend: POST /api/v1/admin/service/stop
    Backend->>State: stop_service(admin_email)
    State->>RAM: Set ORT_SESSION = None & invoke gc.collect()
    RAM-->>State: ~180 MB RAM released to OS
    State->>Logs: INSERT INTO service_audit_logs ("STOP_SERVICE")
    Backend-->>Screen: HTTP 200 {status: "STOPPED", message: "Service stopped"}
    
    Note over Backend: Any public /predict call now returns HTTP 503
    
    Admin->>Screen: Tap "Resume Inference Engine"
    Screen->>Backend: POST /api/v1/admin/service/start
    Backend->>State: start_service(admin_email)
    State->>RAM: Reload ONNX session from cotton_guard_model.onnx
    RAM-->>State: Model active in RAM
    State->>Logs: INSERT INTO service_audit_logs ("START_SERVICE")
    Backend-->>Screen: HTTP 200 {status: "RUNNING", message: "Service resumed"}
```

---

## Flow E: Weather Intelligence & District Selection Flow

```mermaid
sequenceDiagram
    autonumber
    actor Farmer as Cotton Farmer
    participant Dash as HomeDashboardScreen
    participant Sheet as LocationPickerSheet
    participant Weather as WeatherService
    participant Meteo as Open-Meteo Free API

    Farmer->>Dash: Tap District Header (e.g. "Warangal, Telangana")
    Dash->>Sheet: Open LocationPickerSheet
    Farmer->>Sheet: Search "Guntur" & select "Guntur, Andhra Pradesh"
    Sheet->>Sheet: Retrieve GPS Coordinates (Lat: 16.3067, Lon: 80.4365)
    Sheet-->>Dash: Update active location & save in SharedPreferences
    
    Dash->>Weather: getWeather(lat: 16.3067, lon: 80.4365)
    Weather->>Meteo: GET https://api.open-meteo.com/v1/forecast?...
    Meteo-->>Weather: HTTP 200 {temp: 31.2, humidity: 78, rain_prob: 25}
    Weather-->>Dash: Return WeatherData object
    Dash-->>Farmer: Render live weather card with agronomic advisory alert
```
