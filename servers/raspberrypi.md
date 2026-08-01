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
- status report: cron `0 23`, `scripts/system-health.py` → Slack DM `C0AFD7AQ4QK` (이미 셋업). 스크립트는 repo의 포터블 버전으로 통합됨 (배선 갱신: `scripts/setup-status-report.sh`)
- node heartbeat: `homelab-node-agent.service` (systemd, **User=diehard**, enabled) → Memo `/nodes` 5분 주기. repo `~/homelab-node-agent`, config `node-agent.json`. git_repos 리포트(workspace/copilot-instructions/homelab-node-agent 절대경로). root로 돌리면 `~`가 /root라 git_repos 깨짐 → 반드시 User=diehard
- cron 자동화 리포팅: node-agent `cron_jobs` 콜렉터(minione 구현)로 metadata.cron_jobs에 잡별 신선도(log mtime)+ok+last_error 표시. config에 10개 등록(flush/slack-inbox/youtube/disk-cookie/daily5/weekly). `cron_error_log`=memory/cron-errors.jsonl. ※ market 잡은 weekday+TZ 가드라 로그 MISSING 시 오탐 → 제외
- gallery: yozit media server로 기능 마이그레이션 완료 (`gallery.service`는 6/30 중지+disable, 이 머신에선 미운영)
- secondary DNS: **Pi-hole (docker)** — 인프라 SPOF 완화용 failover resolver (이전 dnsmasq에서 마이그레이션, 2026-07-04). adblock(StevenBlack gravity)까지 failover됨. compose `/opt/pihole/docker-compose.yml` (`pihole/pihole:latest`, `network_mode: host`), data `/opt/pihole/etc-pihole`. standalone upstream 1.1.1.1/1.0.0.1/8.8.8.8 (`FTLCONF_dns_upstreams`)이라 primary(yozit pihole 10.0.0.172) 다운 시에도 동작. `FTLCONF_dns_listeningMode: all`로 lo/eth0(192.168.50.192)/tailscale0(100.79.4.18) 전부 응답. web `http://<rpi>/admin/`, 비번 `/root/.pihole-web-pw` (또는 compose의 `FTLCONF_webserver_api_password`). 구 dnsmasq.service는 stop+disable, config는 `/opt/pihole/legacy-dnsmasq-backup/`로 백업 이동(`/etc/dnsmasq.d`는 정리됨). 로컬레코드 sync = `scripts/sync-secondary-dns.sh` (pihole→pihole mirror: yozit `/etc/pihole/pihole.toml`의 `dns.hosts`+`dns.cnameRecords`를 `pihole-FTL --config`로 rpi에 반영, idempotent). SSH `paryoja@100.101.180.8` (yozit docker 경로 `/usr/local/bin/docker`), cron `*/15 * * * *` (`cron-error-wrap.sh dns-sync`, 로그 `/tmp/dns-sync.log`). gravity/blocklist은 각자 유지(sync 안 함) — adblock은 이미 각 pihole이 독립적으로 함. **네트워크 주의**: rpi(192.168.50.0/24)와 yozit LAN(10.0.0.0/24)이 중첩 NAT라 10.0.0.x 클라이언트는 rpi LAN IP로 직접 도달 불가 → secondary는 tailnet(100.79.4.18) 기준 또는 라우터 포트포워드 필요
