# 15 — Complete API Reference Specification

This document provides a complete RESTful API reference for the **Cotton Guard** backend server.

**Base URLs**:
- **Production Cloud**: `https://cotton-guard.onrender.com/api/v1`
- **Local Container / Development**: `http://localhost:7860/api/v1`
- **Interactive Documentation**: `https://cotton-guard.onrender.com/docs` (Swagger UI)

---

## 1. System Health & Core Endpoints

### 1.1 Root Service Status
- **Method**: `GET`
- **Paths**: `/` or `/api/v1`
- **Authentication**: None (Public)
- **Response `200 OK`**:
```json
{
  "status": "ONLINE",
  "app": "Cotton Guard AI API",
  "version": "1.0.0",
  "model_status": "READY",
  "health_endpoint": "/api/v1/health",
  "docs_url": "/docs"
}
```

---

### 1.2 System Health Check
- **Method**: `GET`
- **Paths**: `/health` or `/api/v1/health`
- **Authentication**: None (Public)
- **Response `200 OK`**:
```json
{
  "status": "CONNECTED",
  "version": "1.0.0",
  "uptime_seconds": 14285.2,
  "model_loaded": true,
  "model_name": "MobileNetV3-Large + CBAM Attention (Hybrid CLAHE)",
  "inference_engine": "ONNX Runtime",
  "cotton_validation_ready": true,
  "disease_model_ready": true,
  "supported_classes": [
    "Bacterial Blight",
    "Cotton Leaf Curl Virus",
    "Healthy Leaf",
    "Herbicide Growth Damage",
    "Leaf Hopper / Jassids",
    "Leaf Reddening",
    "Leaf Variegation"
  ],
  "timestamp": "2026-10-10T14:30:00Z"
}
```

---

## 2. Disease Diagnostic & Agronomic Endpoints

### 2.1 Predict Cotton Leaf Disease
- **Method**: `POST`
- **Paths**: `/predict` or `/api/v1/predict`
- **Authentication**: None (Public)
- **Content-Type**: `multipart/form-data`
- **Parameters**:
  - `file`: Raw binary image file (JPEG, PNG, or WEBP; maximum size 15 MB).

#### Success Response `200 OK`:
```json
{
  "success": true,
  "predicted_class": "Bacterial Blight",
  "confidence": 0.9854,
  "is_low_confidence": false,
  "severity": "Moderate to High",
  "severity_level": 3,
  "is_healthy": false,
  "scientific_name": "Xanthomonas citri pv. malvacearum",
  "summary": "Water-soaked angular leaf spots bounded by veinlets, progressing to dark brown necrotic lesions.",
  "symptoms": [
    "Small water-soaked angular leaf spots bounded by veins",
    "Lesions turn reddish-brown then black necrotic",
    "Vein blight causing systemic leaf shedding"
  ],
  "treatment": [
    "Apply Copper Oxychloride 50 WP @ 2.5 g/L + Streptocycline @ 100 mg/L as foliar spray upon first symptom detection.",
    "Repeat spray after 12-15 days if humid weather persists."
  ],
  "prevention": [
    "Treat planting seeds with Streptocycline (100 ppm) before sowing.",
    "Adopt certified resistant Bt cultivars."
  ],
  "advisory": [
    "Apply Copper Oxychloride 50 WP @ 2.5 g/L + Streptocycline @ 100 mg/L as foliar spray upon first symptom detection."
  ],
  "favorable_conditions": "High humidity (>85%), warm temperatures (28-32°C).",
  "quality_metrics": {
    "width": 1024,
    "height": 768,
    "brightness": 124.5,
    "blur_score": 142.8,
    "foliage_ratio": 0.68
  },
  "latency_ms": 18.25,
  "model_name": "MobileNetV3-Large + CBAM Attention (Hybrid CLAHE)",
  "engine": "ONNX Runtime",
  "knowledge_base": "SQLite (advisory.db)"
}
```

#### Error Responses:
- **`400 Bad Request`**: Image file empty, corrupt, or unsupported file type.
- **`413 Payload Too Large`**: Uploaded image exceeds 15 MB.
- **`422 Unprocessable Content (POOR_QUALITY)`**: Image is underexposed ($<30$), overexposed ($>245$), or blurry (blur score $< 15.0$).
  ```json
  {
    "detail": {
      "code": "POOR_QUALITY",
      "message": "Image is out of focus or blurry (sharpness score: 8.2). Hold camera steady.",
      "metrics": { "width": 800, "height": 600, "brightness": 110.2, "blur_score": 8.2, "foliage_ratio": 0.0 }
    }
  }
  ```
- **`422 Unprocessable Content (NON_COTTON)`**: Image lacks botanical foliage ($<15\%$ leaf pixels) or shows synthetic non-biological texture.
  ```json
  {
    "detail": {
      "code": "NON_COTTON",
      "message": "Non-plant or unsupported input detected (foliage coverage 4.1% < 15%).",
      "metrics": { "width": 800, "height": 600, "brightness": 130.0, "blur_score": 85.0, "foliage_ratio": 0.041 }
    }
  }
  ```
