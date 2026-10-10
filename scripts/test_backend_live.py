"""Live Backend Endpoints QA Verification Script."""

__test__ = False

import urllib.request
import urllib.parse
import json
import os
import io
import mimetypes

def make_multipart_body(field_name, file_path, content_type="image/jpeg"):
    boundary = "----WebKitFormBoundary7MA4YWxkTrZu0gW"
    with open(file_path, "rb") as f:
        file_bytes = f.read()
    filename = os.path.basename(file_path)

    body = (
        f"--{boundary}\r\n"
        f'Content-Disposition: form-data; name="{field_name}"; filename="{filename}"\r\n'
        f"Content-Type: {content_type}\r\n\r\n"
    ).encode("utf-8") + file_bytes + f"\r\n--{boundary}--\r\n".encode("utf-8")

    return body, boundary

def execute_endpoint_test(name, url, method="GET", data=None, headers=None, expected_status=200):
    req = urllib.request.Request(url, data=data, method=method)
    if headers:
        for k, v in headers.items():
            req.add_header(k, v)
    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            status_code = response.status
            body = response.read().decode("utf-8")
            parsed = json.loads(body) if body else {}
            is_match = (status_code == expected_status)
            print(f"[{'PASS' if is_match else 'FAIL'}] {name:35s} | HTTP {status_code} | Exp: {expected_status}")
            return status_code, parsed
    except urllib.error.HTTPError as e:
        status_code = e.code
        body = e.read().decode("utf-8")
        is_match = (status_code == expected_status)
        print(f"[{'PASS' if is_match else 'FAIL'}] {name:35s} | HTTP {status_code} | Exp: {expected_status} | Err: {body[:60]}...")
        return status_code, body
    except Exception as e:
        print(f"[FAIL] {name:35s} | Network Error: {e}")
        return None, str(e)

def main():
    base_url = "http://127.0.0.1:8000/api/v1"
    print("=" * 60)
    print("FASTAPI BACKEND ENDPOINTS QA TEST")
    print("=" * 60)

    # 1. Health
    status, health_data = execute_endpoint_test(
        "GET /health",
        f"{base_url}/health",
        expected_status=200
    )
    if isinstance(health_data, dict):
        print(f"       -> Status: {health_data.get('status')} | Engine: {health_data.get('inference_engine')} | Model: {health_data.get('model_name')}")

    # 2. Advisory All
    status, advisory_data = execute_endpoint_test(
        "GET /advisory/all",
        f"{base_url}/advisory/all",
        expected_status=200
    )
    if isinstance(advisory_data, dict):
        total_advisories = len(advisory_data.get("advisories", {}))
        print(f"       -> Loaded advisories for {total_advisories} classes")

    # 3. Fields
    status, fields_data = execute_endpoint_test(
        "GET /fields",
        f"{base_url}/fields",
        expected_status=200
    )
    if isinstance(fields_data, dict):
        print(f"       -> Total fields: {fields_data.get('total_fields')} | Regions: {fields_data.get('monitored_regions')}")

    # 4. Disease Details (All 7 classes + 1 invalid)
    classes = [
        "Bacterial Blight",
        "Cotton Leaf Curl Virus",
        "Healthy Leaf",
        "Herbicide Growth Damage",
        "Leaf Hopper / Jassids",
        "Leaf Reddening",
        "Leaf Variegation"
    ]
    for c in classes:
        encoded = urllib.parse.quote(c)
        execute_endpoint_test(
            f"GET /disease/{c}",
            f"{base_url}/disease/{encoded}",
            expected_status=200
        )

    # Invalid disease name
    execute_endpoint_test(
        "GET /disease/Unknown_Disease_123",
        f"{base_url}/disease/Unknown_Disease_123",
        expected_status=404
    )

    # 5. POST /predict with a real valid leaf image
    valid_img_path = "assets/diseases/bacterial_blight/bacterial_blight_1.jpg"
    body, boundary = make_multipart_body("file", valid_img_path)
    status, pred_data = execute_endpoint_test(
        "POST /predict (Valid Leaf)",
        f"{base_url}/predict",
        method="POST",
        data=body,
        headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
        expected_status=200
    )
    if isinstance(pred_data, dict):
        print(f"       -> Predicted: {pred_data.get('predicted_class')} ({pred_data.get('confidence')*100:.2f}%) | Latency: {pred_data.get('latency_ms'):.1f}ms")

    # 6. POST /predict with an invalid non-image file
    dummy_text = b"This is just a text file, not an image!"
    boundary = "----WebKitFormBoundary7MA4YWxkTrZu0gW"
    invalid_body = (
        f"--{boundary}\r\n"
        f'Content-Disposition: form-data; name="file"; filename="test.txt"\r\n'
        f"Content-Type: text/plain\r\n\r\n"
    ).encode("utf-8") + dummy_text + f"\r\n--{boundary}--\r\n".encode("utf-8")

    execute_endpoint_test(
        "POST /predict (Invalid Text File)",
        f"{base_url}/predict",
        method="POST",
        data=invalid_body,
        headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
        expected_status=400
    )

    print("\nBackend testing completed.")

if __name__ == "__main__":
    main()
