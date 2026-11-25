#!/usr/bin/env bash
# One command surface for the combined Quickshell config.
# Usage: main.sh start | launcher|audio|notifications|wallchange [toggle|open|close]
set -euo pipefail

CONFIG_DIR="${QS_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/quickshell}"
ACTION="${1:-help}"
MODE="${2:-toggle}"

case "$ACTION" in
  start)
    exec qs -p "$CONFIG_DIR/shell.qml"
    ;;
  launcher|audio|notifications|wallchange)
    IPC_TARGET="$ACTION"
    if [[ "$ACTION" == "audio" ]]; then
      IPC_TARGET="audiomixer"
    fi
    case "$MODE" in
      toggle|open|close) exec qs ipc call "$IPC_TARGET" "$MODE" ;;
      *) echo "Unknown mode: $MODE (use toggle, open, or close)" >&2; exit 2 ;;
    esac
    ;;
  help|-h|--help)
    cat <<'HELP'
Quickshell control helper

  main.sh start                    Start the combined shell
  main.sh launcher [toggle|open|close]
  main.sh audio [toggle|open|close]
  main.sh notifications [toggle|open|close]
  main.sh wallchange [toggle|open|close]

Run start from Hyprland autostart once. The other commands use Quickshell IPC
and control the already-running shell instance.
HELP
    ;;
  *) echo "Unknown target: $ACTION" >&2; exit 2 ;;
esac
