#!/usr/bin/env python3
"""Deprecated shim -> scripts/system-health.py (portable version).

Kept so existing macOS LaunchAgents that point at this path keep working.
New setups should call scripts/system-health.py directly.
"""
import os
import sys
from pathlib import Path

target = Path(__file__).resolve().parent / "system-health.py"
os.execv(sys.executable, [sys.executable, str(target), *sys.argv[1:]])
