#!/usr/bin/env bash
# 도구 실행 결과에서 명령 메타데이터만 내부 기록으로 남깁니다.
set -euo pipefail

mkdir -p .harness-logs
node -e '
let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{
  let r={};try{const x=JSON.parse(s);const i=x.tool_input??x.input??{};
    r={시각:new Date().toISOString(),도구:x.tool_name??x.tool??"미상",명령:i.command??i.cmd??""};
  }catch{r={시각:new Date().toISOString(),도구:"미상",명령:"파싱 실패"};}
  process.stdout.write(JSON.stringify(r)+"\n");
});' >> .harness-logs/commands.jsonl

