#!/usr/bin/env bash
# 종료 전 테스트를 강제하고 5회 뒤 사람에게 넘깁니다.
# 규약(2026-10 문서): Claude·Codex 모두 {"decision":"block","reason"} 또는 exit 2 + stderr로 계속시킨다.
# Codex Stop 훅은 exit 0일 때 stdout이 JSON이어야 한다(평문 무효) — 그래서 stdout에는 JSON만 쓰고 진단은 stderr로.
# Codex는 .codex/hooks.json 등록 후 /hooks에서 신뢰 승인해야 실행된다.
set -euo pipefail

GATE_PATHS="${GATE_PATHS:-src tests}" # 공백으로 구분한 테스트 대상 경로
TEST_COMMAND="${HARNESS_TEST_COMMAND:-npm test}"
CODEX_MODE="${CODEX_MODE:-0}"
STATE_FILE="${HARNESS_STOP_STATE:-.harness-state/stop-gate.count}"
read -r -a CHECK_PATHS <<< "$GATE_PATHS"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1 &&
   git diff --quiet HEAD -- "${CHECK_PATHS[@]}" &&
   [[ -z "$(git ls-files --others --exclude-standard -- "${CHECK_PATHS[@]}")" ]]; then
  rm -f "$STATE_FILE"
  printf '%s\n' '{"systemMessage":"stop-gate: 대상 코드 변경 없음 — 테스트 생략, 종료 허용"}'
  exit 0
fi
mkdir -p "$(dirname "$STATE_FILE")"
COUNT=$(( $(cat "$STATE_FILE" 2>/dev/null || printf '0') + 1 ))
printf '%s\n' "$COUNT" > "$STATE_FILE"

if (( COUNT > 5 )); then
  rm -f "$STATE_FILE"
  printf '%s\n' '{"systemMessage":"stop-gate: 5회 초과 — 현재 상태와 시도 내역을 사람에게 보고하세요."}'
  exit 0
fi

if OUTPUT="$(bash -lc "$TEST_COMMAND" 2>&1)"; then
  rm -f "$STATE_FILE"
  printf '%s\n' '{"systemMessage":"stop-gate: 테스트 통과 — 종료 허용"}'
  exit 0
fi

printf 'stop-gate: 테스트 실패 (%s/5회)\n%s\n' "$COUNT" "$OUTPUT" >&2
if [[ "$CODEX_MODE" == "1" ]]; then
  exit 2
fi
printf '{"decision":"block","reason":"stop-gate: 테스트 실패 (%s/5회). 계속 수정하세요."}\n' "$COUNT"

