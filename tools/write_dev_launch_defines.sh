#!/usr/bin/env bash
set -euo pipefail

workspace="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$workspace/.env"

python3 -I - "$workspace/.env/local.json" "$workspace/.env/dev_launch.json" <<'PY'
import json, os, sys, time

local_path, dev_launch_path = sys.argv[1], sys.argv[2]
defines = {}
if os.path.exists(local_path):
    with open(local_path, encoding="utf-8-sig") as f:
        defines.update(json.load(f))
defines["DEV_AUTH_STORAGE_SESSION"] = str(int(time.time() * 1000))
with open(dev_launch_path, "w", encoding="utf-8") as f:
    json.dump(defines, f, indent=2)
    f.write("\n")
PY
echo "Generated .env/dev_launch.json"
