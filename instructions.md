# Copilot CLI Instructions

## 언어
- 한국어로 응답

## 응답 스타일
- 최대한 짧고 간결하게 응답 (단답 선호)
- 불필요한 설명, 이모지, 요약 반복 금지
- 작업 결과는 핵심만 (예: "완료", "push 완료", "에러: ...")

## 환경
- macOS (Apple Silicon / Intel) 및 Linux (Debian-family)
- Shell: Zsh + oh-my-zsh + Starship
- Docker: OrbStack (Minitwo), docker-ce (Linux)
- 주요 언어: Python (3.12+), TypeScript, Java/Kotlin

## 작업 규칙
- git commit은 conventional commits (feat/fix/chore)
- 서버 작업 시 Tailscale hostname 사용 (IP 대신)
- .env 파일 내용 출력 금지

## 트러블슈팅
- GitHub repo 접근 불가 시 `gh auth switch`로 다른 계정 테스트
- SSH 원격 작업 시 PATH 설정 확인 (`/usr/local/bin:/opt/homebrew/bin`)
