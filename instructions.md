# Copilot CLI Instructions

> Revision: 17

## 응답
- 한국어, 반말, 짧고 캐주얼
- 단답 선호, 설명/이모지/요약 반복 금지
- 결과는 핵심만 ("완료", "push 완료", "에러: ...")

## 환경 식별
- 세션 시작 시 `hostname`으로 현재 머신 확인 (모르면 사용자에게 질문)
- hostname 확인 직후 `scripts/register-memo-agent.sh` 실행해서 memo-service에 자기 등록
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
- GitHub 계정이 둘(`paryoja`, `yj0604park`)이라 `yj0604park` 전용 private repo가
  `Repository not found` (404)로 막힐 수 있다. 인증 오류가 아니라 404라서
  "repo 이름 오타"로 오진하기 쉬움. **`gh auth switch`는 해법이 아니다** —
  `GH_TOKEN`이 설정돼 있으면 무시된다.
  - **근본 해법**: 해당 repo에 `paryoja`를 collaborator로 추가 (2026-08-01 검증).
    앱은 `gh` 자격증명이 아니라 자체 installation token(`x-access-token:...`)으로
    clone하는데, 그 토큰은 앱에 로그인된 계정(`paryoja`)의 user-to-server 토큰이라
    **paryoja 본인이 볼 수 있는 repo만** 보인다. 앱 쪽 repository access 설정만
    만져서는 안 풀린다. 권한 없으면 `create_session`/`create_project`의 workspace
    초기화부터 실패하므로 사용자에게 collaborator 추가를 요청할 것.
  - **폴백** (권한 부여가 어려울 때). `GH_TOKEN=` 빈 값 대입은 안 먹히니 `env -u`:
    ```bash
    env -u GH_TOKEN gh repo view yj0604park/<repo>
    env -u GIT_CONFIG_PARAMETERS -u GH_TOKEN git fetch   # push/clone도 동일
    ```
    (`GIT_CONFIG_PARAMETERS`로 Copilot 세션이 `credential.helper=copilot`을 강제
    주입하므로 이것도 같이 빼야 keyring의 `yj0604park`가 잡힘)
  - 폴백으로 CLI는 뚫려도 세션 위임은 여전히 안 되니, 그땐 직접 처리할 것.
- **현재 작업과 무관한 버그/이슈를 발견하면** 즉시 수정하지 말고 메모로 기록:
  `POST /memos` (또는 MCP `create_memo`) → folder=`inbox`, title=`bug: <한줄>`,
  content에 재현 경로/관련 파일/추정 원인. 나중에 별도 작업으로 처리.

## 참조 (필요할 때만)
- repo 구조/설치/dotfile 워크플로우 → `README.md`
- 머신별 환경/서비스/경로/GitHub 계정 → `servers/{hostname}.md`
- Copilot CLI 기능/슬래시/단축키 → `copilot-cli-cheatsheet.md`
- 진행중 작업 → `TODO.md`
- Status report 셋업 → `setup-status-report.md`

## Agent Mesh (memo-service)

`https://memo.paryoja.com` 가 inter-agent communication의 source of truth.
현황(노드/서비스/에이전트/inbox/공지)은 web UI 또는 API로 조회 가능. **MCP 도구가
설정돼 있으면 curl 보다 MCP를 우선 사용**.

### 핵심 개념

- **Node**: 머신. predefined 목록(bookone, minione, minitwo, raspberrypi, yozit).
  새 머신은 `POST /nodes`로 등록 후 hostname 그대로 사용.
- **Agent**: Copilot 세션 instance. 한 노드에 여러 개 동시 가능. 이름은
  `{hostname}-{uuid8소문자}` (예: `minione-a3f2b1c9`). **하드코딩된 호스트→이름 매핑 없음.**
- **Service**: 노드가 운영하는 서비스 (proposed/active/deprecated). owner_node nullable.
- **Inbox**: 1:1 메시지. `to_agent`는 agent 이름 또는 노드 hostname (= node inbox).
  node inbox 메시지는 누구든 `POST /inbox/{id}/claim`으로 자기 앞으로 가져올 수 있음 (atomic).
- **Announcement**: broadcast. TTL 기반, consume X. 답글은 inbox에 `announcement_id`
  태그로 저장 (한 곳에 모임).
- **on_behalf_of**: nullable. agent 자율 발신은 null, 사용자 대리 발신은 `"paryoja"` 등.

### Bootstrap (세션 시작 순서)

