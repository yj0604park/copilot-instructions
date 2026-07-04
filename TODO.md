# TODO: 서버 환경 동기화 프로젝트

## 완료
- [x] Tailscale 메시 네트워크 — 모든 기기 연결됨
- [x] 모니터링 대시보드 — Uptime Kuma + Grafana 운영 중

## 할 일
- [ ] install.sh Linux 테스트 — Pi/mini 서버에서 실행, 누락 패키지 처리
- [ ] atuin 동기화 설정 — 모든 기기 셸 히스토리 통합
- [x] SSH config 관리 — repo `ssh/config` + `~/.ssh/config` Include (install.sh 배선). 키/비밀은 .gitignore로 차단, 로컬 전용 호스트는 repo 밖 유지
- [ ] 서버별 bootstrap 분기 — install.sh에 `--server` 모드 (GUI 앱 제외, 서버 전용 패키지)
- [x] 서버별 환경 문서 작성 — 각 머신의 설치된 도구/서비스 정리
- [ ] DNS failover 클라이언트 배포 — rpi pihole은 secondary로 준비됨(adblock+record sync 완료)이나, 클라이언트가 rpi를 2차 DNS로 안 봐서 yozit 다운 시 전체 다운됨. 라우터 DHCP에 DNS 2개(yozit + rpi) 배포 필요. 선결: (1) 10.0.0.0/24 DHCP 주체 확인, (2) 중첩 NAT라 rpi 도달 IP(tailnet/포트포워드) 확정. 하드 failover 원하면 keepalived VIP(단, 서브넷 다름 → L2 브리지 필요)
