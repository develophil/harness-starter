#!/usr/bin/env bash
# Claude 상태줄 JSON에서 토큰과 캐시를 한 줄로 표시하는 예시입니다.
# ⚠️ 미확인: Codex 상태줄 입력 규약은 확정 전이므로 이 예시는 Claude 입력만 대상으로 합니다.
set -euo pipefail

node -e '
let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{
  let x={};try{x=JSON.parse(s)}catch{}
  const u=x.current_usage??{};
  const input=u.input_tokens??0, cache=u.cache_read_input_tokens??x.prompt_cache?.cache_read_input_tokens??0;
  const rate=input?`${(100*cache/input).toFixed(1)}%`:"—";
  process.stdout.write(`입력 ${input} · 캐시 ${rate}`);
});'

