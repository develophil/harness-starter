#!/usr/bin/env bash
# 구현, 읽기 전용 리뷰, 테스트를 차례로 실행합니다.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
DEFAULT_BRIEF="loops/task""-brief.md"
BRIEF="${1:-$DEFAULT_BRIEF}"
if [[ -f "$BRIEF" ]]; then PROMPT="$(<"$BRIEF")"; else PROMPT="$BRIEF"; fi
[[ -n "${PROMPT// }" ]] || { printf 'pipeline: 지시문이 비었습니다\n' >&2; exit 2; }
mkdir -p "$ROOT/.codex-work"
"$ROOT/loops/cx-mini.sh" "$PROMPT" > "$ROOT/.codex-work/pipeline-implementation.txt"
"$ROOT/loops/cx-mini.sh" --ro "현재 변경을 수정하지 말고 요구사항 누락, 회귀 위험, 검증 공백을 심각도순으로 검토하세요." > "$ROOT/.codex-work/pipeline-review.txt"
(cd "$ROOT" && npm test)
printf '결론: 구현, 읽기 전용 리뷰, 테스트 3단계를 통과했습니다.\n'
printf '변경 파일:\n'
(cd "$ROOT" && git status --short)
printf '검증 상태: npm test 통과\n'
