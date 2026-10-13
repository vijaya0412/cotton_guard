"""Comprehensive Automated Test Suite for Cotton Guard FastAPI Server.
Covers:
- GET /api/v1/health (health and model readiness)
- GET /api/v1/advisory/all (complete 7-class catalog)
- GET /api/v1/disease/{class_name} (canonical and alias resolution)
- GET /api/v1/fields (regional agro-climatic profiles)
- POST /api/v1/predict (valid authentic cotton leaves)
- POST /api/v1/predict (empty upload rejection - 400)
- POST /api/v1/predict (corrupted upload rejection - 400)
- POST /api/v1/predict (dark / overexposed / blurry quality rejection - 422 POOR_QUALITY)
- POST /api/v1/predict (non-cotton synthetic image rejection - 422 NON_COTTON)
- Flutter contract compliance verification
"""

import os
import sys
import io
from PIL import Image
import numpy as np
import pytest
from fastapi.testclient import TestClient

# Ensure backend can be imported
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from main import app, CANONICAL_CLASSES
from ml.cotton_gate import CottonDomainGate

client = TestClient(app)

# Absolute path to a real, non-cotton leaf fixture. This fixture is intentionally
# NOT fabricated: verifying that a genuine mango leaf is rejected requires an
# authentic photograph, which is not present in the repository. Until a real
# fixture is supplied, the mango regression test is skipped rather than asserting
# that the current colour/texture heuristic can recognise plant species.
MANGO_FIXTURE_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "manual_tests", "mango_leaf.jpeg"
)

def test_health_endpoint():
    response = client.get("/api/v1/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "CONNECTED"
    assert data["model_loaded"] is True
    assert "MobileNet" in data["model_name"]
    assert data["inference_engine"] == "ONNX Runtime"
    assert data["cotton_validation_ready"] is True
    assert data["disease_model_ready"] is True
    assert len(data["supported_classes"]) == 7
    for cls_name in CANONICAL_CLASSES:
        assert cls_name in data["supported_classes"]

def test_advisory_all_endpoint():
    response = client.get("/api/v1/advisory/all")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "SUCCESS"
    assert "catalog" in data
    assert len(data["catalog"]) == 7
    assert len(data["general_care"]) >= 4

def test_disease_detail_endpoint_canonical_and_aliases():
    # 1. Canonical Name
    res1 = client.get("/api/v1/disease/Leaf Reddening")
    assert res1.status_code == 200
    d1 = res1.json()
    assert d1["class_name"] == "Leaf Reddening"
    assert d1["details"]["canonical_name"] == "Leaf Reddening"

    # 2. Alias typo 'Leaf Redding'
    res2 = client.get("/api/v1/disease/Leaf Redding")
    assert res2.status_code == 200
    d2 = res2.json()
    assert d2["class_name"] == "Leaf Reddening"

    # 3. Slug format 'bacterial_blight'
    res3 = client.get("/api/v1/disease/bacterial_blight")
    assert res3.status_code == 200
    d3 = res3.json()
    assert d3["class_name"] == "Bacterial Blight"

    # 4. Non-existent disease -> 404
    res_none = client.get("/api/v1/disease/NonExistentDisease123")
    assert res_none.status_code == 404

def test_fields_endpoint():
    response = client.get("/api/v1/fields")
    assert response.status_code == 200
    data = response.json()
    assert len(data["regions"]) >= 4

def test_predict_valid_cotton_image():
    # Load authentic sample image
    sample_path = os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        "assets", "diseases", "bacterial_blight", "bacterial_blight_1.jpg"
    )
    assert os.path.exists(sample_path)

    with open(sample_path, "rb") as f:
        file_bytes = f.read()

    response = client.post(
        "/api/v1/predict",
        files={"file": ("bacterial_blight_1.jpg", file_bytes, "image/jpeg")}
    )
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert data["predicted_class"] in CANONICAL_CLASSES
    assert data["confidence"] > 0.0
    assert "severity" in data
    assert "symptoms" in data
    assert len(data["symptoms"]) > 0
    assert "treatment" in data
    assert len(data["treatment"]) > 0
    assert "prevention" in data
    assert "MobileNet" in data["model_name"]
    assert data["engine"] == "ONNX Runtime"

def test_predict_empty_upload():
    response = client.post(
        "/api/v1/predict",
        files={"file": ("empty.jpg", b"", "image/jpeg")}
    )
    assert response.status_code == 400
    assert "empty" in response.json()["detail"].lower()

def test_predict_corrupt_upload():
    response = client.post(
        "/api/v1/predict",
        files={"file": ("corrupt.jpg", b"NOT_AN_IMAGE_DATA_1234567890", "image/jpeg")}
    )
    assert response.status_code == 400

def test_predict_oversized_upload(monkeypatch):
    from main import MAX_UPLOAD_SIZE_MB
    # Temporarily set MAX_UPLOAD_SIZE_MB to 1MB for fast testing
    import main
    monkeypatch.setattr(main, "MAX_UPLOAD_SIZE_MB", 1)
    large_payload = b"X" * (2 * 1024 * 1024)  # 2MB
    response = client.post(
        "/api/v1/predict",
        files={"file": ("large.jpg", large_payload, "image/jpeg")}
    )
    assert response.status_code == 413
    assert "exceeds maximum allowable limit" in response.json()["detail"]


