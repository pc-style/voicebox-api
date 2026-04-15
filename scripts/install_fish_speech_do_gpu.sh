#!/usr/bin/env bash
set -euo pipefail

# Backward-compatible entrypoint with a clearer name.
exec "$(dirname "$0")/install_voicebox_do_gpu.sh" "$@"
