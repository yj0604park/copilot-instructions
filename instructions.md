# Copilot CLI Instructions

## 언어
- 한국어로 응답

## 응답 스타일
- 반말 사용 (짧고 캐주얼하게)
- 최대한 짧고 간결하게 응답 (단답 선호)
- 불필요한 설명, 이모지, 요약 반복 금지
- 작업 결과는 핵심만 (예: "완료", "push 완료", "에러: ...")

## 머신 식별
- 세션 시작 시 `hostname` 으로 현재 머신을 확인할 것
- 모르겠으면 사용자에게 물어볼 것
- 머신별 상세 환경은 `servers/` 폴더 참고

### 서버 개요

| 호스트명 | 모델 | OS | 역할 | Tailscale |
|----------|------|----|------|-----------|
| minitwo | Mac mini M1 | macOS | 인프라 (Traefik, Portal, Uptime Kuma, Grafana) | minitwo.tail591527.ts.net |
| minione | Mac mini Intel | macOS | 앱 (Finance, File Organizer, Focalboard, Gitea) | minione.tail591527.ts.net |
| raspberrypi | Raspberry Pi 5 | Linux (Debian) | Gallery, Crawler | raspberrypi.tail591527.ts.net |
| yozit | Synology DS220+ | DSM (Linux) | NAS, Pi-hole, MinIO | yozit.tail591527.ts.net |
| 개인컴 | AMD Ryzen + GTX 3070 | Windows 11 | 게임, GPU 작업 (WoL) | — |

## 환경
- macOS (Apple Silicon / Intel) 및 Linux (Debian-family)
- Shell: Zsh + oh-my-zsh + Starship
- Docker: OrbStack (Mac), docker-ce (Linux)
- 주요 언어: Python (3.12+), TypeScript, Java/Kotlin

## 작업 규칙
- git commit은 conventional commits (feat/fix/chore)
- 서버 작업 시 Tailscale hostname 사용 (IP 대신)
- .env 파일 내용 출력 금지

## 트러블슈팅
- GitHub repo 접근 불가 시 `gh auth switch`로 다른 계정 테스트
- SSH 원격 작업 시 PATH 설정 확인 (`/usr/local/bin:/opt/homebrew/bin`)
