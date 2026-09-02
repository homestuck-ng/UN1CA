#!/bin/bash

set -e

SRC_DIR="$(dirname "$(realpath "$0")")"
OUT_DIR="$SRC_DIR/out"
TOOLS_DIR="$OUT_DIR/tools/bin"

mkdir -p "$TOOLS_DIR"

# ============================================================
# Tools
# ============================================================

ANDROID_TOOLS=true
APKTOOL=true
EROFS_UTILS=true
IMG2SDAT=true
SAMLOADER=true
SIGNAPK=true
SMALI=true

# ============================================================
# Helper functions
# ============================================================

BUILD() {
    local NAME="$1"
    local DIR="$2"
    shift 2

    echo
    echo "========================================"
    echo " Building $NAME"
    echo "========================================"

    cd "$DIR"

    for CMD in "$@"; do
        echo "+ $CMD"
        eval "$CMD"
    done

    cd "$SRC_DIR"
}

CHECK_TOOLS() {
    for TOOL in "$@"; do
        if ! command -v "$TOOL" >/dev/null 2>&1; then
            return 0
        fi
    done

    return 1
}

# ============================================================
# Android platform tools
# ============================================================

if command -v adb >/dev/null 2>&1 &&
   command -v fastboot >/dev/null 2>&1; then
    ANDROID_TOOLS=false
fi

# ============================================================
# Apktool
# ============================================================

if command -v apktool >/dev/null 2>&1; then
    APKTOOL=false
fi

if $APKTOOL && [ -d "$SRC_DIR/external/apktool" ]; then
    APKTOOL_CMDS=(
        "python3 -m pip install --user ."
    )

    BUILD "apktool" "$SRC_DIR/external/apktool" "${APKTOOL_CMDS[@]}"
fi

# ============================================================
# EROFS Utils
# ============================================================

if command -v mkfs.erofs >/dev/null 2>&1; then
    EROFS_UTILS=false
fi

if $EROFS_UTILS && [ -d "$SRC_DIR/external/erofs-utils" ]; then
    EROFS_CMDS=(
        "autoreconf -fiv"
        "./configure"
        "make -j$(nproc)"
    )

    BUILD "erofs-utils" "$SRC_DIR/external/erofs-utils" "${EROFS_CMDS[@]}"
fi

# ============================================================
# img2sdat
# ============================================================

if command -v img2sdat.py >/dev/null 2>&1; then
    IMG2SDAT=false
fi

if $IMG2SDAT && [ -d "$SRC_DIR/external/img2sdat" ]; then
    IMG2SDAT_CMDS=(
        "python3 -m pip install --user ."
    )

    BUILD "img2sdat" "$SRC_DIR/external/img2sdat" "${IMG2SDAT_CMDS[@]}"
fi

# ============================================================
# samloader
# ============================================================

SAMLOADER_VENV="$OUT_DIR/tools/venv"
SAMLOADER_EXEC="$SAMLOADER_VENV/bin/samloader"

if [ -x "$SAMLOADER_EXEC" ]; then
    SAMLOADER=false
fi

if $SAMLOADER; then

    if [ ! -d "$SRC_DIR/external/samloader" ]; then
        echo
        echo "[ERROR] external/samloader does not exist!"
        echo
        exit 1
    fi

    echo
    echo "========================================"
    echo " Building samloader"
    echo "========================================"

    python3 -m venv "$SAMLOADER_VENV"

    source "$SAMLOADER_VENV/bin/activate"

    python3 -m pip install --upgrade pip

    pip3 install .

    deactivate

    cd "$SRC_DIR"

    echo
    echo "[OK] samloader installed:"
    echo "     $SAMLOADER_EXEC"
fi

# ============================================================
# SignAPK
# ============================================================

if [ -f "$TOOLS_DIR/signapk.jar" ]; then
    SIGNAPK=false
fi

if $SIGNAPK && [ -d "$SRC_DIR/external/signapk" ]; then
    SIGNAPK_CMDS=(
        "make"
    )

    BUILD "signapk" "$SRC_DIR/external/signapk" "${SIGNAPK_CMDS[@]}"
fi

# ============================================================
# Smali / Baksmali
# ============================================================

if command -v smali >/dev/null 2>&1 &&
   command -v baksmali >/dev/null 2>&1; then
    SMALI=false
fi

if $SMALI && [ -d "$SRC_DIR/external/smali" ]; then
    SMALI_CMDS=(
        "./gradlew build"
    )

    BUILD "smali" "$SRC_DIR/external/smali" "${SMALI_CMDS[@]}"
fi

# ============================================================
# Final check
# ============================================================

echo
echo "========================================"
echo " Checking tools"
echo "========================================"

if [ -x "$SAMLOADER_EXEC" ]; then
    echo "[OK] samloader"
    "$SAMLOADER_EXEC" --help >/dev/null
else
    echo "[ERROR] samloader was not installed!"
    exit 1
fi

echo
echo "========================================"
echo " Build complete"
echo "========================================"
echo
echo "samloader:"
echo "  $SAMLOADER_EXEC"
echo
echo "Tools:"
echo "  $TOOLS_DIR"
echo
