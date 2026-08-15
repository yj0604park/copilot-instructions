#!/usr/bin/env python3
"""Daily system health summary — portable across macOS / Linux / Synology DSM.

Posts a Slack message directly using a bot token at
~/.config/system-health/env (SLACK_BOT_TOKEN, HEALTH_CHANNEL).

Sections:
  - copilot-instructions: hash@branch (+ dirty/ahead/behind)
  - System: CPU temp (if available), memory, root disk, load avg, uptime
  - Services: failed init jobs (launchd/systemd) + docker container status

Platform notes:
  macOS      : sysctl/vm_stat, launchctl
  Linux      : /proc/{meminfo,uptime}, /sys/class/thermal, systemctl --failed
  Synology   : Linux paths, but no systemd -> init check skipped, docker is at
               /usr/local/bin/docker (not on cron's PATH)

Usage:
  system-health.py [--dry-run]
"""
from __future__ import annotations

import argparse
import json
import os
import platform
import re
import shutil
import subprocess
import sys
import time
import urllib.request
from datetime import datetime
from pathlib import Path

ENV_FILE = Path.home() / ".config" / "system-health" / "env"

TEMP_WARN, TEMP_CRIT = 70.0, 80.0
DISK_WARN, DISK_CRIT = 80.0, 90.0
MEM_WARN, MEM_CRIT = 85.0, 95.0
LOAD_WARN_RATIO, LOAD_CRIT_RATIO = 1.0, 2.0

IS_MAC = platform.system() == "Darwin"
IS_LINUX = platform.system() == "Linux"
# Synology DSM ships a /etc/synoinfo.conf and has no systemd.
IS_SYNOLOGY = IS_LINUX and Path("/etc/synoinfo.conf").exists()

# cron/launchd give a minimal PATH; look for tools in the usual extra spots too.
EXTRA_PATH = ["/usr/local/bin", "/opt/homebrew/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin"]


def which(name: str) -> str | None:
    found = shutil.which(name)
    if found:
        return found
    for d in EXTRA_PATH:
        cand = Path(d) / name
        if cand.is_file() and os.access(cand, os.X_OK):
            return str(cand)
    return None


def run(cmd: list[str], timeout: int = 10) -> subprocess.CompletedProcess | None:
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    except Exception:
        return None


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
    if IS_MAC:
        for name, args in (("osx-cpu-temp", ["-c"]), ("istats", ["cpu", "temp"])):
            exe = which(name)
            if not exe:
                continue
            p = run([exe, *args], timeout=5)
            if p and p.returncode == 0:
                m = re.search(r"(\d+\.?\d*)", p.stdout)
                if m:
                    return float(m.group(1))
        return None

    # Linux: prefer a CPU-ish thermal zone, else vcgencmd (Raspberry Pi).
    best = None
    for zone in sorted(Path("/sys/class/thermal").glob("thermal_zone*")):
        try:
            raw = (zone / "temp").read_text().strip()
            celsius = float(raw) / 1000.0
        except Exception:
            continue
        if not 0 < celsius < 150:
            continue
        try:
            zone_type = (zone / "type").read_text().strip().lower()
        except Exception:
            zone_type = ""
        if any(k in zone_type for k in ("cpu", "soc", "x86_pkg", "coretemp")):
            return celsius
        best = celsius if best is None else max(best, celsius)
    if best is not None:
        return best

    exe = which("vcgencmd")
    if exe:
        p = run([exe, "measure_temp"], timeout=5)
        if p and p.returncode == 0:
            m = re.search(r"(\d+\.?\d*)", p.stdout)
            if m:
                return float(m.group(1))
    return None


def disk_usage_pct() -> tuple[int, int, float]:
    s = shutil.disk_usage("/")
    return s.total, s.used, (s.used / s.total) * 100


def mem_usage_pct() -> tuple[int, int, float]:
    """Return (total_bytes, used_bytes, pct)."""
    if IS_MAC:
        # sysctl for total, vm_stat for breakdown. "Used" = total - free -
        # inactive - speculative, matching Activity Monitor's approximation.
        total = int(subprocess.check_output(["sysctl", "-n", "hw.memsize"]).strip())
        out = subprocess.check_output(["vm_stat"]).decode()
        m = re.search(r"page size of (\d+) bytes", out)
        page = int(m.group(1)) if m else 4096
        stats: dict[str, int] = {}
        for line in out.splitlines():
            m = re.match(r'"?([A-Za-z][\w\- ]+?)"?:\s+(\d+)\.?', line)
            if m:
                stats[m.group(1).strip()] = int(m.group(2)) * page
        used = (
            total
            - stats.get("Pages free", 0)
            - stats.get("Pages inactive", 0)
            - stats.get("Pages speculative", 0)
        )
        return total, used, (used / total) * 100

    # Linux: MemAvailable is the honest "how much can I still use" number.
    info: dict[str, int] = {}
    for line in Path("/proc/meminfo").read_text().splitlines():
        m = re.match(r"(\w+):\s+(\d+) kB", line)
        if m:
            info[m.group(1)] = int(m.group(2)) * 1024
    total = info.get("MemTotal", 0)
    if not total:
        return 0, 0, 0.0
    available = info.get("MemAvailable")
    if available is None:
        available = (
            info.get("MemFree", 0) + info.get("Buffers", 0) + info.get("Cached", 0)
        )
    used = total - available
    return total, used, (used / total) * 100


