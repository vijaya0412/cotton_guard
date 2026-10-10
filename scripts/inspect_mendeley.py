import os
import re
import json

html_path = r"C:\Users\duppa\.gemini\antigravity-cli\brain\858d2708-e378-442b-80e3-51d5557a8c49\.system_generated\steps\1226\content.md"

with open(html_path, "r", encoding="utf-8", errors="ignore") as f:
    content = f.read()

print("Total HTML length:", len(content))

# Look for embedded JSON state
script_tags = re.findall(r'<script[^>]*>(.*?)</script>', content, re.DOTALL)
print(f"Total script tags: {len(script_tags)}")

for i, tag in enumerate(script_tags):
    if "b3jy2p6k8w" in tag:
        print(f"Tag {i} contains dataset ID! Length: {len(tag)}")
        # Check if JSON
        try:
            # Look for JSON patterns inside
            match = re.search(r'\{.*"b3jy2p6k8w".*\}', tag, re.DOTALL)
            if match:
                print("Found JSON match with b3jy2p6k8w!")
                sub = match.group(0)
                # Print some snippet
                print(sub[:500])
        except Exception as e:
            print("Error parsing tag:", e)

# Also search for direct download links in content
for line in content.splitlines():
    if any(k in line.lower() for k in ["download", ".zip", "prod-dcd-datasets", "files"]):
        if "http" in line or "href" in line:
            print("Line with link:", line[:200])
