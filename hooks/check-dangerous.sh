#!/usr/bin/env bash
# 위험 명령과 보호 경로 변경을 차단합니다. Node 내장 모듈만 사용합니다.
set -euo pipefail

node --input-type=module -e '
import fs from "node:fs";

const input = fs.readFileSync(0, "utf8");
function block(reason) {
  console.error(`차단: ${reason}. 필요하다면 사람이 직접 실행하세요.`);
  process.exit(2);
}

// 기존 위험 명령 차단은 입력 전체에 그대로 적용합니다.
for (const pattern of ["rm -rf /", "rm -rf ~", "push --force", "push -f", "DROP TABLE"]) {
  if (input.includes(pattern)) block(`위험 명령 패턴 ${pattern}`);
}

let payload;
try { payload = JSON.parse(input); } catch { payload = { tool_input: { command: input } }; }
const tool = payload.tool_name || "";
const args = payload.tool_input || {};
const protectedPath = value => /(^|\/)_protected(\/|$)/.test(value);
if (["Edit", "Write", "MultiEdit"].includes(tool) && protectedPath(args.file_path || args.path || "")) {
  block("보호 경로 변경");
}
const command = args.command || "";

// 인용 문자열은 한 인수로 보존하고, 파이프·연결 명령·리다이렉션을 구분합니다.
// 셸을 실행하거나 변수·별칭·심볼릭 링크를 해석하는 보안 샌드박스는 아닙니다.
const lexemes = command.match(/(?:[^\s"\x27\\;&|()<>]+|\\[\s\S]|"(?:\\[\s\S]|[^"\\])*"|\x27[^\x27]*\x27)+|>>|>\||>|<<|<|&&|\|\||[;&|()\n]/g) || [];
const unquote = value => value.replace(/"((?:\\[\s\S]|[^"\\])*)"|\x27([^\x27]*)\x27|\\([\s\S])/g,
  (_, double, single, escaped) => double !== undefined ? double.replace(/\\(["\\$`])/g, "$1") : single ?? escaped);
const basename = value => value.split("/").pop();

function checkCommand(words) {
  while (words.length && (/^[A-Za-z_][A-Za-z_0-9]*=/.test(words[0]) ||
    ["sudo", "env", "command", "builtin", "exec"].includes(basename(words[0])))) words.shift();
  const name = basename(words.shift() || "");
  if (["rm", "mv", "tee", "chmod", "chown", "chgrp", "truncate", "touch", "mkdir", "rmdir", "unlink", "install"].includes(name)) {
    if (words.some(protectedPath)) block("보호 경로 쓰기·삭제·이동");
  }
  if (name === "cp") {
    const targetOption = words.findIndex(word => word === "-t" || word === "--target-directory");
    const targetEquals = words.find(word => word.startsWith("--target-directory="));
    const target = targetOption >= 0 ? words[targetOption + 1] :
      targetEquals ? targetEquals.slice(targetEquals.indexOf("=") + 1) : words.filter(word => !word.startsWith("-")).at(-1);
    if (protectedPath(target || "")) block("보호 경로로 복사");
  }
  if (name === "sed" && words.some(word => /^--in-place(?:=|$)|^-[^-]*i/.test(word))) {
    let hasScript = false;
    for (let index = 0; index < words.length; index++) {
      const word = words[index];
      if (["-e", "--expression", "-f", "--file"].includes(word)) { hasScript = true; index++; continue; }
      if (/^--(?:expression|file)=|^-[ef].+/.test(word)) { hasScript = true; continue; }
      if (word.startsWith("-") || (word === "" && words[index - 1] === "-i")) continue;
      if (!hasScript) { hasScript = true; continue; }
      if (protectedPath(word)) block("보호 경로 제자리 편집");
    }
  }
}

let words = [];
let comment = false;
for (let index = 0; index < lexemes.length; index++) {
  const token = lexemes[index];
  if (token === "\n") comment = false;
  if (comment) continue;
  if (token.startsWith("#")) { comment = true; continue; }
  if (/^(?:>>|>\||>|<<|<)$/.test(token)) {
    if (/^\d+$/.test(words.at(-1) || "")) words.pop();
    const target = unquote(lexemes[++index] || "");
    if (token.startsWith(">") && protectedPath(target)) block("보호 경로 출력 리다이렉션");
  } else if (/^(?:&&|\|\||[;&|()\n])$/.test(token)) {
    checkCommand(words);
    words = [];
  } else {
    words.push(unquote(token));
  }
}
checkCommand(words);
'