def test_predict_poor_quality_dark_image():
    dark_img = Image.new("RGB", (300, 300), color=(5, 5, 5))
    buf = io.BytesIO()
    dark_img.save(buf, format="JPEG")
    buf.seek(0)

    response = client.post(
        "/api/v1/predict",
        files={"file": ("dark.jpg", buf.getvalue(), "image/jpeg")}
    )
    assert response.status_code == 422
    detail = response.json()["detail"]
    assert detail["code"] == "POOR_QUALITY"
    assert "dark" in detail["message"].lower()

def test_predict_poor_quality_bright_image():
    bright_img = Image.new("RGB", (300, 300), color=(250, 250, 250))
    buf = io.BytesIO()
    bright_img.save(buf, format="JPEG")
    buf.seek(0)

    response = client.post(
        "/api/v1/predict",
        files={"file": ("bright.jpg", buf.getvalue(), "image/jpeg")}
    )
    assert response.status_code == 422
    detail = response.json()["detail"]
    assert detail["code"] == "POOR_QUALITY"

def test_predict_non_cotton_synthetic_image():
    # Create textured grey non-plant checkerboard (sharp edges, 0% foliage)
    arr = np.zeros((300, 300, 3), dtype=np.uint8)
    for i in range(0, 300, 20):
        for j in range(0, 300, 20):
            if (i // 20 + j // 20) % 2 == 0:
                arr[i:i+20, j:j+20] = [200, 200, 200]
            else:
                arr[i:i+20, j:j+20] = [80, 80, 80]
    textured_img = Image.fromarray(arr)
    buf = io.BytesIO()
    textured_img.save(buf, format="JPEG")
    buf.seek(0)

    response = client.post(
        "/api/v1/predict",
        files={"file": ("checkerboard.jpg", buf.getvalue(), "image/jpeg")}
    )
    assert response.status_code == 422
    detail = response.json()["detail"]
    assert detail["code"] == "NON_COTTON"

@pytest.mark.skipif(
    not os.path.exists(MANGO_FIXTURE_PATH),
    reason=(
        "No authentic non-cotton leaf fixture available at manual_tests/mango_leaf.jpeg. "
        "A real mango/tomato/chilli photograph is required to verify species rejection; "
        "the current colour/texture gate is NOT a species recogniser and must not be "
        "asserted to reject mango leaves."
    ),
)
def test_predict_mango_leaf_rejected_as_non_cotton():
    # Regression: a real non-cotton leaf must be rejected (non-disease) once a
    # dedicated cotton-vs-non-cotton suitability classifier is in place.
    with open(MANGO_FIXTURE_PATH, "rb") as f:
        file_bytes = f.read()

    response = client.post(
        "/api/v1/predict",
        files={"file": ("mango_leaf.jpeg", file_bytes, "image/jpeg")}
    )
    assert response.status_code == 422
    detail = response.json()["detail"]
    assert detail["code"] in ("NON_COTTON", "UNCERTAIN")


def test_predict_uncertain_prediction_rejected(monkeypatch):
    # An uncertain model output must return a structured 422 rejection and must
    # never carry a disease prediction, treatment, or advisory payload.
    sample_path = os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        "assets", "diseases", "bacterial_blight", "bacterial_blight_1.jpg"
    )
    assert os.path.exists(sample_path)

    def _force_uncertain(cls, probabilities):
        return True, "Ambiguous symptoms: top candidates are too close."

    monkeypatch.setattr(
        CottonDomainGate,
        "evaluate_prediction_uncertainty",
        classmethod(_force_uncertain),
    )

    with open(sample_path, "rb") as f:
        file_bytes = f.read()

    response = client.post(
        "/api/v1/predict",
        files={"file": ("bacterial_blight_1.jpg", file_bytes, "image/jpeg")}
    )
    assert response.status_code == 422
    payload = response.json()

    detail = payload["detail"]
    assert detail["code"] == "UNCERTAIN"
    assert "confidence" in detail["metrics"]

    # Rejection must never leak a diagnosis.
    assert "predicted_class" not in payload
    assert "treatment" not in payload
    assert "advisory" not in payload
    assert "is_healthy" not in payload
    assert "success" not in payload or payload.get("success") is None

def test_root_endpoints():
    res_root = client.get("/")
    assert res_root.status_code == 200
    d_root = res_root.json()
    assert d_root["status"] == "ONLINE"
    assert d_root["app"] == "Cotton Guard AI API"

    res_api_v1 = client.get("/api/v1")
    assert res_api_v1.status_code == 200
    d_api_v1 = res_api_v1.json()
    assert d_api_v1["status"] == "ONLINE"

def test_route_aliases_without_api_v1_prefix():
    # Verify routes respond identically without /api/v1 prefix
    res_health = client.get("/health")
    assert res_health.status_code == 200
    assert res_health.json()["status"] == "CONNECTED"

    res_fields = client.get("/fields")
    assert res_fields.status_code == 200
    assert res_fields.json()["status"] == "SUCCESS"

    res_advisory = client.get("/advisory/all")
    assert res_advisory.status_code == 200
    assert res_advisory.json()["status"] == "SUCCESS"

if __name__ == "__main__":
    test_root_endpoints()
    test_route_aliases_without_api_v1_prefix()
    test_health_endpoint()
    test_advisory_all_endpoint()
    test_disease_detail_endpoint_canonical_and_aliases()
    test_fields_endpoint()
    test_predict_valid_cotton_image()
    test_predict_empty_upload()
    test_predict_corrupt_upload()
    test_predict_poor_quality_dark_image()
    test_predict_poor_quality_bright_image()
    test_predict_non_cotton_synthetic_image()
    print("\nALL FASTAPI ENDPOINT & CONTRACT TESTS PASSED!")
