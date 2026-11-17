#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

MODE="${1:---check}"

usage() {
    echo "PancakeLinux Build System"
    echo
    echo "Usage: $0 [--check|--build|--help]"
}

check_environment() {
    local failed=0

    echo "=-= PancakeLinux Build Check =-="
    echo "Project: $PROJECT_DIR"
    echo "Host: $(uname -srm)"
    echo

    for tool in doas mksquashfs unsquashfs grub-mkrescue xorriso; do
        if command -v "$tool" >/dev/null 2>&1; then
            printf '[OK] %s\n' "$tool"
        else
            printf '[MISSING] %s\n' "$tool"
            failed=1
        fi
    done

    echo
    for script in \
        scripts/prepare-live-rootfs.sh \
        scripts/build-squashfs.sh \
        scripts/assemble-iso.sh; do

        if [[ -x "$PROJECT_DIR/$script" ]]; then
            printf '[OK] %s\n' "$script"
        else
            printf '[MISSING OR NOT EXECUTABLE] %s\n' "$script"
            failed=1
        fi
    done

    echo
    if (( failed )); then
        echo "Environment check failed."
        return 1
    fi

    echo "Environment check passed."
}

build() {
    echo
    echo "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
    echo "       PancakeLinux Build"
    echo "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
    echo

    echo "=-= Stage 1: Checking live rootfs =-="
    "$PROJECT_DIR/scripts/prepare-live-rootfs.sh" --check

    echo
    echo "=-= Stage 2: Checking SquashFS =-="
    "$PROJECT_DIR/scripts/build-squashfs.sh" --check

    echo
    echo "=-= Stage 3: Refreshing live rootfs =-="
    "$PROJECT_DIR/scripts/prepare-live-rootfs.sh" --refresh

    echo
    echo "=-= Stage 4: Building SquashFS =-="
    "$PROJECT_DIR/scripts/build-squashfs.sh" --apply

    echo
    echo "=-= Stage 5: Assembling ISO =-="
    "$PROJECT_DIR/scripts/assemble-iso.sh" --apply

    echo
    echo "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
    echo "  PancakeLinux Build complete!   "
    echo "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
}

case "$MODE" in
    --check)
        check_environment
        echo
        "$PROJECT_DIR/scripts/prepare-live-rootfs.sh" --check
        echo
        "$PROJECT_DIR/scripts/build-squashfs.sh" --check
        echo
        "$PROJECT_DIR/scripts/assemble-iso.sh" --check
        ;;

    --build)
        check_environment || exit 1
        build
        ;;

    --help|-h)
        usage
        ;;

    *)
        usage
        exit 2
        ;;
esac
