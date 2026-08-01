# TODO: 서버 환경 동기화 프로젝트

## 완료
- [x] Tailscale 메시 네트워크 — 모든 기기 연결됨
- [x] 모니터링 대시보드 — Uptime Kuma + Grafana 운영 중

## 할 일
- [ ] install.sh Linux 테스트 — Pi/mini 서버에서 실제 실행 (`--server`), 누락 패키지 처리
- [ ] atuin 동기화 설정 — 모든 기기 셸 히스토리 통합
- [x] SSH config 관리 — repo `ssh/config` + `~/.ssh/config` Include (install.sh 배선). 키/비밀은 .gitignore로 차단, 로컬 전용 호스트는 repo 밖 유지
- [x] 서버별 bootstrap 분기 — `install.sh --server` (Brewfile에서 cask/tap 필터링, Nerd Font 안내 skip)
- [x] 서버별 환경 문서 작성 — 각 머신의 설치된 도구/서비스 정리
- [ ] Secrets 중앙화 (key vault) — 각 머신 `.env` 흩어져 있음. 검토(2026-07):
  - **후보**: Infisical(self-host, 추천) / HashiCorp Vault(무거움) / SOPS+age(서버리스, UI·회전·감사 없음)
  - **Infisical 선정 근거**: `infisical run -- <cmd>` 런타임 주입 + `infisical export`로 `.env` 생성 → 기존 앱 코드 무수정. 머신 아이덴티티로 노드별 스코프. docker compose(Postgres+Redis) self-host, UI 깔끔
  - **배포 후보 노드**: yozit(NAS, docker 다수·uptime 좋음, `vault.paryoja.com`+Caddy) vs minione(기존 Postgres 스택·memo-service)
  - **미결정**: 도구 확정 / 배포 노드 / 마이그레이션 범위(어느 `.env`부터)
- [ ] DNS failover 클라이언트 배포 — rpi pihole은 secondary로 준비됨(adblock+record sync 완료)이나, 클라이언트가 rpi를 2차 DNS로 안 봐서 yozit 다운 시 전체 다운됨. 라우터 DHCP에 DNS 2개(yozit + rpi) 배포 필요. 선결: (1) 10.0.0.0/24 DHCP 주체 확인, (2) 중첩 NAT라 rpi 도달 IP(tailnet/포트포워드) 확정. 하드 failover 원하면 keepalived VIP(단, 서브넷 다름 → L2 브리지 필요)

- [ ] 노드 stale 알림 — homelab-node-agent가 죽어도 아무도 모른다 (bookone은 2026-07-12부터
      3주간 방치, yozit 컨테이너도 같은 시기 Exited). memo-service가 24h 무heartbeat 노드를
      Slack으로 알리도록 요청함 (minione 소유). 리포터가 죽으면 리포트가 안 오는 순환 구조를 끊는 게 목적
- [x] system-health 스크립트 통합 — `scripts/system-health.py` 하나로 macOS/Linux/Synology 지원.
      배선은 `scripts/setup-status-report.sh`. bookone/rpi/yozit에서 동작 검증
- [x] CI — GitHub Actions shellcheck + bash -n + py_compile (`.github/workflows/lint.yml`)