def loadavg() -> tuple[float, float, float, int]:
    l1, l5, l15 = os.getloadavg()
    return l1, l5, l15, os.cpu_count() or 1


def uptime_human() -> str:
    seconds = None
    if IS_MAC:
        raw = subprocess.check_output(["sysctl", "-n", "kern.boottime"]).decode()
        m = re.search(r"sec = (\d+)", raw)
        if m:
            seconds = time.time() - int(m.group(1))
    else:
        try:
            seconds = float(Path("/proc/uptime").read_text().split()[0])
        except Exception:
            seconds = None
    if seconds is None:
        return "?"
    d = int(seconds // 86400)
    h = int((seconds % 86400) // 3600)
    mi = int((seconds % 3600) // 60)
    if d:
        return f"{d}일 {h}시간"
    if h:
        return f"{h}시간 {mi}분"
    return f"{mi}분"


# ---------- Services ----------

def init_failed() -> tuple[str, list[str]]:
    """Return (label, failed_units). label is '' when the check doesn't apply."""
    if IS_MAC:
        p = run(["launchctl", "list"])
        if not p:
            return "launchctl", []
        failed = []
        for line in p.stdout.splitlines()[1:]:
            parts = line.split(None, 2)
            if len(parts) < 3:
                continue
            pid, status, label = parts
            if status in ("0", "-"):
                continue
            # PID column is numeric while the job is running: `status` is then a
            # stale exit code from a previous run (e.g. 143 on a restart), not a
            # current failure.
            if pid.isdigit():
                continue
            if label.startswith(("com.apple.", "0x")):
                continue
            failed.append(f"{label} (exit {status})")
        return "launchctl", failed

    if IS_SYNOLOGY or not which("systemctl"):
        return "", []

    p = run(["systemctl", "--failed", "--no-legend", "--plain"])
    if not p or p.returncode not in (0, 1):
        return "systemd", []
    failed = []
    for line in p.stdout.strip().splitlines():
        unit = line.split()[0] if line.split() else ""
        if unit:
            failed.append(unit)
    return "systemd", failed


def docker_summary() -> tuple[int, int, list[str]]:
    """Return (running, total, problem_lines). Empty if docker missing."""
    exe = which("docker")
    if not exe:
        return 0, 0, []
    p = run([exe, "ps", "-a", "--format", "{{.Names}}\t{{.Status}}"], timeout=20)
    if not p or p.returncode != 0:
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
        git = which("git")
        if not git:
            return None

        def g(*args):
            return subprocess.check_output(
                [git, "-C", str(repo), *args], stderr=subprocess.DEVNULL
            ).decode().strip()

        out = {
            "branch": g("rev-parse", "--abbrev-ref", "HEAD"),
            "hash": g("rev-parse", "--short", "HEAD"),
            "dirty": bool(g("status", "--porcelain")),
            "ahead": 0,
            "behind": 0,
            "install_pending": False,
        }
        try:
            counts = g("rev-list", "--left-right", "--count", "@{u}...HEAD").split()
            if len(counts) == 2:
                out["behind"], out["ahead"] = int(counts[0]), int(counts[1])
        except Exception:
            pass
        # install.sh stamps .git/installed-commit; a mismatch means the repo was
        # pulled but install.sh never re-ran (symlinks/agents possibly stale).
        try:
            stamp = Path(g("rev-parse", "--git-dir"))
            if not stamp.is_absolute():
                stamp = repo / stamp
            stamp = stamp / "installed-commit"
            if stamp.exists():
                out["install_pending"] = (
                    stamp.read_text().strip() != g("rev-parse", "HEAD")
                )
        except Exception:
            pass
        return out
    except Exception:
        return None


# ---------- Report ----------

def build_report() -> str:
    now = datetime.now()
    host = platform.node().split(".")[0]
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
        if info["install_pending"]:
            parts.append(":warning: install 안 됨")
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
    if total_m:
        lines.append(
            f"  • {tag(pct_m, MEM_WARN, MEM_CRIT)} 메모리 : "
            f"{human_bytes(used_m)} / {human_bytes(total_m)} ({pct_m:.1f}%)"
        )
    l1, l5, l15, ncpu = loadavg()
    lines.append(
        f"  • {tag(l1 / ncpu, LOAD_WARN_RATIO, LOAD_CRIT_RATIO)} "
        f"load {l1:.2f} / {l5:.2f} / {l15:.2f} (CPU {ncpu}코어)"
    )
    lines.append(f"  • :hourglass_flowing_sand: 가동 {uptime_human()}")

    # Services
    lines.append("")
    lines.append("*:wrench: 서비스*")
    label, failed = init_failed()
    if label:
        if failed:
            lines.append(f"  • :red_circle: {label} 실패 {len(failed)}건")
            for f in failed[:5]:
                lines.append(f"    – {f}")
            if len(failed) > 5:
                lines.append(f"    – … +{len(failed) - 5}건")
        else:
            lines.append(f"  • :large_green_circle: {label} 실패 없음")
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
        print(
            f"[system-health] missing SLACK_BOT_TOKEN or HEALTH_CHANNEL in {ENV_FILE}",
            file=sys.stderr,
        )
        return 2

    resp = post_slack(token, channel, report)
    if not resp.get("ok"):
        print(f"[system-health] slack error: {resp}", file=sys.stderr)
        return 3
    print(f"[system-health] posted ts={resp.get('ts')}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
