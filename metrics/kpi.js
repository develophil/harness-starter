#!/usr/bin/env node
// JSON 결과와 JSONL 트랜스크립트를 재귀 탐색해 Claude·Codex KPI를 집계합니다.
const { readdirSync, readFileSync, statSync } = require('node:fs');
const { resolve } = require('node:path');

const inputDir = process.argv[2];
if (!inputDir) {
  console.error('사용: node metrics/kpi.js SESSION_JSON_DIR');
  process.exit(2);
}
const dir = resolve(inputDir);
if (!statSync(dir).isDirectory()) throw new Error(`디렉터리가 아닙니다: ${inputDir}`);

const numberOrNull = (value) => value != null && value !== '' && Number.isFinite(Number(value)) ? Number(value) : null;
const sum = (items, key) => items.reduce((total, item) => total + (item[key] ?? 0), 0);
const optionalSum = (items, key) => items.some((item) => item[key] != null) ? sum(items, key) : null;

function* sessionFiles(directory) {
  for (const entry of readdirSync(directory, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
    const file = resolve(directory, entry.name);
    if (entry.isDirectory()) yield* sessionFiles(file);
    else if (entry.isFile() && /\.jsonl?$/.test(entry.name)) yield file;
  }
}

function readRecords(file) {
  const content = readFileSync(file, 'utf8');
  if (file.endsWith('.json')) {
    const item = JSON.parse(content);
    return Array.isArray(item) ? item : [item];
  }
  return content.split('\n').flatMap((line, index) => {
    if (!line.trim()) return [];
    try { return [JSON.parse(line)]; }
    catch { throw new Error(`${file}:${index + 1} JSON 파싱 실패`); }
  });
}

function rowFor(item, isCodex = false) {
  const usage = item.usage || {};
  const input = numberOrNull(item.input_tokens ?? usage.input_tokens) ?? 0;
  const cached = numberOrNull(item.cache_read_tokens ?? usage.cache_read_input_tokens ?? usage.cached_input_tokens) ?? 0;
  const created = numberOrNull(item.cache_creation_input_tokens ?? usage.cache_creation_input_tokens) ?? 0;
  // Codex와 기존 가상 로그의 cache_read_tokens는 전체 input_tokens에 이미 포함됩니다.
  const totalInput = isCodex || item.cache_read_tokens != null ? input : input + created + cached;
  return {
    tool: isCodex ? 'Codex' : 'Claude', input: totalInput, cached,
    cost: numberOrNull(item.total_cost_usd ?? usage.total_cost_usd),
    loops: numberOrNull(item.loop_retries ?? item.loop_iterations),
    human: numberOrNull(item.human_interventions ?? item.permission_requests) ??
      (Array.isArray(item.permission_denials) ? item.permission_denials.length : null),
    reverts: numberOrNull(item.reverts ?? item.rollback_count)
  };
}

const rows = [];
for (const file of sessionFiles(dir)) {
  const records = readRecords(file).filter((item) => item && typeof item === 'object');
  const results = records.filter((item) => item.type !== 'assistant' && item.type !== 'turn.completed' &&
    (item.session_id || item.total_cost_usd != null || item.type === 'result') &&
    (item.input_tokens != null || item.usage?.input_tokens != null));
  // stream-json에 결과 행이 있으면 assistant 행과 이중 집계하지 않습니다.
  if (results.length) {
    rows.push(...results.map((item) => rowFor(item)));
  } else {
    const messages = new Map();
    for (const [index, item] of records.entries()) {
      if (item.type !== 'assistant' || !item.message?.usage) continue;
      const key = item.message.id ?? item.uuid ?? index;
      const previous = messages.get(key) || {};
      const usage = item.message.usage;
      // 같은 message.id의 여러 블록·중간 usage는 카운터별 최대값으로 한 번만 셉니다.
      const merged = {};
      for (const name of ['input_tokens', 'cache_creation_input_tokens', 'cache_read_input_tokens', 'total_cost_usd']) {
        const values = [previous[name], usage[name]].map(numberOrNull).filter((value) => value != null);
        merged[name] = values.length ? Math.max(...values) : null;
      }
      messages.set(key, merged);
    }
    if (messages.size) {
      const calls = [...messages.values()].map((usage) => rowFor({ usage }));
      const stops = records.filter((item) => item.subtype === 'stop_hook_summary' || item.type === 'stop_hook_summary');
      const denials = records.filter((item) => Array.isArray(item.permission_denials));
      rows.push({
        tool: 'Claude', input: sum(calls, 'input'), cached: sum(calls, 'cached'),
        cost: optionalSum(calls, 'cost'),
        loops: stops.length ? stops.filter((item) => item.hookErrors?.length > 0).length : null,
        human: denials.length ? denials.reduce((total, item) => total + item.permission_denials.length, 0) : null,
        reverts: null
      });
    }
  }
  rows.push(...records.filter((item) => item.type === 'turn.completed' && item.usage).map((item) => rowFor(item, true)));
}

const display = (value, format = String) => value == null ? '—' : format(value);
const percent = (part, total) => total ? `${(100 * part / total).toFixed(1)}%` : '—';
const money = (value) => `$${value.toFixed(4)}`;
const tools = ['Claude', 'Codex'].filter((tool) => rows.some((row) => row.tool === tool));

console.log('| 도구 | 작업 수 | 작업단위당 비용 | 캐시 히트율 | 루프 반복 수 | 사람 개입 횟수 | 되돌림 횟수 |');
console.log('|---|---:|---:|---:|---:|---:|---:|');
for (const tool of tools) {
  const items = rows.filter((row) => row.tool === tool);
  const costs = items.filter((item) => item.cost != null);
  const unitCost = costs.length ? sum(costs, 'cost') / costs.length : null;
  console.log(`| ${tool} | ${items.length} | ${display(unitCost, money)} | ${percent(sum(items, 'cached'), sum(items, 'input'))} | ${display(optionalSum(items, 'loops'))} | ${display(optionalSum(items, 'human'))} | ${display(optionalSum(items, 'reverts'))} |`);
}
if (!rows.length) console.error('집계 가능한 Claude 또는 Codex 레코드가 없습니다.');
