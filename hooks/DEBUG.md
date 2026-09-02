# Hook 디버깅 가이드

## 1. hook에 디버그 로그 추가

`notify.sh` 상단에 임시로 추가:

```bash
INPUT=$(cat)
echo "$(date): INPUT=$INPUT" >> /tmp/copilot-hook-debug.log
```

파싱 중간값도 로깅:

```bash
echo "$(date): SESSION_ID=$SESSION_ID" >> /tmp/copilot-hook-debug.log
echo "$(date): EVENTS_FILE=$EVENTS_FILE" >> /tmp/copilot-hook-debug.log
echo "$(date): LAST_MSG=$LAST_MSG" >> /tmp/copilot-hook-debug.log
echo "$(date): SUMMARY=$SUMMARY" >> /tmp/copilot-hook-debug.log
```

## 2. events.jsonl 직접 확인

```bash
# 세션 ID 확인
ls ~/.copilot/session-state/

# 이벤트 타입 분포
jq -c '.type' ~/.copilot/session-state/{SESSION_ID}/events.jsonl | sort | uniq -c

# 마지막 assistant 메시지 확인
grep '"assistant.message"' ~/.copilot/session-state/{SESSION_ID}/events.jsonl \
  | tail -1 \
  | jq -r '.data.content'

# 특수문자/줄바꿈 확인 (cat -v로 제어문자 표시)
grep '"assistant.message"' ~/.copilot/session-state/{SESSION_ID}/events.jsonl \
  | tail -1 \
  | jq -r '.data.content' \
  | cat -v
```

## 3. agentStop hook 입력 페이로드 구조

```json
{
  "timestamp": 1778914021549,
  "cwd": "/Users/yoonjaepark/services",
  "session_id": "9d298a3f-...",
  "transcriptPath": "",       // 비어있을 수 있음!
  "stopReason": "end_turn"
}
```

- 키는 **snake_case (`session_id`)**다. `sessionId`로 읽으면 에러 없이 빈 값이
  나와서 조용히 fallback을 탄다. 스크립트는 `.session_id // .sessionId // empty`로
  읽어 버전에 따라 스키마가 다를 경우의 camelCase도 함께 받는다.
- `transcriptPath`는 빈 문자열일 수 있으므로 `session_id`로 직접 경로 구성
- 경로: `~/.copilot/session-state/{session_id}/events.jsonl`

## 4. 흔한 문제

| 증상 | 원인 | 해결 |
|------|------|------|
| `(null)` 표시 | 메시지에 줄바꿈 포함 → OSC 9 시퀀스 깨짐 | `tr '\n' ' '` |
| 이전 턴 메시지 표시 | hook이 현재 턴 기록 전에 실행 | `sleep 1` 추가 |
| Bell 알림 | OSC 9의 `\a`(BEL)이 tmux에서 bell로 처리 | tmux `bell-action none` |
| 알림 중복 | 모든 tmux pane에 전송 | `$TMUX_PANE`으로 현재 pane만 |
| 알림 안 옴 | symlink 깨짐 or 스크립트 실행 권한 없음 | `ls -la`, `chmod +x` 확인 |

## 5. 디버깅 끝나면 정리

```bash
rm /tmp/copilot-hook-debug.log
```
