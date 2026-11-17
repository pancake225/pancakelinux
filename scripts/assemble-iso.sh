#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
ISO_DIR="$BUILD_DIR/iso"

MODE="${1:---check}"

check_inputs() {
    local failed=0

    for tool in grub-mkrescue xorriso; do
        if command -v "$tool" >/dev/null 2>&1; then
            echo "[OK] $tool"
        else
            echo "[MISSING] $tool"
            failed=1
        fi
    done

    for file in \
        "$PROJECT_DIR/live/grub.cfg" \
        "$ISO_DIR/live/vmlinuz" \
        "$ISO_DIR/live/initrd.img" \
        "$ISO_DIR/live/filesystem.squashfs"; do

        if [[ -s "$file" ]]; then
            echo "[OK] ${file#"$PROJECT_DIR/"}"
        else
            echo "[MISSING] ${file#"$PROJECT_DIR/"}"
            failed=1
        fi
    done

    if [[ -d "$ISO_DIR/live" ]]; then
        local unexpected=0

        for file in "$ISO_DIR"/live/*backup* "$ISO_DIR"/live/*.tmp; do
            [[ -e "$file" ]] || continue
            echo "[UNEXPECTED] ISO staging file: ${file#"$PROJECT_DIR/"}"
            unexpected=1
        done

        if (( unexpected )); then
            failed=1
        else
            echo "[OK] No backup or temporary files in ISO staging"
        fi
    fi

    return "$failed"
}

case "$MODE" in
    --check)
        echo "=-= ISO Assembly Check =-="
        check_inputs
        echo "Check passed. No changes made."
        ;;

    --apply)
        echo "=-= Checking ISO inputs =-="
        check_inputs || exit 1 

        BUILD_TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
        ISO="$BUILD_DIR/PancakeLinux-$BUILD_TIMESTAMP.iso"

        if [[ -e "$ISO" ]]; then
            echo "ERROR: ISO already exists: $ISO"
            exit 1
        fi

        TEMP_DIR="$(mktemp -d "$BUILD_DIR/.iso-assembly.XXXXXX")"
        trap 'rm -rf -- "$TEMP_DIR"' EXIT

        echo "Preparing temporary ISO staging..."
        cp -a "$ISO_DIR/." "$TEMP_DIR/"
        install -D -m 0644 \
            "$PROJECT_DIR/live/grub.cfg" \
            "$TEMP_DIR/boot/grub/grub.cfg"

        echo "Building ISO: $ISO"
        grub-mkrescue -o "$ISO" "$TEMP_DIR"

        if [[ ! -s "$ISO" ]]; then
            echo "ERROR: ISO creation failed."
            exit 1
        fi

        echo
        echo "ISO created successfully:"
        ls -lh "$ISO"
        ;;

    --help|-h)
        echo "Usage: $0 [--check|--apply|--help]"
        ;;

    *)
        echo "Usage: $0 [--check|--apply|--help]"
        exit 2
        ;;
esac

