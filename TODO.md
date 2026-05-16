# TODO: 서버 환경 동기화 프로젝트

## 환경
- Mac (개발 메인)
- Raspberry Pi (크롤링, 이미지 뷰어)
- 클라우드 서버 (유휴)
- NAS (별도)
- miniOne, miniTwo (추가 서버)

## 할 일

- [ ] install.sh Linux 테스트 — Pi/mini 서버에서 실행, 누락 패키지 처리
- [ ] atuin 동기화 설정 — 모든 기기 셸 히스토리 통합
- [ ] SSH config 관리 — `~/.ssh/config`를 repo에 추가 (Pi, mini, NAS 접속 정보)
- [ ] 서버별 bootstrap 분기 — install.sh에 `--server` 모드 (GUI 앱 제외, 서버 전용 패키지)
- [ ] Tailscale 메시 네트워크 — 모든 기기 간 VPN 연결
- [ ] 모니터링 대시보드 — 서버 상태 통합 확인 (uptime, 디스크 등)
