# TODO: 서버 환경 동기화 프로젝트

## 환경
- Mac (Minitwo M1, Minione Intel — 개발/서비스)
- Raspberry Pi 5 (Gallery, AI)
- NAS Yozit (Pi-hole, MinIO)
- 개인컴 (게이밍 PC)

## 완료
- [x] Tailscale 메시 네트워크 — 모든 기기 연결됨
- [x] 모니터링 대시보드 — Uptime Kuma + Grafana 운영 중

## 할 일
- [ ] install.sh Linux 테스트 — Pi/mini 서버에서 실행, 누락 패키지 처리
- [ ] atuin 동기화 설정 — 모든 기기 셸 히스토리 통합
- [ ] SSH config 관리 — `~/.ssh/config`를 repo에 추가 (Pi, mini, NAS 접속 정보)
- [ ] 서버별 bootstrap 분기 — install.sh에 `--server` 모드 (GUI 앱 제외, 서버 전용 패키지)
- [ ] 서버별 환경 문서 작성 — 각 머신의 설치된 도구/서비스 정리
