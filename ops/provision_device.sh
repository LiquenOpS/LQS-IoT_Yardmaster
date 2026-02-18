#!/bin/bash
# Provision all backends. Wrapper for provision_all.py.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec "$ROOT/venv/bin/python3" "$ROOT/ops/provision_all.py"
