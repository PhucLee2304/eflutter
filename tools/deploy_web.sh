#!/usr/bin/env bash
# Build eflutter web and publish it to /var/www/eflutter-web (served by nginx on :8188).
set -euo pipefail
cd "$(dirname "$0")/.."
flutter build web --dart-define-from-file=.env/local.json
./tools/cache_bust_web.sh

# Chặn deploy bản build rỗng/hỏng trước khi --delete xóa file trên site.
test -s build/web/index.html && test -s build/web/main.dart.js
# -rlt thay cho -a: giữ group www-data (setgid) của thư mục site.
rsync -rlt --delete-after --delay-updates build/web/ /var/www/eflutter-web/
echo "Deployed to /var/www/eflutter-web"
