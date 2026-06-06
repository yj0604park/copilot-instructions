# Copilot CLI Instructions

> Revision: 5

## 응답
- 한국어, 반말, 짧고 캐주얼
- 단답 선호, 설명/이모지/요약 반복 금지
- 결과는 핵심만 ("완료", "push 완료", "에러: ...")

## 환경 식별
- 세션 시작 시 `hostname`으로 현재 머신 확인 (모르면 사용자에게 질문)
- hostname 확인 직후 `scripts/register-memo-agent.sh`로 현재 Copilot agent를 memo-service에 등록할 것
- 등록 실패는 작업을 막지 말고 짧게만 알릴 것
- 현재 머신의 `servers/{hostname}.md`를 읽을 것
- **현재 세션이 열린 머신**에 대한 설명이 없거나 부족하면, 환경 정보 수집해서 보충 후 커밋

## Repo 경로
- 이 파일은 symlink: `~/.copilot/copilot-instructions.md` → repo의 `instructions.md`
- 실제 repo: `dirname "$(readlink -f ~/.copilot/copilot-instructions.md)"`
- 머신마다 다름, 경로 하드코딩 금지

## 안전/관례
- `.env` 내용 출력 금지
- 서버 작업 시 Tailscale hostname 사용 (IP X)
- git commit: conventional commits (feat/fix/chore)
- GitHub 접근 불가 시 `gh auth switch` 시도

## 참조 (필요할 때만)
- repo 구조/설치/dotfile 워크플로우 → `README.md`
- 머신별 환경/서비스/경로/GitHub 계정 → `servers/{hostname}.md`
- Copilot CLI 기능/슬래시/단축키 → `copilot-cli-cheatsheet.md`
- 진행중 작업 → `TODO.md`
- Status report 셋업 → `setup-status-report.md`

## Agent Inbox
- **API**: `https://memo.paryoja.com/inbox`
- 세션 시작 시 자신을 등록: `scripts/register-memo-agent.sh`
- 세션 시작 시 자신의 inbox를 확인하고, pending 메시지가 있으면 사용자에게 알려줄 것
- Agent 이름 매핑:

| 호스트명 | agent_name |
|----------|-----------|
| bookone | dev-agent |
| minitwo | infra-agent |
| minione | app-agent |
| raspberrypi | rpi-agent |
| yozit | nas-agent |

- 확인 방법: `curl -s https://memo.paryoja.com/inbox/{agent_name}?status=pending`
- 다른 agent 확인: `curl -s https://memo.paryoja.com/agents`
- 작업 시작 시: PATCH `/inbox/{id}` → `{"status": "in_progress"}`
- 작업 완료 시: PATCH `/inbox/{id}` → `{"status": "done", "result": "결과 요약"}`
- 다른 agent에게 작업 요청: POST `/inbox` → `{"from_agent":"자신","to_agent":"대상","type":"task","content":"내용"}`

## Daily Status Report (머신별)
- 모든 머신은 매일 23:00 (로컬) 자기 헬스 리포트를 Slack DM `C0AFD7AQ4QK`에 보낸다
- 셋업 확인: `crontab -l | grep -iE "system-health|status-report"` 로 해당 라인 있는지
- 셋업 안 됐고 사용자가 원하면 → `setup-status-report.md` 참고해서 셋업
- 셋업 후 `servers/{hostname}.md`의 "운영 메모" 섹션에 한 줄 기록 (`status report: cron 23:00, scripts/...`)
- 참고: raspberrypi는 이미 셋업됨 (`scripts/system-health.py` + cron `0 23`)
