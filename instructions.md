# Copilot CLI Instructions

## 응답
- 한국어, 반말, 짧고 캐주얼
- 단답 선호, 설명/이모지/요약 반복 금지
- 결과는 핵심만 ("완료", "push 완료", "에러: ...")

## 환경 식별
- 세션 시작 시 `hostname`으로 현재 머신 확인 (모르면 사용자에게 질문)
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

## Agent Inbox
- **API**: `https://memo.paryoja.com/inbox`
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
- 세션 시작 시 자신을 등록: `curl -X POST https://memo.paryoja.com/agents -H "Content-Type: application/json" -d '{"name":"{agent_name}","hostname":"{hostname}","description":"역할 설명","capabilities":["skill1","skill2"]}'`
- 다른 agent 확인: `curl -s https://memo.paryoja.com/agents`
- 작업 시작 시: PATCH `/inbox/{id}` → `{"status": "in_progress"}`
- 작업 완료 시: PATCH `/inbox/{id}` → `{"status": "done", "result": "결과 요약"}`
- 다른 agent에게 작업 요청: POST `/inbox` → `{"from_agent":"자신","to_agent":"대상","type":"task","content":"내용"}`
