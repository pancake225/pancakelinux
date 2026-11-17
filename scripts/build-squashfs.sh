#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LIVE_ROOTFS="$PROJECT_DIR/build/live-rootfs"
LIVE_DIR="$PROJECT_DIR/build/iso/live"
OUTPUT="$LIVE_DIR/filesystem.squashfs"

MODE="${1:---check}"

usage() {
    echo "Usage: $0 [--check|--apply|--help]"
}

check_inputs() {
    local failed=0

    for tool in mksquashfs unsquashfs doas; do
        if command -v "$tool" >/dev/null 2>&1; then
            echo "[OK] $tool"
        else
            echo "[MISSING] $tool"
            failed=1
        fi
    done

    if [[ -d "$LIVE_ROOTFS/etc" && -f "$LIVE_ROOTFS/etc/os-release" ]]; then
        echo "[OK] Live rootfs"
    else
        echo "[MISSING] Live rootfs or os-release"
        failed=1
    fi

    if [[ -d "$LIVE_DIR" ]]; then
        echo "[OK] ISO live directory"
    else
        echo "[MISSING] ISO live directory"
        failed=1
    fi

    return "$failed"
}

case "$MODE" in
    --check)
        echo "=-= SquashFS Build Check =-="
        check_inputs
        echo "Check passed. No changes made."
        ;;

    --apply)
        echo "=-= Checking SquashFS inputs =-="
        check_inputs || exit 1

        TEMP_DIR="$(mktemp -d "$PROJECT_DIR/build/.squashfs.XXXXXX")"
        TEMP_IMAGE="$TEMP_DIR/filesystem.squashfs"
        BACKUP="$PROJECT_DIR/build/filesystem.squashfs.backup.$(date +%Y%m%d-%H%M%S)"

        cleanup() {
            if [[ -d "$TEMP_DIR" ]]; then
                doas rm -rf -- "$TEMP_DIR"
            fi
        }
        trap cleanup EXIT

        echo
        echo "Building SquashFS from live rootfs..."
        doas mksquashfs "$LIVE_ROOTFS" "$TEMP_IMAGE" \
            -comp gzip \
            -b 1M \
            -noappend \
            -no-progress

        echo
        echo "Validating generated image..."
        doas unsquashfs -s "$TEMP_IMAGE"

        if [[ ! -s "$TEMP_IMAGE" ]]; then
            echo "ERROR: Generated image is empty."
            exit 1
        fi

        if [[ -e "$OUTPUT" ]]; then
            echo
            echo "Preserving previous image:"
            echo "$BACKUP"
            doas cp -a "$OUTPUT" "$BACKUP"
        fi

        echo
        echo "Installing new SquashFS image..."
        doas mv -f -- "$TEMP_IMAGE" "$OUTPUT"

        echo
        echo "SquashFS build complete:"
        ls -lh "$OUTPUT"
        ;;

    --help|-h)
        usage
        ;;

    *)
        usage
        exit 2
        ;;
esac