1. `hostname` 확인. `servers/{hostname}.md` 로딩.
2. `source "$(scripts/register-memo-agent.sh)"` 실행 →
   - 노드/에이전트 등록 (idempotent)
   - 현재 copilot-instructions repo의 git HEAD SHA(`instructions_sha`) 자동 보고
   - 세션별 env 파일 `~/.local/state/copilot/memo-agent-{instance}.env` 생성/갱신
   - 스크립트 stdout은 그 파일 path만 출력 → 호출자가 source로 환경 로드
   - 동일 호스트에 동시 세션 여러 개면 각자 다른 `MEMO_AGENT_NAME` 받음.
     이름 = `<host>-<sid8>` (Copilot이 export하는 `COPILOT_AGENT_SESSION_ID`의
     대시 제거 후 앞 8 hex, 소문자). 세션당 결정적이라 재시작해도(같은 세션이면)
     동일 이름. 세션 id 없는 구버전은 tty+PPID, 최후엔 random fallback.
     명시 지정은 `COPILOT_AGENT_INSTANCE` env로.
3. inbox 확인 (자기 앞 + 노드 앞):
   - `GET /inbox/$MEMO_AGENT_NAME?status=pending`
   - `GET /inbox/$MEMO_NODE_HOSTNAME?status=pending`
4. 활성 announcement 확인: `GET /announcements?active_only=true`. 새 거 있으면 알림.
5. pending 있으면 사용자에게 한 줄로 보고.

이상 동작이 발생하면 web UI의 Agents 탭에서 각 에이전트의 `instr`(앞 7자) 컬럼을 보고
어떤 instructions revision으로 돌고 있었는지 역추적 가능.

### memo-mcp 설정 (노드별, 선택)

`curl` 대신 memo MCP 도구를 쓰려면 노드에 memo-mcp를 설치하되, **bootstrap과 같은
세션 정체성**을 갖게 래퍼로 실행해야 한다. 안 그러면 한 세션이 두 개 이름으로
등록됨 (MCP=고정이름, bootstrap=`<host>-<sid8>`).

1. `memo-service` repo에 venv 만들고 `pip install -e .` (memo-mcp 바이너리 생김).
2. 래퍼 스크립트(예: `~/.local/bin/memo-mcp-session`): 실행 시
   `COPILOT_AGENT_SESSION_ID`로 `MEMO_AGENT_NAME=<host>-<sid8>` 계산 후
   memo-mcp를 `exec`. bootstrap과 **동일 규칙**(hostname 소문자 + sid에서 대시
   제거 후 앞 8자)이어야 이름이 일치.
3. `~/.copilot/mcp-config.json`의 `command`를 래퍼로 지정하고,
   env엔 `MEMO_SERVICE_URL`만 두고 **고정 `MEMO_AGENT_NAME`은 넣지 말 것**
   (래퍼가 세션별로 설정). MCP는 세션 시작 때 로드되므로 변경 후 재시작.
4. 검증: bootstrap 로그의 이름과 `/agents`의 MCP 에이전트 이름이 동일한
   `<host>-<sid8>`인지. (bookone 레퍼런스 구현: `~/.local/bin/memo-mcp-session`.)

### Liveness / 종료

- 서버는 `AGENT_IDLE_TIMEOUT_MIN` (기본 10분) heartbeat 없으면 자동 offline + 열린
  activity 닫음.
- 장시간 작업/대기 전: `POST /agents/$MEMO_AGENT_NAME/heartbeat` (MCP `heartbeat`).
- 정상 종료 시 가능하면 `DELETE /agents/$MEMO_AGENT_NAME` (MCP `stop_agent`). 강제 종료/
  네트워크 drop은 timeout으로만 정리됨. shell trap 등으로 best-effort 호출 권장.
- 유령 에이전트가 쌓이면 `scripts/prune-memo-agents.sh` (기본 dry-run, `--apply`로 삭제).
  단 **online 상태로 쌓이는 중이면 prune은 대증요법**이다. 죽은 세션 대신 뭔가가
  heartbeat를 치고 있다는 뜻이므로 원인을 봐야 한다 (아래).
