import urllib.request
import re

url = "https://data.mendeley.com/datasets/bundle.js?5e5376ee3a5def54f781"
req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
js = urllib.request.urlopen(req).read().decode("utf-8")

# Find occurrences of publicApiBaseUrl or apiBaseUrl
for m in re.finditer(r"(publicApiBaseUrl|apiBaseUrl)", js):
    snippet = js[max(0, m.start()-50):min(len(js), m.end()+200)]
    print("Match:", snippet.replace("\n", " "))
