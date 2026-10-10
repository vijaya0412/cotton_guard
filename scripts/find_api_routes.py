import re

html_path = r"C:\Users\duppa\.gemini\antigravity-cli\brain\858d2708-e378-442b-80e3-51d5557a8c49\.system_generated\steps\1226\content.md"
with open(html_path, "r", encoding="utf-8", errors="ignore") as f:
    text = f.read()

print("HTML length:", len(text))

# Find script src URLs
srcs = re.findall(r'<script[^>]+src=["\']([^"\']+)["\']', text)
for s in srcs:
    print("Script src:", s)

# Find all occurrences of "download" or "files" with surrounding context
for m in re.finditer(r'(download|files|b3jy2p6k8w)', text, re.IGNORECASE):
    start = max(0, m.start() - 50)
    end = min(len(text), m.end() + 100)
    snippet = text[start:end].replace("\n", " ")
    if any(k in snippet.lower() for k in ["http", "api", "json", "href", "url", "zip", "get", "post"]):
        print("Snippet:", snippet)
