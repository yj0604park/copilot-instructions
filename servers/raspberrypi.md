# Raspberry Pi — Instagram & AI

## 스펙
- **모델**: Raspberry Pi 5 Model B Rev 1.0
- **CPU**: ARM Cortex-A76, 4코어, aarch64
- **메모리**: 8GB
- **디스크**: 117GB (mmcblk0p2)
- **OS**: Debian bookworm (Linux 6.12, aarch64)
- **Tailscale**: `raspberrypi.tail591527.ts.net` (100.79.4.18)
- **LAN IP**: 192.168.50.192

## 런타임
- **Python**: 3.11.2 (시스템)
- **Node**: v22.x
- **Docker**: 미설치 (서비스는 systemd로 직접 운영)

## 주요 작업
- Instagram Crawler
- 이미지 사람 감지 (현재: Groq API → YOLO 로컬 전환 예정)
- Copilot CLI 워크스페이스 (`~/.openclaw/workspace/`) — 에이전트 페르소나/메모리

## 프로젝트 경로
- `~/.openclaw/workspace/` — Copilot 에이전트 작업 디렉토리
- `~/.openclaw/workspace/copilot-instructions/` — dotfiles/instructions repo
- `~/.openclaw/workspace/projects/` — Instagram 등 서브 프로젝트

## GitHub 계정
- 활성: `yj0604park` (기본)
- 추가 로그인: `diehardclaw99-creator` (이 워크스페이스 repo 소유 — `clo-automations`)
- repo 접근 불가 시 `gh auth switch`

## 도메인 패턴
- `*.tail591527.ts.net` — Tailscale 내부 (`raspberrypi.tail591527.ts.net`)

## 운영 메모
- Docker 도입 시 `docker-ce` apt 설치 필요
- SSH 원격 작업 시 PATH: `/usr/local/bin:/usr/bin` (기본으로 충분)
- status report: cron `0 23`, `scripts/system-health.py` → Slack DM `C0AFD7AQ4QK` (이미 셋업)
- node heartbeat: `homelab-node-agent.service` (systemd, enabled) → Memo `/nodes` 5분 주기. repo `~/homelab-node-agent`, config `node-agent.json` (hostname=raspberrypi, service_check=gallery.service)
