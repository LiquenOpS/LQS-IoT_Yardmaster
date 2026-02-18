#!/bin/bash
# Deprovision all backends. Wrapper for deprovision_all.py.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec "$ROOT/venv/bin/python3" "$ROOT/ops/deprovision_all.py"
