#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") [-f|--force] [--no-repair] <dir> [output-file]

Собирает NAR-архив из сжатых частей в <dir>, проверяя целостность
SHA256 и par2. При необходимости восстанавливает повреждённые или
потерянные части с помощью par2.

Arguments:
  <dir>          Каталог с system-closure.nar.xz.part-*, .par2 и .sha256
  [output-file]  Выходной NAR-файл. Если не указан или указан "-",
                 архив пишется в stdout.

Options:
  -f, --force     Перезаписать существующий output-file
      --no-repair Только проверка, без автоматического восстановления
  -h, --help      Показать эту справку
EOF
}

log() { printf '%s\n' "$*" >&2; }

FORCE=0
REPAIR=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    -f|--force)  FORCE=1; shift ;;
    --no-repair) REPAIR=0; shift ;;
    -h|--help)   usage; exit 0 ;;
    --)          shift; break ;;
    -*)          log "Неизвестный параметр: $1"; usage >&2; exit 1 ;;
    *)           break ;;
  esac
done

if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage >&2
  exit 1
fi

NAR_DIR=$1
OUTPUT=${2:-}

if [[ "$OUTPUT" == "-" ]]; then
  OUTPUT=""
fi

[[ -d "$NAR_DIR" ]] || { log "Ошибка: каталог не найден: $NAR_DIR"; exit 1; }
NAR_DIR="$(cd "$NAR_DIR" && pwd)"

BASE_NAME="system-closure.nar.xz"
PART_PREFIX="$NAR_DIR/${BASE_NAME}.part-"
PAR2_INDEX="$NAR_DIR/${BASE_NAME}.par2"
SHA_FILE="$NAR_DIR/${BASE_NAME}.sha256"

for cmd in xz par2 sha256sum cat mktemp; do
  command -v "$cmd" &>/dev/null \
    || { log "Ошибка: утилита '$cmd' не найдена."; exit 1; }
done

[[ -f "$SHA_FILE" ]]   || { log "Ошибка: не найден $SHA_FILE"; exit 1; }
[[ -f "$PAR2_INDEX" ]] || { log "Ошибка: не найден $PAR2_INDEX"; exit 1; }

shopt -s nullglob
PARTS=("${PART_PREFIX}"*)
shopt -u nullglob
[[ ${#PARTS[@]} -gt 0 ]] \
  || { log "Ошибка: не найдено частей по шаблону ${PART_PREFIX}*"; exit 1; }

if [[ -n "$OUTPUT" && -e "$OUTPUT" && $FORCE -eq 0 ]]; then
  log "Ошибка: '$OUTPUT' уже существует. Используйте --force для перезаписи."
  exit 1
fi

log "Найдено частей: ${#PARTS[@]}"
ls -lh "${PARTS[@]}" >&2

TMP_VERIFY=""
TMP_OUT=""
cleanup() {
  [[ -n "${TMP_VERIFY:-}" ]] && rm -f "$TMP_VERIFY"
  [[ -n "${TMP_OUT:-}" ]] && rm -f "$TMP_OUT"
}
trap cleanup EXIT

log ""
log "[1/3] Проверка целостности par2 ..."
TMP_VERIFY=$(mktemp)
set +e
par2 verify "$PAR2_INDEX" >"$TMP_VERIFY" 2>&1
PAR2_RC=$?
set -e

case $PAR2_RC in
  0)
    log "  OK: файлы целы, восстановление не требуется."
    ;;
  1)
    log "  Обнаружены повреждённые или отсутствующие части."
    if [[ $REPAIR -eq 0 ]]; then
      log "ОШИБКА: указан --no-repair, но восстановление необходимо."
      tail -n 30 "$TMP_VERIFY" >&2
      exit 1
    fi
    log "[2/3] Восстановление с помощью par2 ..."
    if ! par2 repair "$PAR2_INDEX" >&2; then
      log "ОШИБКА: par2 repair не смог восстановить данные."
      tail -n 30 "$TMP_VERIFY" >&2
      exit 1
    fi
    log "  Восстановление завершено."
    ;;
  *)
    log "ОШИБКА: par2 не может восстановить файлы (код возврата $PAR2_RC)."
    tail -n 30 "$TMP_VERIFY" >&2
    exit 1
    ;;
esac
rm -f "$TMP_VERIFY"
TMP_VERIFY=""

log ""
log "[3/3] Проверка контрольных сумм SHA256 ..."
SHA_NAME=${SHA_FILE##*/}
if ! (cd "$NAR_DIR" && sha256sum -c --strict "$SHA_NAME") >&2; then
  log "ОШИБКА: контрольные суммы не сходятся. Архив повреждён."
  exit 1
fi
log "  OK: все контрольные суммы совпадают."

log ""
log "Сборка и распаковка NAR-архива ..."

if [[ -z "$OUTPUT" ]]; then
  cat "${PARTS[@]}" | xz -dc
  log "Готово: stdout"
  exit 0
fi

TMP_OUT="${OUTPUT}.tmp.$$"
cat "${PARTS[@]}" | xz -dc > "$TMP_OUT"
mv "$TMP_OUT" "$OUTPUT"
TMP_OUT=""

sha256sum "$OUTPUT" > "$OUTPUT.sha256"

log "Готово: $OUTPUT"
ls -lh "$OUTPUT" >&2
log "SHA256 NAR сохранён: $OUTPUT.sha256"
