# 공용 훅

- `check-dangerous.sh`: 강제 푸시, 루트 삭제, 보호 경로처럼 되돌리기 어려운 명령을 exit 2로 차단합니다.
- `log-commands.sh`: 실행한 도구와 명령 메타데이터를 `.harness-logs/commands.jsonl`에 남깁니다. 원문 전체는 저장하지 않습니다.

Claude Code는 `.claude/settings.json`의 `PreToolUse`·`PostToolUse`, Codex는 `.codex/hooks.json`의 같은 이벤트에 등록하고 대화형 `/hooks`에서 **신뢰 승인**해야 실행됩니다(정의를 바꾸면 재승인). Gemini 등록 스키마는 아래 미확인 항목을 해소한 뒤 팀 설정에 추가합니다.

# 버전 확인: Gemini 훅 등록 위치와 이벤트 스키마는 설치 버전에서 재검증합니다.

