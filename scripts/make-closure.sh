#!/usr/bin/env bash
# Сборка замыкания + профиля pull + графа дериваций → nar → части.
set -eu
ROOT=$(pwd)
WORK="$ROOT/tmp_path"
export HOME="$WORK/home"
rm -rf "$HOME"; mkdir -p "$HOME/.config/guix"

# channels.scm машины сборки (абсолютные пути к снимкам repos)
cat > "$HOME/.config/guix/channels.scm" <<EOF
(list (channel (name 'guix)    (url "$ROOT/for_flight/repos/guix"))
      (channel (name 'nonguix) (url "$ROOT/for_flight/repos/nonguix")))
EOF

echo "==> guix pull (пингуем экземпляр guix+каналы)"
guix pull
PROF=$(readlink -f "$HOME/.config/guix/current")
G="$PROF/bin/guix"

echo "==> guix system build"
SYS=$("$G" system build "$ROOT/for_flight/config/configuration.scm")
DRV=$("$G" system build -d "$ROOT/for_flight/config/configuration.scm")

echo "==> экспорт замыкания: система + профиль pull + граф дериваций"
mkdir -p "$ROOT/for_flight/nars"
guix archive --export --recursive "$SYS" "$PROF" "$DRV" \
  > "$ROOT/for_flight/nars/system-closure.nar"

# метаданные для preflight-проверок
{ "$G" --version | head -n1; guix --version | head -n1; } \
  > "$ROOT/for_flight/nars/VERSIONS"

echo "==> сжатие и нарезка"
xz -T0 -f "$ROOT/for_flight/nars/system-closure.nar"
bash "$ROOT/scripts/make-nar-parts.sh"

echo "==> ВАЖНО: сам ISO собирайте тем же экземпляром guix:"
echo "    $G system image -t iso9660 installer.scm"
