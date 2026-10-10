import urllib.request
import json

urls = [
    'https://data.mendeley.com/public-api/datasets/b3jy2p6k8w/files',
    'https://data.mendeley.com/public-api/datasets/b3jy2p6k8w/files?version=1',
    'https://data.mendeley.com/public-api/datasets/b3jy2p6k8w?view=full',
    'https://data.mendeley.com/public-api/datasets/b3jy2p6k8w/download?version=2',
    'https://data.mendeley.com/datasets/b3jy2p6k8w/2/download',
    'https://prod-dcd-datasets-cache-zipfiles.s3.eu-west-1.amazonaws.com/b3jy2p6k8w-2.zip',
    'https://prod-dcd-datasets-cache-zipfiles.s3.eu-west-1.amazonaws.com/b3jy2p6k8w-1.zip',
    'https://data.mendeley.com/public-api/datasets/b3jy2p6k8w/version/2',
    'https://data.mendeley.com/public-api/datasets/b3jy2p6k8w/version/2/download',
]

for u in urls:
    try:
        req = urllib.request.Request(u, headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'})
        with urllib.request.urlopen(req, timeout=10) as resp:
            ct = resp.headers.get("Content-Type")
            cl = resp.headers.get("Content-Length")
            print(f"[SUCCESS {resp.status}] {u} -> Content-Type: {ct} | Length: {cl}")
            if ct and "json" in ct:
                data = resp.read()
                print("   Preview:", data[:200])
    except urllib.error.HTTPError as e:
        print(f"[{e.code}] {u}")
    except Exception as e:
        print(f"[ERR] {u} -> {e}")
