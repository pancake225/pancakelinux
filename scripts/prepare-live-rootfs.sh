#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
ROOTFS="$PROJECT_DIR/build/rootfs"
LIVE_ROOTFS="$PROJECT_DIR/build/live-rootfs"

MODE="${1:---check}"

usage() {
    echo "Usage: $0 [--check|--apply|--refresh|--help]"
}

check_config() {
    local failed=0

    for file in \
        config/os-release \
        config/hostname \
        config/issue \
        config/motd \
        config/apt/99pancakelinux-no-translations \
        live/runit/getty-tty1/run \
        live/runit/getty-ttyS0/run; do

        if [[ -s "$PROJECT_DIR/$file" ]]; then
            echo "[OK] $file"
        else
            echo "[MISSING] $file"
            failed=1
        fi
    done

    return "$failed"
}

install_config() {
    echo "Installing PancakeLinux identity..."

    doas install -m 0644 \
        "$PROJECT_DIR/config/os-release" \
        "$LIVE_ROOTFS/etc/os-release"

    doas install -m 0644 \
        "$PROJECT_DIR/config/hostname" \
        "$LIVE_ROOTFS/etc/hostname"

    doas install -m 0644 \
        "$PROJECT_DIR/config/issue" \
        "$LIVE_ROOTFS/etc/issue"

    doas install -m 0644 \
        "$PROJECT_DIR/config/motd" \
        "$LIVE_ROOTFS/etc/motd"

    echo "Installing live getty configurations..."

    doas install -D -m 0755 \
        "$PROJECT_DIR/live/runit/getty-tty1/run" \
        "$LIVE_ROOTFS/etc/sv/getty-tty1/run"

    doas install -D -m 0755 \
        "$PROJECT_DIR/live/runit/getty-ttyS0/run" \
        "$LIVE_ROOTFS/etc/sv/getty-ttyS0/run"

    echo "Installing APT configuration..." 
    
    doas install -D -m 0644 \
        "$PROJECT_DIR/config/apt/99pancakelinux-no-translations" \
        "$LIVE_ROOTFS/etc/apt/apt.conf.d/99pancakelinux-no-translations"
}

clean_apt_cache() {
    echo "Cleaning APT cache from live rootfs..."

    doas chroot "$LIVE_ROOTFS" apt-get clean

    echo "Removing generated APT package caches..."

    doas rm -f \
        "$LIVE_ROOTFS/var/cache/apt/pkgcache.bin" \
        "$LIVE_ROOTFS/var/cache/apt/srcpkgcache.bin"

    echo "APT cache cleaned."
}

case "$MODE" in
    --check)
        echo "=-= Live Rootfs Check =-="

        if [[ -d "$ROOTFS/etc/runit/runsvdir/default" ]]; then
            echo "[OK] Base rootfs"
        else
            echo "[MISSING] Base rootfs"
            exit 1
        fi

        check_config

        if [[ -d "$LIVE_ROOTFS" ]]; then
            echo "[OK] Existing live rootfs"
        else
            echo "[INFO] Live rootfs has not been created"
        fi

        echo "Check complete. No changes made."
        ;;

    --apply)
        if [[ ! -d "$ROOTFS/etc/runit/runsvdir/default" ]]; then
            echo "ERROR: Base rootfs is missing or incomplete."
            exit 1
        fi

        check_config

        if [[ -e "$LIVE_ROOTFS" ]]; then
            echo "ERROR: Live rootfs already exists."
            echo "Use --refresh to update its configuration."
            exit 1
        fi

        echo "Creating live rootfs..."
        doas cp -a "$ROOTFS" "$LIVE_ROOTFS"

        install_config
        clean_apt_cache

        echo "Live rootfs created successfully."
        ;;

    --refresh)
        if [[ ! -d "$LIVE_ROOTFS/etc" ]]; then
            echo "ERROR: Existing live rootfs is missing."
            exit 1
        fi

        check_config

        echo "Refreshing PancakeLinux configuration..."
        
        install_config
        clean_apt_cache

        echo
        echo "Live rootfs refreshed successfully."
        ;;

    --help|-h)
        usage
        ;;

    *)
        usage
        exit 2
        ;;
esac
