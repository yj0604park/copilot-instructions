# GitHub Copilot CLI 기능 총정리

## 1. 슬래시 명령어 (Slash Commands)

### 기본
| 명령어 | 설명 |
|---|---|
| `/help` | 전체 도움말 |
| `/clear` | 세션 초기화 |
| `/exit` | CLI 종료 |
| `/version` | 버전 확인 |
| `/update` | 최신 버전 업데이트 |
| `/feedback` | 피드백 제출 |
| `/login` / `/logout` | GitHub 인증 |
| `/changelog` | 변경 이력 (+ `summarize`로 AI 요약) |

### 모델 & 에이전트
| 명령어 | 설명 |
|---|---|
| `/model` | AI 모델 선택 (Sonnet, GPT-5 등) |
| `/agent` | 커스텀 에이전트 선택 |
| `/fleet` | 병렬 서브에이전트 모드 |
| `/tasks` | 서브에이전트/셸 작업 관리 |
| `/autopilot` | 자동 실행 모드 토글 |
| `/delegate` | GitHub에 세션 전송 → PR 자동 생성 |

### 코드 & 리뷰
| 명령어 | 설명 |
|---|---|
| `/diff` | 현재 디렉토리 변경사항 리뷰 |
| `/pr` | 현재 브랜치 PR 작업 |
| `/review` | 코드 리뷰 에이전트 실행 |
| `/plan` | 코딩 전 구현 계획 수립 |
| `/lsp` | LSP 서버 관리 (코드 인텔리전스) |
| `/ide` | IDE 워크스페이스 연결 |

### 세션 관리
| 명령어 | 설명 |
|---|---|
| `/resume` | 이전 세션 이어서 작업 |
| `/rename` | 세션 이름 변경 |
| `/compact` | 대화 압축 (컨텍스트 절약) |
| `/context` | 토큰 사용량 시각화 |
| `/usage` | 세션 통계 (프리미엄 요청 수, 토큰 등) |
| `/share` | 세션을 마크다운/HTML/Gist로 공유 |
| `/rewind` / `/undo` | 마지막 턴 되돌리기 + 파일 복원 |
| `/copy` | 마지막 응답 클립보드 복사 |
| `/search` | 대화 타임라인 검색 |
| `/remote` | GitHub 웹/모바일에서 원격 제어 토글 |

### 권한 관리
| 명령어 | 설명 |
|---|---|
| `/allow-all` | 모든 권한 활성화 |
| `/add-dir` | 파일 접근 허용 디렉토리 추가 |
| `/list-dirs` | 허용된 디렉토리 목록 표시 |
| `/cwd` | 작업 디렉토리 변경 |
| `/reset-allowed-tools` | 허용 도구 목록 초기화 |

### 스케줄 & 기타
| 명령어 | 설명 |
|---|---|
| `/every` | 반복 예약 (예: `/every 5m run tests`) |
| `/after` | 일회성 예약 (예: `/after 30s ping me`) |
| `/ask` | 대화 기록에 안 남는 사이드 질문 |
| `/research` | 딥 리서치 (GitHub + 웹 검색) |
| `/keep-alive` | 시스템 슬립 방지 |
| `/experimental` | 실험 기능 활성화 |
| `/theme` | 컬러 모드 설정 |
| `/statusline` / `/footer` | 상태줄 설정 |
| `/streamer-mode` | 스트리머 모드 (모델명/할당량 숨김) |
| `/terminal-setup` | 멀티라인 입력 설정 (Shift+Enter) |
| `/chronicle` | 세션 히스토리 도구 |

---

## 2. 키보드 단축키

| 키 | 기능 |
|---|---|
| `Shift+Tab` | 모드 전환 (Suggest → Edit → Autopilot) |
| `Ctrl+S` | 명령 실행, 입력 유지 |
| `Ctrl+O` / `Ctrl+E` | 타임라인 전체 펼치기 |
| `Ctrl+C` | 취소 (2번 누르면 종료) |
| `Ctrl+D` | 종료 |
| `Ctrl+L` | 화면 클리어 |
| `Ctrl+T` | 추론 과정 표시 토글 |
| `Ctrl+X → B` | 현재 작업 백그라운드로 이동 |
| `Ctrl+X → O` | 최근 링크 열기 |
| `Ctrl+G` | 외부 에디터($EDITOR)에서 프롬프트 편집 |
| `Ctrl+A` / `Ctrl+E` | 줄 시작/끝 이동 |
| `Ctrl+W` | 이전 단어 삭제 |
| `Ctrl+U` | 커서~줄 시작 삭제 |
| `Ctrl+K` | 커서~줄 끝 삭제 |
| `Meta+←/→` | 단어 단위 이동 |
| `Esc` | 취소 |

---

## 3. 프롬프트 특수 문법

| 문법 | 기능 | 예시 |
|---|---|---|
| `@파일경로` | 파일을 컨텍스트에 추가 | `@src/app.js의 버그 수정해줘` |
| `#번호` | GitHub 이슈/PR 참조 | `#42 이슈 해결해줘` |
| `!명령어` | 셸 명령어 즉시 실행 | `!git status` |
| `/스킬명` | 특정 스킬 호출 | `/frontend-design 네비게이션 바 만들어` |

---

## 4. 커스터마이징 기능 비교