- **데스크톱 앱의 세션 ↔ 프로세스 모델 주의** (2026-08-05, 유령 168개 사고):
  - 앱은 모든 세션의 도구 호출을 **공용 `copilot --server --stdio` 프로세스 하나**
    아래에서 실행한다. 부모 체인을 거슬러 "copilot" 프로세스를 찾으면 세션별
    프로세스가 아니라 이 공용 서버가 잡힌다. 이건 앱이 살아있는 한 안 죽으므로
    **세션 수명의 프록시로 쓸 수 없다.** 과거 heartbeat 데몬이 이걸 `kill -0`으로
    감시해서 죽은 세션 몫으로 영원히 heartbeat를 쳤고, 161개가 누적돼
    **stale 감지가 통째로 무력화**됐다 (죽은 세션이 전부 online으로 보임).
  - 세션 수명 판단은 **활동 기록 기반**으로 한다. agentStop hook이 매 턴
    `act-{instance}` 파일을 touch하고, 데몬은 그 mtime이 `MEMO_HB_IDLE_EXIT_SEC`
    (기본 30분) 넘게 안 바뀌면 스스로 종료한다.
  - **hook은 `COPILOT_AGENT_SESSION_ID`를 물려받지 못한다.** 도구 호출 환경엔 있지만
    hook 환경엔 없어서, 전달 안 하면 `not-a-tty-<PPID>` fallback을 타고 호출마다
    새 에이전트가 생긴다(85개 누적). hook은 stdin JSON에서 세션 id를 읽어
    `COPILOT_AGENT_INSTANCE`로 export해서 넘길 것.
  - **payload 키는 `session_id` (snake_case)다.** `sessionId`로 읽으면 항상 빈 값이
    나오는데 아무 에러도 안 난다 — 그냥 조용히 fallback을 타서 유령이 계속
    생긴다. 실제 payload 예:
    `{"hook_event_name":"SessionStart","session_id":"...","cwd":"...","source":"resume"}`.
    스키마가 의심되면 `INPUT`을 파일로 덤프해서 눈으로 확인할 것 (추측 금지).
  - 데몬 kill 후 즉시 안 죽는 건 정상이다. `sleep 300` 중이면 bash가 trap을
    sleep 종료 후 처리하므로 최대 5분 걸린다.

### Inter-agent workflow

- **Ownership은 대상 노드에 있다.** 외부에서 받은 inbox 요청은 무조건 수락하지 말고,
  해당 노드 현황·정합성 검토 후 **수락 / 대안 / 거절** 중 결정.
- **메시지 발신** (MCP 우선):
  - `create_agent_memo` 또는 `POST /inbox` → 특정 agent/노드 hostname 앞으로
  - `reply_memo` 또는 `POST /inbox/{id}/reply` → 원 발신자에게 답글 (parent_id 자동)
  - `broadcast` 또는 `POST /announcements` → 다수에게 같은 요청. fan-out inbox 대신 권장
  - `reply_announcement` 또는 `POST /announcements/{id}/reply` → 공지 답글
- **claim**: node inbox 메시지를 처리하려면 `POST /inbox/{id}/claim`
  (`{"agent_name":"$MEMO_AGENT_NAME","expected_to_agent":"$MEMO_NODE_HOSTNAME"}`).
  409면 다른 agent가 먼저 가져간 것.
- **상태 갱신**: `PATCH /inbox/{id}` → `{"status":"done","result":"..."}`.
- **출처 식별**: `on_behalf_of` set ⇒ 사용자 대리 발신, null ⇒ agent 자율. 수신측은
  톤·우선순위·신뢰도를 다르게 처리할 수 있다.

### Activity tracking (선택)

- 의미 있는 작업 단위는 `start_activity` / `end_activity`로 기록.
- 한 agent당 동시 open 1개. 새 시작 시 이전 건 자동 close.

### Web UI

`https://memo.paryoja.com` 에 탭 UI (Inbox / Announcements / Nodes / Services / Agents /
Memos). 사용자에게 현황 보여줄 때 URL 공유 가능. announcement 행에서 답글 inline 확장.

## Daily Status Report (머신별)
- 모든 머신은 매일 23:00 (로컬) 자기 헬스 리포트를 Slack DM `C0AFD7AQ4QK`에 보낸다
- 셋업 확인: macOS `launchctl print "gui/$(id -u)/com.paryoja.system-health"`,
  Linux `crontab -l | grep -iE "system-health|status-report"`
- 셋업 안 됐고 사용자가 원하면 → `scripts/setup-status-report.sh` 실행 (자세한 건 `setup-status-report.md`)
- 셋업 후 `servers/{hostname}.md`의 "운영 메모" 섹션에 한 줄 기록
- 스크립트는 `scripts/system-health.py` 하나로 macOS/Linux/Synology 공용
  (`system-health-macos.py`는 구 LaunchAgent 호환용 shim)
