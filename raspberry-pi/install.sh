#!/bin/sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

install -m 755 "$SCRIPT_DIR/rpi4test-set-time" /usr/local/sbin/rpi4test-set-time
install -m 440 "$SCRIPT_DIR/rpi4test-time.sudoers" /etc/sudoers.d/rpi4test-time

if command -v visudo >/dev/null 2>&1; then
    visudo -cf /etc/sudoers.d/rpi4test-time
fi

echo
echo "Raspberry Pi clock helper installed successfully."
