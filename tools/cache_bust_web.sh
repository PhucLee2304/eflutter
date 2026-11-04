#!/usr/bin/env bash
# Gắn ?v=<build time> vào flutter_bootstrap.js/main.dart.js và đổi tên font theo version trong build/web.
# Flutter web không hash tên file, nên Cloudflare có thể giữ bản JS cũ; index.html
# không bị cache nên URL mới buộc trình duyệt và Cloudflare lấy bản build mới.
set -euo pipefail
web="$(cd "$(dirname "$0")/.." && pwd)/build/web"
version="$(date +%s)"

sed -i -E "s#(src=\"flutter_bootstrap\.js)(\?v=[0-9]+)?\"#\1?v=${version}\"#" "$web/index.html"
sed -i -E "s#\"mainJsPath\":\"main\.dart\.js(\?v=[0-9]+)?\"#\"mainJsPath\":\"main.dart.js?v=${version}\"#g" "$web/flutter_bootstrap.js"

# Font icon bị tree-shake theo bản build (icon mới không có trong font cũ):
# chép font sang tên có version và trỏ FontManifest.json (không bị cache) sang đó.
python3 -I - "$web" "$version" <<'PY'
import json, os, re, shutil, sys

web, version = sys.argv[1], sys.argv[2]
manifest_path = os.path.join(web, "assets", "FontManifest.json")
with open(manifest_path, encoding="utf-8") as f:
    manifest = json.load(f)
for family in manifest:
    for font in family["fonts"]:
        original = re.sub(r"\.v\d+(\.[^.]+)$", r"\1", font["asset"])
        stem, ext = os.path.splitext(original)
        versioned = f"{stem}.v{version}{ext}"
        folder = os.path.join(web, "assets", os.path.dirname(original))
        old = re.compile(re.escape(os.path.basename(stem)) + r"\.v\d+" + re.escape(ext) + "$")
        for name in os.listdir(folder):
            if old.match(name):
                os.remove(os.path.join(folder, name))
        shutil.copyfile(os.path.join(web, "assets", original), os.path.join(web, "assets", versioned))
        font["asset"] = versioned
with open(manifest_path, "w", encoding="utf-8") as f:
    json.dump(manifest, f, separators=(",", ":"))
PY

grep -q "flutter_bootstrap.js?v=${version}" "$web/index.html"
grep -q "main.dart.js?v=${version}" "$web/flutter_bootstrap.js"
grep -q "\.v${version}\." "$web/assets/FontManifest.json"
echo "Cache-busted build/web with v=${version}"
