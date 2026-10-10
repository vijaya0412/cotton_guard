import urllib.request
import uuid
import json

def test_live_predict(image_path):
    url = 'http://127.0.0.1:8000/predict'
    boundary = uuid.uuid4().hex
    with open(image_path, 'rb') as f:
        file_bytes = f.read()
    filename = image_path.replace('\\', '/').split('/')[-1]

    parts = []
    parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="{filename}"\r\nContent-Type: image/jpeg\r\n\r\n'.encode('utf-8'))
    parts.append(file_bytes)
    parts.append(f'\r\n--{boundary}--\r\n'.encode('utf-8'))
    body = b''.join(parts)

    req = urllib.request.Request(url, data=body, headers={
        'Content-Type': f'multipart/form-data; boundary={boundary}',
        'Content-Length': str(len(body))
    })
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            print(f"HTTP Status: {resp.status}")
            data = json.loads(resp.read().decode('utf-8'))
            print(json.dumps(data, indent=2))
            return data
    except urllib.error.HTTPError as e:
        print(f"HTTP Error {e.code}: {e.read().decode('utf-8')}")
        return None

if __name__ == '__main__':
    test_live_predict('dataset/split/test/bacterial_blight/BBC00080.jpg')
