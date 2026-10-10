import os
import sys
import time
import urllib.request
import zipfile
import hashlib

DATASET_URL = "https://data.mendeley.com/public-files/datasets/b3jy2p6k8w/files/9a365367-8a96-4c15-8bcc-a533ab79c7d6/file_downloaded"
EXPECTED_SHA256 = "cb4f662985a33831e92d37644fe6092e76be321dd6b4bf443e65f9ae130d137a"
RAW_DIR = os.path.join("dataset", "raw", "SAR-CLD-2024")
ZIP_PATH = os.path.join("dataset", "raw", "Original_Dataset.zip")

os.makedirs(RAW_DIR, exist_ok=True)

print("=" * 60)
print("DOWNLOADING AUTHENTIC SAR-CLD-2024 ORIGINAL DATASET")
print("=" * 60)
print(f"Target URL: {DATASET_URL}")
print(f"Destination: {ZIP_PATH}")

# 1. Download with progress
if not os.path.exists(ZIP_PATH) or os.path.getsize(ZIP_PATH) != 270591498:
    req = urllib.request.Request(DATASET_URL, headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"})
    with urllib.request.urlopen(req) as resp, open(ZIP_PATH, "wb") as out_file:
        total_size = int(resp.headers.get("Content-Length", 270591498))
        downloaded = 0
        chunk_size = 1024 * 1024 # 1MB
        t0 = time.time()
        
        while True:
            chunk = resp.read(chunk_size)
            if not chunk:
                break
            out_file.write(chunk)
            downloaded += len(chunk)
            elapsed = time.time() - t0
            speed = (downloaded / (1024 * 1024)) / max(elapsed, 0.001)
            percent = (downloaded / total_size) * 100
            print(f"\rDownloaded {downloaded / (1024*1024):.1f} MB / {total_size / (1024*1024):.1f} MB ({percent:.1f}%) at {speed:.1f} MB/s", end="", flush=True)

    print("\nDownload complete!")
else:
    print(f"Archive already downloaded ({os.path.getsize(ZIP_PATH) / (1024*1024):.1f} MB). Skipping download.")

# 2. Verify SHA256
print("\nVerifying SHA-256 checksum...")
h = hashlib.sha256()
with open(ZIP_PATH, "rb") as f:
    while chunk := f.read(4 * 1024 * 1024):
        h.update(chunk)
calculated_hash = h.hexdigest()
print(f"Calculated: {calculated_hash}")
print(f"Expected:   {EXPECTED_SHA256}")
if calculated_hash.lower() == EXPECTED_SHA256.lower():
    print("SHA-256 Checksum Verified Successfully!")
else:
    print("WARNING: Checksum mismatch!")

# 3. Extract Archive
print(f"\nExtracting archive into {RAW_DIR}...")
with zipfile.ZipFile(ZIP_PATH, "r") as z:
    z.extractall(RAW_DIR)
print("Extraction complete!")

# 4. Inventory extracted files
all_files = []
for root, dirs, files in os.walk(RAW_DIR):
    for f in files:
        all_files.append(os.path.join(root, f))

print(f"Total files extracted in {RAW_DIR}: {len(all_files):,}")
