#!/bin/sh
set -eu
if ! command -v python3 >/dev/null 2>&1; then
  echo 'Python 3.9+ is required. On macOS: brew install python' >&2
  exit 1
fi
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec python3 "$SCRIPT_DIR/scripts/install.py" "$@"
