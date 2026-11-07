// 실제 사용자 로그 없이 집계 결과와 세션 경계를 검증합니다.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { execFileSync } = require('node:child_process');
const { mkdtempSync, writeFileSync, rmSync } = require('node:fs');
const { tmpdir } = require('node:os');
const { resolve, join } = require('node:path');
const script = resolve(__dirname, '../kpi.js');
const run = (dir) => execFileSync(process.execPath, [script, dir], { encoding: 'utf8' });

test('하위 폴더의 트랜스크립트는 중복 메시지를 제외하고 파일당 세션 1개로 집계한다', () => {
  assert.match(run(resolve(__dirname, 'fixtures')), /\| Claude \| 1 \| — \| 75\.0% \| 1 \| 1 \| — \|/);
});

test('헤드리스 JSON은 캐시 생성·읽기를 분모에 포함하고 Codex는 전체 입력을 사용한다', () => {
  const dir = mkdtempSync(join(tmpdir(), 'harness-kpi-'));
  try {
    writeFileSync(join(dir, 'headless.json'), JSON.stringify({
      type: 'result', session_id: 'synthetic-headless', total_cost_usd: 0.5,
      usage: { input_tokens: 10, cache_creation_input_tokens: 90, cache_read_input_tokens: 900 },
      permission_denials: []
    }, null, 2));
    writeFileSync(join(dir, 'codex.jsonl'), JSON.stringify({
      type: 'turn.completed', session_id: 'synthetic-codex', total_cost_usd: 0.2,
      usage: { input_tokens: 100, cached_input_tokens: 40 }
    }));
    const output = run(dir);
    assert.match(output, /\| Claude \| 1 \| \$0\.5000 \| 90\.0% \| — \| 0 \| — \|/);
    assert.match(output, /\| Codex \| 1 \| \$0\.2000 \| 40\.0% \| — \| — \| — \|/);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('stream-json 결과와 assistant 사용량은 이중 집계하지 않고 0 비용을 보존한다', () => {
  const dir = mkdtempSync(join(tmpdir(), 'harness-kpi-stream-'));
  try {
    writeFileSync(join(dir, 'stream.jsonl'), [
      { type: 'assistant', message: { id: 'synthetic-stream', usage: { input_tokens: 10, cache_read_input_tokens: 90 } } },
      { type: 'result', usage: { input_tokens: 20, cache_read_input_tokens: 80 }, total_cost_usd: 0 }
    ].map((item) => JSON.stringify(item)).join('\n'));
    assert.match(run(dir), /\| Claude \| 1 \| \$0\.0000 \| 80\.0% \| — \| — \| — \|/);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
