#!/usr/bin/env python3
import sys, json, subprocess, os

d = json.loads(sys.stdin.read())
folder = d.get('cwd', '').rsplit('/', 1)[-1] or 'unknown'
session_id = d.get('sessionId', '')

snippet = '작업 완료'

# events.jsonl 경로 추정
events_path = os.path.expanduser(f'~/.copilot/session-state/{session_id}/events.jsonl')
if os.path.exists(events_path):
    try:
        last_content = ''
        with open(events_path) as f:
            for line in f:
                e = json.loads(line)
                if e.get('type') == 'assistant.message':
                    c = e.get('data', {}).get('content', '')
                    if c:
                        last_content = c
        if last_content:
            # 줄바꿈 제거, 80자 제한
            snippet = last_content.replace('\n', ' ').strip()[:80]
    except:
        pass

title = f'Copilot [{folder}]'
# 따옴표 이스케이프
snippet = snippet.replace('"', '\\"')
title = title.replace('"', '\\"')

subprocess.run([
    'osascript', '-e',
    f'display notification "{snippet}" with title "{title}" sound name "Funk"'
])
