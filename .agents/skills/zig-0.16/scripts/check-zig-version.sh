#!/bin/sh
# Verify exactly Zig 0.16.0 is available
set -e

ZIG_CMD="${ZIG_CMD:-zig}"

if ! command -v "$ZIG_CMD" > /dev/null 2>&1; then
    echo "ERROR: zig not found. Set ZIG_CMD or add zig to PATH."
    exit 1
fi

VERSION=$("$ZIG_CMD" version)

if [ "$VERSION" = "0.16.0" ]; then
    echo "OK: Zig $VERSION detected."
else
    echo "ERROR: Zig $VERSION detected, but exactly 0.16.0 is required."
    exit 1
fi
