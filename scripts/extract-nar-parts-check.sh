#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") [-f|--force] [--no-repair] [-h|--help]

Собирает NAR-архив из сжатых частей в offline/nars/, проверяя целостность
SHA256 и par2. При необходимости восстанавливает повреждённые или
потерянные части с помощью par2.

Options:
  -f, --force     Перезаписать существующий system-closure.nar
      --no-repair Только проверка, без автоматического восстановления
  -h, --help      Показать эту справку
EOF
}

FORCE=0
REPAIR=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    -f|--force)  FORCE=1; shift ;;
    --no-repair) REPAIR=0; shift ;;
    -h|--help)   usage; exit 0 ;;
    *) echo "Неизвестный параметр: $1" >&2; usage >&2; exit 1 ;;
  esac
done

# --- Пути ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
NAR_DIR="$REPO_ROOT/offline/nars"
BASE_NAME="system-closure.nar.xz"
OUTPUT_NAR="$NAR_DIR/system-closure.nar"
PART_PREFIX="$NAR_DIR/${BASE_NAME}.part-"
PAR2_INDEX="$NAR_DIR/${BASE_NAME}.par2"
SHA_FILE="$NAR_DIR/${BASE_NAME}.sha256"

# --- Зависимости ---
for cmd in xz par2 sha256sum cat; do
  command -v "$cmd" &>/dev/null \
    || { echo "Ошибка: утилита '$cmd' не найдена." >&2; exit 1; }
done

# --- Входные файлы ---
[[ -f "$SHA_FILE" ]]   || { echo "Ошибка: не найден $SHA_FILE" >&2; exit 1; }
[[ -f "$PAR2_INDEX" ]] || { echo "Ошибка: не найден $PAR2_INDEX" >&2; exit 1; }

shopt -s nullglob
PARTS=("${PART_PREFIX}"*)
shopt -u nullglob
[[ ${#PARTS[@]} -gt 0 ]] \
  || { echo "Ошибка: не найдено частей по шаблону ${PART_PREFIX}*" >&2; exit 1; }

if [[ -e "$OUTPUT_NAR" && $FORCE -eq 0 ]]; then
  echo "Ошибка: '$OUTPUT_NAR' уже существует. Используйте --force для перезаписи." >&2
  exit 1
fi

echo "Найдено частей: ${#PARTS[@]}"
ls -lh "${PARTS[@]}"

# --- 1. Проверка целостности par2 ---
echo
echo "[1/3] Проверка целостности par2 ..."
set +e
par2 verify "$PAR2_INDEX" >/tmp/par2_verify.$$ 2>&1
PAR2_RC=$?
set -e

case $PAR2_RC in
  0)
    echo "  OK: файлы целы, восстановление не требуется."
    rm -f /tmp/par2_verify.$$
    ;;
  1)
    echo "  Обнаружены повреждённые или отсутствующие части."
    if [[ $REPAIR -eq 0 ]]; then
      echo "ОШИБКА: указан --no-repair, но восстановление необходимо." >&2
      tail -n 30 /tmp/par2_verify.$$ >&2
      rm -f /tmp/par2_verify.$$
      exit 1
    fi
    echo "[2/3] Восстановление с помощью par2 ..."
    if ! par2 repair "$PAR2_INDEX"; then
      echo "ОШИБКА: par2 repair не смог восстановить данные." >&2
      rm -f /tmp/par2_verify.$$
      exit 1
    fi
    echo "  Восстановление завершено."
    rm -f /tmp/par2_verify.$$
    ;;
  *)
    echo "ОШИБКА: par2 не может восстановить файлы (код возврата $PAR2_RC)." >&2
    tail -n 30 /tmp/par2_verify.$$ >&2
    rm -f /tmp/par2_verify.$$
    exit 1
    ;;
esac

# --- 2. Проверка SHA256 ---
echo
echo "[3/3] Проверка контрольных сумм SHA256 ..."
if ! sha256sum -c --strict "$SHA_FILE"; then
  echo "ОШИБКА: контрольные суммы не сходятся. Архив повреждён." >&2
  exit 1
fi
echo "  OK: все контрольные суммы совпадают."

# --- 3. Сборка и распаковка ---
echo
echo "Сборка и распаковка NAR-архива ..."
TMP="$OUTPUT_NAR.tmp"
trap 'rm -f "$TMP"' EXIT

cat "${PART_PREFIX}"* | xz -dc > "$TMP"
mv "$TMP" "$OUTPUT_NAR"
trap - EXIT

# --- 4. SHA256 для получившегося NAR ---
sha256sum "$OUTPUT_NAR" > "$OUTPUT_NAR.sha256"

echo
echo "Готово: $OUTPUT_NAR"
ls -lh "$OUTPUT_NAR"
echo "SHA256 NAR сохранён: $OUTPUT_NAR.sha256"