- **`503 Service Unavailable`**: Inference service is paused or stopped by administrator.

---

### 2.2 Comprehensive Advisory Catalog
- **Method**: `GET`
- **Paths**: `/advisory/all` or `/api/v1/advisory/all`
- **Authentication**: None (Public)
- **Response `200 OK`**: Returns complete catalog of all 7 conditions, treatments, symptoms, and 4 general agronomic care practices.

---

### 2.3 Single Disease Profile
- **Method**: `GET`
- **Paths**: `/disease/{class_name}` or `/api/v1/disease/{class_name}`
- **Authentication**: None (Public)
- **Path Parameter**: `class_name` (Supports slugs and canonical names, e.g. `bacterial_blight`, `Leaf Reddening`, `curl_virus`).
- **Response `200 OK`**:
```json
{
  "class_name": "Leaf Reddening",
  "knowledge_base": "SQLite (advisory.db)",
  "details": {
    "canonical_name": "Leaf Reddening",
    "scientific_name": "Physiological Anthocyanosis & Nutrient Deficiency",
    "summary": "Premature physiological reddening of cotton leaves triggered by magnesium deficiency.",
    "severity": "Mild to Moderate",
    "severity_level": 2,
    "symptoms": ["Interveinal leaf tissue turns bronze then deep purplish-red"],
    "treatment": ["Foliar spray of 1% Magnesium Sulphate + 1% Urea at first reddening onset."],
    "prevention": ["Basal soil application of Magnesium Sulphate @ 10-15 kg/acre."]
  }
}
```

---

### 2.4 Agricultural Regions & Zones
- **Method**: `GET`
- **Paths**: `/fields` or `/api/v1/fields`
- **Authentication**: None (Public)
- **Response `200 OK`**: Returns soil types, sowing windows, and major varieties across Indian cotton zones (Southern, Central, Northern, Transition).

---

## 3. User Authentication Endpoints

### 3.1 Register User
- **Method**: `POST`
- **Paths**: `/auth/register` or `/api/v1/auth/register`
- **Authentication**: None (Public)
- **Request Body**:
```json
{
  "email": "farmer@example.com",
  "password": "SecurePassword123",
  "full_name": "Ravi Kumar",
  "phone": "+91 9876543210",
  "location": "Warangal, Telangana",
  "latitude": 17.9689,
  "longitude": 79.5941
}
```
- **Response `200 OK`**: Returns session token and user profile with `role: "Cotton Farmer"`.
- **Response `403 Forbidden`**: Returned if client attempts to self-assign an admin role.
- **Response `409 Conflict`**: Account with email already exists.

---

### 3.2 Login User
- **Method**: `POST`
- **Paths**: `/auth/login` or `/api/v1/auth/login`
- **Authentication**: None (Public)
- **Request Body**:
```json
{
  "email": "farmer@example.com",
  "password": "SecurePassword123"
}
```
- **Response `200 OK`**: Returns session token and user profile.
- **Response `401 Unauthorized`**: Invalid email or password.

---

### 3.3 Google OAuth Authentication
- **Method**: `POST`
- **Paths**: `/auth/google` or `/api/v1/auth/google`
- **Authentication**: None (Public)
- **Request Body**:
```json
{
  "id_token": "eyJhbGciOiJSUzI1NiIs..."
}
```
- **Response `200 OK`**: Verifies token with Google and returns session token.

---

### 3.4 Retrieve Current Profile
- **Method**: `GET`
- **Paths**: `/auth/me` or `/api/v1/auth/me`
- **Headers**: `Authorization: Bearer <token>`
- **Response `200 OK`**: Current user profile.

---

## 4. Administrative Control Plane Endpoints

All admin endpoints require either:
- Header: `Authorization: Bearer <admin_token>`
- Header: `X-Admin-Key: <ADMIN_API_KEY>`

### 4.1 Get Service State
- **Method**: `GET`
- **Paths**: `/admin/service/state` or `/api/v1/admin/service/state`
- **Response `200 OK`**:
```json
{
  "success": true,
  "admin_caller": "admin@cottonguard.org",
  "service_status": {
    "status": "RUNNING",
    "uptime_seconds": 14290.0,
    "predictions_served": 48
  },
  "model_loaded": true,
  "recent_audit_logs": [...]
}
```

---

### 4.2 Start / Resume Inference Service
- **Method**: `POST`
- **Paths**: `/admin/service/start` or `/api/v1/admin/service/start`
- **Response `200 OK`**: Reloads ONNX session into RAM and returns updated status.

---

### 4.3 Stop / Pause Inference Service
- **Method**: `POST`
- **Paths**: `/admin/service/stop` or `/api/v1/admin/service/stop`
- **Response `200 OK`**: Unloads ONNX model from RAM, triggers garbage collection, and returns updated status.

---

### 4.4 Get Service Audit Logs
- **Method**: `GET`
- **Paths**: `/admin/service/logs` or `/api/v1/admin/service/logs`
- **Query Parameter**: `limit` (default: 50)
- **Response `200 OK`**: List of all recorded administrative start/stop operations with timestamps and caller IDs.
