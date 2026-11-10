#!/usr/bin/env bash
set -Eeuo pipefail

failures=0
for service in NetworkManager.service bluetooth.service; do
    if sudo systemctl enable --now "$service"; then
        printf '[ OK ] %s enabled and started\n' "$service"
    else
        printf '[FAIL] Could not enable/start %s\n' "$service" >&2
        failures=$((failures + 1))
    fi
done
exit "$((failures > 0 ? 1 : 0))"