### Custom Instructions (커스텀 지시사항)
- **목적**: Copilot이 항상 따르는 기본 행동 규칙
- **사용 예**: 코딩 컨벤션, 언어 설정, 응답 스타일
- **위치**:
  - `~/.copilot/copilot-instructions.md` (글로벌)
  - `.github/copilot-instructions.md` (저장소)
  - `.github/instructions/**/*.instructions.md` (경로별)
  - `AGENTS.md` / `CLAUDE.md` / `GEMINI.md` (저장소 루트)

### Skills (스킬)
- **목적**: 특정 작업에만 적용되는 전문 지시 + 스크립트
- **사용 예**: GitHub Actions 디버깅, SVG→PNG 변환, 문서 검사
- **위치**:
  - `~/.copilot/skills/스킬명/SKILL.md` (개인)
  - `.github/skills/스킬명/SKILL.md` (저장소)
- **구조 예시**:
  ```
  .github/skills/github-actions-debugging/
  ├── SKILL.md          # 이름, 설명, 지시사항
  └── debug-script.sh   # 선택적 스크립트
  ```
- **SKILL.md 예시**:
  ```markdown
  ---
  name: github-actions-failure-debugging
  description: GitHub Actions 실패 디버깅 가이드
  allowed-tools: shell
  ---
  1. list_workflow_runs로 실패한 워크플로우 확인
  2. summarize_job_log_failures로 실패 로그 요약
  3. 실패 재현 후 수정
  ```
- **명령어**: `/skills list`, `/skills info`, `/skills reload`, `/skills add`, `/skills remove`
- **외부 스킬**: [awesome-copilot.github.com/skills](https://awesome-copilot.github.com/skills/)에서 다운로드 가능

### MCP Servers
- **목적**: 외부 서비스 연결 (추가 도구 제공)
- **기본 제공**: GitHub MCP Server (PR 머지, 이슈 관리 등)
- **추가 방법**: `/mcp add`
- **설정 파일**: `~/.copilot/mcp-config.json`
- **사용 예**: 캘린더 앱, 지원 티켓 시스템, DB 등 연동

### Hooks (훅)
- **목적**: 세션 생명주기의 특정 시점에 자동 실행되는 셸 명령
- **종류**:
  | Hook | 실행 시점 |
  |---|---|
  | `sessionStart` / `sessionEnd` | 세션 시작/종료 |
  | `preToolUse` / `postToolUse` | 도구 사용 전/후 |
  | `userPromptSubmitted` | 프롬프트 제출 시 |
  | `errorOccurred` | 에러 발생 시 |
  | `agentStop` | 에이전트 정지 시 |
  | `subagentStop` | 서브에이전트 완료 시 |
- **사용 예**: 보호 경로 편집 차단, 세션 로그 저장, 에러 시 자동 재시도

### Custom Agents (커스텀 에이전트)
- **목적**: 특정 역할의 전문가 페르소나 정의
- **내장 에이전트**: explore, task, research, code-review, rubber-duck, general-purpose
- **위치**:
  - `~/.copilot/agents/` (개인)
  - `.github/agents/` (저장소)
  - `.github-private` 저장소의 `/agents/` (조직)
- **사용 방법**: `/agent` 명령 또는 `copilot --agent=에이전트명`
- **사용 예**: react-reviewer, docs-writer, security-auditor

### Plugins (플러그인)
- **목적**: 스킬, 훅, 커스텀 에이전트, MCP 서버를 묶어 배포하는 패키지
- **관리**: `/plugin` 명령

---

## 5. LSP (Language Server Protocol) 설정

코드 인텔리전스 (go-to-definition, hover 등) 지원.

- **설정 파일**:
  - `~/.copilot/lsp-config.json` (글로벌)
  - `.github/lsp.json` (저장소)
- **예시**:
  ```json
  {
    "lspServers": {
      "typescript": {
        "command": "typescript-language-server",
        "args": ["--stdio"],
        "fileExtensions": {
          ".ts": "typescript",
          ".tsx": "typescript"
        }
      }
    }
  }
  ```

---

## 6. CLI 실행 옵션

| 옵션 | 설명 |
|---|---|
| `copilot --resume` | 이전 세션 이어서 |
| `copilot --continue` | 가장 최근 세션 이어서 |
| `copilot --agent=이름` | 특정 에이전트로 시작 |
| `copilot --prompt "..."` | 프롬프트 직접 전달 |
| `copilot --allow-all` / `--yolo` | 모든 권한 허용 |
| `copilot --experimental` | 실험 기능 활성화 |
| `copilot --banner` | 배너 다시 표시 |
| `copilot --no-custom-instructions` | 커스텀 지시사항 무시 |

---

## 7. 설정 파일 위치 (`~/.copilot/`)

| 파일 | 역할 |
|---|---|
| `copilot-instructions.md` | 글로벌 커스텀 지시사항 |
| `settings.json` | 로그레벨, URL 허용 등 설정 |
| `config.json` | 인증 등 기본 설정 |
| `mcp-config.json` | MCP 서버 설정 |
| `lsp-config.json` | LSP 서버 설정 |
| `permissions-config.json` | 도구 권한 설정 |
| `agents/` | 개인 커스텀 에이전트 |
| `skills/` | 개인 스킬 |
| `hooks/` | 훅 스크립트 |
| `session-state/` | 세션 상태 저장 |
