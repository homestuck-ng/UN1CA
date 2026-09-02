#!/usr/bin/env bash

#
# Copyright (C) 2026
# SPDX-License-Identifier: GPL-3.0-or-later
#

set -e

# [
GET_LATEST_FIRMWARE()
{
    curl -s --retry 3 -m 5 \
        "https://fota-cloud-dn.ospserver.net/firmware/$CSC/$MODEL/version.xml" \
        | perl -nE 'say $1 if /<latest[^>]*>(.*?)<\/latest>/'
}

DOWNLOAD_FIRMWARE()
{
    local OUT="$ODIN_DIR/${MODEL}_${CSC}"
    local ZIP_FILE

    rm -rf "$OUT"
    mkdir -p "$OUT"

    echo "- Downloading $MODEL firmware with $CSC CSC..."

    samloader \
        -m "$MODEL" \
        -r "$CSC" \
        -i "$IMEI" \
        download \
        -O "$OUT"

    ZIP_FILE="$(find "$OUT" -type f -name "*.zip" | sort -r | head -n 1)"

    if [ ! "$ZIP_FILE" ] || [ ! -f "$ZIP_FILE" ]; then
        echo "! Download failed: firmware ZIP not found"
        exit 1
    fi

    echo "- Extracting $(basename "$ZIP_FILE")..."

    unzip -o "$ZIP_FILE" -d "$OUT"
    rm -f "$ZIP_FILE"

    echo -n "$LATEST_FIRMWARE" > "$OUT/.downloaded"

    echo "- Firmware downloaded successfully"
}

FIRMWARES=( "$SOURCE_FIRMWARE" "$TARGET_FIRMWARE" )

IFS=':' read -ra SOURCE_EXTRA_FIRMWARES <<< "$SOURCE_EXTRA_FIRMWARES"
for i in "${SOURCE_EXTRA_FIRMWARES[@]}"; do
    [ -n "$i" ] && FIRMWARES+=( "$i" )
done

IFS=':' read -ra TARGET_EXTRA_FIRMWARES <<< "$TARGET_EXTRA_FIRMWARES"
for i in "${TARGET_EXTRA_FIRMWARES[@]}"; do
    [ -n "$i" ] && FIRMWARES+=( "$i" )
done

FORCE=false

while [ "$#" != 0 ]; do
    case "$1" in
        "-f" | "--force")
            FORCE=true
            ;;
        *)
            echo "Usage: download_fw [options]"
            echo " -f, --force : Force firmware download"
            exit 1
            ;;
    esac

    shift
done

mkdir -p "$ODIN_DIR"

for i in "${FIRMWARES[@]}"; do

    MODEL="$(echo "$i" | cut -d "/" -f 1)"
    CSC="$(echo "$i" | cut -d "/" -f 2)"
    IMEI="$(echo "$i" | cut -d "/" -f 3)"

    if [ -z "$MODEL" ] || [ -z "$CSC" ] || [ -z "$IMEI" ]; then
        echo "! Invalid firmware string: $i"
        exit 1
    fi

    echo
    echo "- Processing $MODEL firmware with $CSC CSC"

    LATEST_FIRMWARE="$(GET_LATEST_FIRMWARE)"

    if [ -z "$LATEST_FIRMWARE" ]; then
        echo "! Latest firmware could not be fetched"
        exit 1
    fi

    echo "  Latest firmware: $LATEST_FIRMWARE"

    if [ -f "$ODIN_DIR/${MODEL}_${CSC}/.downloaded" ]; then

        DOWNLOADED="$(cat "$ODIN_DIR/${MODEL}_${CSC}/.downloaded")"

        if [ "$DOWNLOADED" = "$LATEST_FIRMWARE" ]; then
            echo "  Firmware already downloaded"
            continue
        fi

        if $FORCE; then
            echo "- Updating $MODEL firmware with $CSC CSC..."
            DOWNLOAD_FIRMWARE
        else
            echo "  A newer firmware is available."
            echo "  Use --force to download it."
            continue
        fi

    else

        DOWNLOAD_FIRMWARE

    fi

done

exit 0
