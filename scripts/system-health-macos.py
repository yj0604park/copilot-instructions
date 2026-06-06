#!/usr/bin/env python3
"""Daily system health summary for macOS hosts.

Posts a Slack message directly using a bot token at
~/.config/system-health/env.

Sections:
  - copilot-instructions: hash@branch (+ dirty/ahead/behind)
  - System: CPU temp (if available), memory, root disk, load avg, uptime
  - Services: launchctl failed jobs + docker container status

Usage:
  system-health-macos.py [--dry-run]
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import urllib.request
from datetime import datetime
from pathlib import Path

ENV_FILE = Path.home() / ".config" / "system-health" / "env"

TEMP_WARN, TEMP_CRIT = 70.0, 80.0
DISK_WARN, DISK_CRIT = 80.0, 90.0
MEM_WARN, MEM_CRIT = 85.0, 95.0
LOAD_WARN_RATIO, LOAD_CRIT_RATIO = 1.0, 2.0


def tag(value: float, warn: float, crit: float) -> str:
    if value >= crit:
        return ":red_circle:"
    if value >= warn:
        return ":large_orange_circle:"
    return ":large_green_circle:"


def human_bytes(n: float) -> str:
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if n < 1024:
            return f"{n:.1f}{unit}"
        n /= 1024
    return f"{n:.1f}PB"


def load_env(path: Path) -> dict[str, str]:
    env: dict[str, str] = {}
    if not path.exists():
        return env
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        env[k.strip()] = v.strip().strip('"').strip("'")
    return env


# ---------- System ----------

def cpu_temp_c() -> float | None:
    for cmd in (["osx-cpu-temp", "-c"], ["istats", "cpu", "temp"]):
        try:
            p = subprocess.run(cmd, capture_output=True, text=True, timeout=5)
            if p.returncode == 0:
                m = re.search(r"(\d+\.?\d*)", p.stdout)
                if m:
                    return float(m.group(1))
        except FileNotFoundError:
            continue
        except Exception:
            continue
    return None


def disk_usage_pct() -> tuple[int, int, float]:
    s = shutil.disk_usage("/")
    return s.total, s.used, (s.used / s.total) * 100


def mem_usage_pct() -> tuple[int, int, float]:
    """Return (total_bytes, used_bytes, pct).

    Uses sysctl for total, vm_stat for breakdown. "Used" = total - free - inactive,
    matching Activity Monitor's "Memory Used" approximation.
    """
    total = int(subprocess.check_output(["sysctl", "-n", "hw.memsize"]).strip())
    out = subprocess.check_output(["vm_stat"]).decode()
    m = re.search(r"page size of (\d+) bytes", out)
    page = int(m.group(1)) if m else 4096
    stats: dict[str, int] = {}
    for line in out.splitlines():
        m = re.match(r'"?([A-Za-z][\w\- ]+?)"?:\s+(\d+)\.?', line)
        if m:
            stats[m.group(1).strip()] = int(m.group(2)) * page
    free = stats.get("Pages free", 0)
    inactive = stats.get("Pages inactive", 0)
    speculative = stats.get("Pages speculative", 0)
    used = total - free - inactive - speculative
    return total, used, (used / total) * 100


def loadavg() -> tuple[float, float, float, int]:
    l1, l5, l15 = os.getloadavg()
    return l1, l5, l15, os.cpu_count() or 1


def uptime_human() -> str:
    raw = subprocess.check_output(["sysctl", "-n", "kern.boottime"]).decode()
    m = re.search(r"sec = (\d+)", raw)
    if not m:
        return "?"
    import time
    s = time.time() - int(m.group(1))
    d = int(s // 86400)
    h = int((s % 86400) // 3600)
    mi = int((s % 3600) // 60)
    if d:
        return f"{d}일 {h}시간"
    if h:
        return f"{h}시간 {mi}분"
    return f"{mi}분"


# ---------- Services ----------

def launchctl_failed() -> list[str]:
    try:
        p = subprocess.run(
            ["launchctl", "list"], capture_output=True, text=True, timeout=10
        )
    except Exception:
        return []
    failed = []
    for line in p.stdout.splitlines()[1:]:
        parts = line.split(None, 2)
        if len(parts) < 3:
            continue
        pid, status, label = parts
        if status in ("0", "-"):
            continue
        if label.startswith(("com.apple.", "0x")):
            continue
        failed.append(f"{label} (exit {status})")
    return failed


def docker_summary() -> tuple[int, int, list[str]]:
    """Return (running, total, problem_lines). Empty if docker missing."""
    if not shutil.which("docker"):
        return 0, 0, []
    try:
        p = subprocess.run(
            ["docker", "ps", "-a", "--format", "{{.Names}}\t{{.Status}}"],
            capture_output=True, text=True, timeout=10,
        )
    except Exception:
        return 0, 0, []
    if p.returncode != 0:
        return 0, 0, []
    total = running = 0
    problems = []
    for line in p.stdout.strip().splitlines():
        if "\t" not in line:
            continue
        name, status = line.split("\t", 1)
        total += 1
        if status.startswith("Up "):
            running += 1
            if "unhealthy" in status:
                problems.append(f"{name}: {status}")
        else:
            problems.append(f"{name}: {status}")
    return running, total, problems


# ---------- copilot-instructions ----------

def copilot_instructions_info() -> dict | None:
    try:
        link = Path.home() / ".copilot" / "copilot-instructions.md"
        if not link.exists():
            return None
        repo = Path(os.path.realpath(link)).parent

        def g(*args):
            return subprocess.check_output(
                ["git", "-C", str(repo), *args],
                stderr=subprocess.DEVNULL,
            ).decode().strip()

        out = {
            "branch": g("rev-parse", "--abbrev-ref", "HEAD"),
            "hash": g("rev-parse", "--short", "HEAD"),
            "dirty": bool(g("status", "--porcelain")),
            "ahead": 0,
            "behind": 0,
        }
        try:
            counts = g("rev-list", "--left-right", "--count", "@{u}...HEAD").split()
            if len(counts) == 2:
                out["behind"], out["ahead"] = int(counts[0]), int(counts[1])
        except Exception:
            pass
        return out
    except Exception:
        return None


# ---------- Report ----------

def build_report() -> str:
    now = datetime.now()
    host = os.uname().nodename.split(".")[0]
    lines = [f":stethoscope: *시스템 헬스 리포트* ({host}) — {now:%Y-%m-%d %H:%M}"]

    info = copilot_instructions_info()
    if info:
        parts = [f"`{info['hash']}`@`{info['branch']}`"]
        if info["dirty"]:
            parts.append("dirty")
        if info["ahead"]:
            parts.append(f"{info['ahead']} ahead")
        if info["behind"]:
            parts.append(f"{info['behind']} behind")
        lines.append(f"_copilot-instructions: {' · '.join(parts)}_")

    # System
    lines.append("")
    lines.append("*:computer: 시스템*")
    temp = cpu_temp_c()
    if temp is not None:
        lines.append(f"  • {tag(temp, TEMP_WARN, TEMP_CRIT)} CPU 온도 {temp:.1f}°C")
    total_d, used_d, pct_d = disk_usage_pct()
    lines.append(
        f"  • {tag(pct_d, DISK_WARN, DISK_CRIT)} 디스크 / : "
        f"{human_bytes(used_d)} / {human_bytes(total_d)} ({pct_d:.1f}%)"
    )
    total_m, used_m, pct_m = mem_usage_pct()
    lines.append(
        f"  • {tag(pct_m, MEM_WARN, MEM_CRIT)} 메모리 : "
        f"{human_bytes(used_m)} / {human_bytes(total_m)} ({pct_m:.1f}%)"
    )
    l1, l5, l15, ncpu = loadavg()
    load_ratio = l1 / ncpu
    lines.append(
        f"  • {tag(load_ratio, LOAD_WARN_RATIO, LOAD_CRIT_RATIO)} "
        f"load {l1:.2f} / {l5:.2f} / {l15:.2f} (CPU {ncpu}코어)"
    )
    lines.append(f"  • :hourglass_flowing_sand: 가동 {uptime_human()}")

    # Services
    lines.append("")
    lines.append("*:wrench: 서비스*")
    failed_lc = launchctl_failed()
    if failed_lc:
        lines.append(f"  • :red_circle: launchctl 실패 {len(failed_lc)}건")
        for f in failed_lc[:5]:
            lines.append(f"    – {f}")
        if len(failed_lc) > 5:
            lines.append(f"    – … +{len(failed_lc) - 5}건")
    else:
        lines.append("  • :large_green_circle: launchctl 실패 없음")
    running, total, problems = docker_summary()
    if total:
        d_tag = ":large_green_circle:" if not problems else ":large_orange_circle:"
        lines.append(f"  • {d_tag} Docker {running}/{total} running")
        for p in problems[:5]:
            lines.append(f"    – {p}")
        if len(problems) > 5:
            lines.append(f"    – … +{len(problems) - 5}건")

    return "\n".join(lines)


# ---------- Slack ----------

def post_slack(token: str, channel: str, text: str) -> dict:
    req = urllib.request.Request(
        "https://slack.com/api/chat.postMessage",
        data=json.dumps({"channel": channel, "text": text, "mrkdwn": True}).encode(),
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json; charset=utf-8",
        },
    )
    with urllib.request.urlopen(req, timeout=15) as resp:
        return json.loads(resp.read())


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true", help="print report, do not post")
    args = ap.parse_args()

    report = build_report()

    if args.dry_run:
        print(report)
        return 0

    env = load_env(ENV_FILE)
    token = env.get("SLACK_BOT_TOKEN") or os.environ.get("SLACK_BOT_TOKEN")
    channel = env.get("HEALTH_CHANNEL") or os.environ.get("HEALTH_CHANNEL")
    if not token or not channel:
        print(f"[system-health] missing SLACK_BOT_TOKEN or HEALTH_CHANNEL in {ENV_FILE}", file=sys.stderr)
        return 2

    resp = post_slack(token, channel, report)
    if not resp.get("ok"):
        print(f"[system-health] slack error: {resp}", file=sys.stderr)
        return 3
    print(f"[system-health] posted ts={resp.get('ts')}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
