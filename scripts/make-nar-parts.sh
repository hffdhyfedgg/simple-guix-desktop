#!/usr/bin/env bash
set -euo pipefail

# --- Настройки ---
PART_SIZE="${PART_SIZE:-2G}"
PAR2_REDUNDANCY="${PAR2_REDUNDANCY:-5}"
XZ_LEVEL="${XZ_LEVEL:-6}"

# --- Пути ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
NAR_DIR="$REPO_ROOT/for_flight/nars"

BASE_NAME="system-closure.nar.xz"
PART_PREFIX="$NAR_DIR/${BASE_NAME}.part-"

# --- Проверки ---
# Ожидаем данные NAR через stdin. Если stdin — терминал, значит, поток не подан.
if [[ -t 0 ]]; then
    echo "Ошибка: данные NAR должны поступать через stdin." >&2
    echo "Использование:" >&2
    echo "  $0 < system-closure.nar" >&2
    echo "  cat system-closure.nar | $0" >&2
    exit 1
fi

# Создаём каталог назначения, если его нет
mkdir -p "$NAR_DIR"

if ! command -v xz &>/dev/null; then
    echo "Ошибка: утилита 'xz' не установлена." >&2
    exit 1
fi

if ! command -v par2 &>/dev/null; then
    echo "Ошибка: утилита 'par2' не установлена. Установите пакет 'par2'." >&2
    exit 1
fi

# --- Сжатие и разбиение ---
echo "Сжатие stdin и разбиение на части по $PART_SIZE ..."

# Старые части намеренно не удаляем — это отдельная задача.
# rm -f "${PART_PREFIX}"* "${NAR_DIR}/${BASE_NAME}.par2"* "${NAR_DIR}/${BASE_NAME}.vol"*.par2 2>/dev/null || true

# Читаем поток из stdin, сжимаем на лету и разбиваем.
# -T0 задействует все доступные ядра для сжатия.
xz -T0 -"$XZ_LEVEL" -c \
    | split -b "$PART_SIZE" -d -a 3 - "$PART_PREFIX"

# Собираем список созданных частей (без него не проверить пустой поток)
shopt -s nullglob
parts=( "${PART_PREFIX}"* )
shopt -u nullglob

if (( ${#parts[@]} == 0 )); then
    echo "Ошибка: части не были созданы (возможно, stdin пуст)." >&2
    exit 1
fi

echo "Созданы части:"
ls -lh "${parts[@]}"

# --- Создание файлов восстановления par2 ---
echo "Создание файлов избыточности par2 (${PAR2_REDUNDANCY}%) ..."
par2 create -r"$PAR2_REDUNDANCY" -n1 \
    "$NAR_DIR/${BASE_NAME}.par2" \
    "${parts[@]}"

echo "Готово. Файлы восстановления:"
ls -lh "$NAR_DIR/${BASE_NAME}.par2" "$NAR_DIR/${BASE_NAME}.vol"*.par2 2>/dev/null \
    || ls -lh "$NAR_DIR/${BASE_NAME}.par2"*

# --- Контрольные суммы (опционально) ---
echo "Создание контрольных сумм SHA256 ..."
sha256sum "${parts[@]}" > "$NAR_DIR/${BASE_NAME}.sha256"

echo "Все операции успешно завершены."
