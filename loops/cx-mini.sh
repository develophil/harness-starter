#!/usr/bin/env bash
# 지휘자에서 Codex 실행자로 넘기는 최소 래퍼입니다.
set -euo pipefail

SANDBOX="workspace-write"; RESUME=""
while (($#)); do
  case "$1" in
    -r) RESUME="$(cat .codex-work/.last-thread 2>/dev/null || true)"; shift ;;
    --ro) SANDBOX="read-only"; shift ;;
    *) break ;;
  esac
done
PROMPT="${*:-$(cat)}"
[[ -n "${PROMPT// }" ]] || { printf 'cx-mini: 지시문이 비었습니다\n' >&2; exit 2; }
mkdir -p .codex-work
TMP_DIR="$(mktemp -d)"; trap 'rm -rf "$TMP_DIR"' EXIT
ARGS=(exec --skip-git-repo-check -s "$SANDBOX" --json -o "$TMP_DIR/final.txt")
if [[ -n "$RESUME" ]]; then ARGS+=(resume "$RESUME"); fi
ARGS+=("$PROMPT")
printf 'cx-mini: [%s] %s\n' "$SANDBOX" "$PWD" >&2
START="$(date +%s)"
if codex "${ARGS[@]}" </dev/null 2>"$TMP_DIR/error.log" | tee "$TMP_DIR/events.jsonl" | jq -r '
  if .type=="thread.started" then "· 세션 \(.thread_id)"
  elif .type=="item.completed" and .item.type=="file_change" then "· 파일 변경"
  elif .type=="item.completed" and .item.type=="command_execution" then "· 명령 실행"
  elif .type=="turn.completed" then "· 입력 \(.usage.input_tokens), 캐시 \(.usage.cached_input_tokens), 출력 \(.usage.output_tokens)"
  elif .type=="error" then "! 오류: \(.message // (.|tostring))" else empty end' >&2; then STATUS=0; else STATUS=$?; fi
THREAD="$(jq -r 'select(.type=="thread.started")|.thread_id' "$TMP_DIR/events.jsonl" 2>/dev/null | head -1 || true)"
[[ -z "$THREAD" ]] || printf '%s' "$THREAD" > .codex-work/.last-thread
FINAL="$(cat "$TMP_DIR/final.txt" 2>/dev/null || true)"
{
  printf '\n## %s — cx-mini (%s, %s초) 세션 %s\n\n' "$(date +%T)" "$SANDBOX" "$(( $(date +%s) - START ))" "${THREAD:-?}"
  printf '%s\n' "$PROMPT" | sed 's/^/> /'; printf '\n%s\n' "${FINAL:-(응답 없음)}"
} >> ".codex-work/$(date +%F).md"
(( STATUS == 0 )) || { tail -20 "$TMP_DIR/error.log" >&2; exit "$STATUS"; }
[[ -n "${FINAL// }" ]] || { printf 'cx-mini: 최종 응답이 없습니다\n' >&2; exit 1; }
printf '%s\n' "$FINAL"

