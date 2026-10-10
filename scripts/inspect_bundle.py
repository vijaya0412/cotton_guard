import urllib.request
import re

url = "https://data.mendeley.com/datasets/bundle.js?5e5376ee3a5def54f781"
req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"})

with urllib.request.urlopen(req, timeout=15) as r:
    js = r.read().decode("utf-8", errors="ignore")
    print("Bundle length:", len(js))

# Look for patterns like apiBaseUrl, files, download
for m in set(re.findall(r'(/api/[a-zA-Z0-9_\-/{}$]+)', js)):
    if any(k in m for k in ["file", "dataset", "archive", "download"]):
        print("API match:", m)

for m in set(re.findall(r'(/public-api/[a-zA-Z0-9_\-/{}$]+)', js)):
    if any(k in m for k in ["file", "dataset", "archive", "download"]):
        print("Public API match:", m)

# Search for download-all or archive creation
for line in js.split(";"):
    if "download-all" in line or "archive" in line and "status" in line:
        if len(line) < 300:
            print("Line:", line.strip())
