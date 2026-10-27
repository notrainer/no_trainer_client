#!/bin/bash
# Exercise a separate X server; never connect to the participant desktop.
set -euo pipefail

export DISPLAY=:99
log=$(mktemp)
Xvfb "$DISPLAY" -screen 0 1024x768x24 -nolisten tcp -ac -noreset >"$log" 2>&1 &
server=$!
cleanup() {
    kill "$server" 2>/dev/null || true
    wait "$server" 2>/dev/null || true
    rm -f "$log"
}
trap cleanup EXIT

for _ in {1..50}; do
    if xrandr --query >/dev/null 2>&1; then
        break
    fi
    if ! kill -0 "$server" 2>/dev/null; then
        cat "$log" >&2
        exit 1
    fi
    sleep 0.1
done

xrandr --newmode 2560x1440 241.50 2560 2608 2640 2720 1440 1443 1448 1481 +HSync -VSync
xrandr --addmode screen 2560x1440
for resolution in 2560x1440 1024x768 2560x1440; do
    xrandr --output screen --mode "$resolution"
    xrandr --query | grep -Fq "screen connected ${resolution}+0+0"
done
echo "Display resize checks passed: 2560x1440 -> 1024x768 -> 2560x1440."
