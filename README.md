# 팀 하네스 스타터 키트

> 블로그 연재 「AI 업무 활용 로드맵」 고급·하네스 편의 실습 스타터입니다 — https://androphil.tistory.com/category/AI%20%EC%97%85%EB%AC%B4%20%ED%99%9C%EC%9A%A9%20%EB%A1%9C%EB%93%9C%EB%A7%B5
> 2026년 11월 기계 리허설로 확인한 함정(폴더 신뢰, Stop 게이트 범위, 위험 명령 훅 오탐)은 이 판에 반영돼 있습니다. MIT 라이선스.

공용 지침, 가드레일, 작업 루프, 권한 프로필, 스킬 평가, KPI를 한 번에 옮기는 공개 템플릿입니다.
공용 규칙은 `AGENTS.md`에 두고 도구별 디렉터리는 얇은 어댑터로 유지합니다.
적용 전 `<your-org>`, `<repo>`, `${API_KEY}` 자리표시자와 테스트 명령을 팀 환경에 맞게 바꾸세요.

## 5분 적용

1. 미리 보기: `scripts/apply.sh ../project --layer all --profile explore --dry-run`
2. 적용: `scripts/apply.sh ../project --layer all --profile explore --yes`
3. 대상의 `AGENTS.md`, `.claude/settings.json`, `.codex/config.toml`을 검토합니다.
4. `.harness/profiles/explore/`의 세 조각을 읽고 기존 설정에 **수동 병합**합니다. 조각은 자동 활성화되지 않습니다.
5. 적용 후 대상 폴더에서 `claude`를 한 번 **대화형으로 열어 폴더 신뢰를 승인**합니다. 미신뢰 폴더에서는 프로젝트 `permissions.allow`가 무시됩니다. 훅·deny가 실행되어도 allow 적용을 뜻하지는 않습니다.
6. 대상에서 `bash -n hooks/*.sh loops/*.sh metrics/*.sh`와 프로젝트 테스트를 실행합니다.

### build 프로필과 Stop 게이트 활성화

`scripts/apply.sh ../project --layer all --profile build --yes`는 구현 프로필을 복사합니다. 기존 설정을 검토한 뒤 병합하는 설계이므로 이 명령만으로 Stop 게이트가 켜지지는 않습니다. 대상 폴더에서 아래 명령으로 build의 허용·차단 규칙과 Stop 훅을 병합합니다(`jq` 필요). 기존 규칙과 다른 이벤트의 훅은 보존합니다.

```bash
cd ../project
jq --slurpfile build .harness/profiles/build/claude.settings.json '
  .permissions.allow = ((.permissions.allow // []) + $build[0].permissions.allow | unique) |
  .permissions.deny = ((.permissions.deny // []) + $build[0].permissions.deny | unique) |
  .hooks.Stop = ((.hooks.Stop // []) + $build[0].hooks.Stop | unique)
' .claude/settings.json > .claude/settings.merged.json &&
  mv .claude/settings.merged.json .claude/settings.json
jq -e '.hooks.Stop[] .hooks[] | select(.command == "bash loops/stop-gate.sh")' .claude/settings.json
```

`HARNESS_TEST_COMMAND`(기본 `npm test`)를 대상 프로젝트에 맞게 정한 뒤 위 5번의 폴더 신뢰 승인을 마칩니다. `--layer profiles`만 적용했다면 `--layer loops`도 적용해야 Stop 훅이 실행할 파일이 생깁니다.

build의 `Bash(npm test:*)`, `Bash(node --check:*)`, `Bash(npx vitest:*)`는 단독 명령과 인수를 포함한 접두 매칭입니다. `head`·`tail` 규칙도 포함하므로 `npm test | tail -5`, `node --check src/index.js && npm test`를 구성하는 명령이 각각 허용됩니다. 임의의 뒤 명령까지 허용하지는 않습니다. 위험 명령 deny는 계속 우선합니다. [공식 권한 문법](https://code.claude.com/docs/en/permissions#compound-commands)에서 `:*`와 ` *`의 동등성 및 복합 명령의 구성 요소별 판정을 확인할 수 있습니다(2026-11-07 확인).

## 도구별 선택

- Claude Code: `AGENTS.md`, `CLAUDE.md`, `.claude/`, `hooks/`를 사용합니다.
- Codex CLI: `AGENTS.md`, `.codex/`, `.agents/skills/`를 사용합니다. 공용 `skills/`도 함께 보존됩니다.
- Gemini CLI: `AGENTS.md`, `GEMINI.md`, `.gemini/`를 사용하되 미확인 표시를 먼저 재검증합니다.

레이어만 적용하려면 `--layer core|loops|profiles|evals|metrics`, 구현 프로필은 `--profile build`를 사용합니다. 기존 파일은 기본적으로 `y/N` 확인 뒤 덮어쓰며 자동화에서는 `--yes`를 명시합니다.

## 먼저 고칠 곳

- `AGENTS.md`: 프로젝트 개요, 스택, 완료 기준
- `loops/stop-gate.sh`: `HARNESS_TEST_COMMAND`, `GATE_PATHS`(기본 `src tests`)
- `profiles/`: 허용·차단 명령과 네트워크 정책
- `skills/release-notes/`: 팀 입력 형식과 출력 기준

## 알려진 함정

- 신뢰 승인하지 않은 폴더에서는 Claude Code가 프로젝트 `.claude/settings.json`의 `permissions.allow`를 무시합니다. 훅·deny가 적용되어도 allow 적용을 뜻하지는 않습니다. 적용한 폴더에서 `claude`를 한 번 대화형으로 열어 폴더 신뢰를 승인하세요.
- 헤드리스·CI에서는 적용한 폴더에서 설정을 명시합니다: `claude -p --settings .claude/settings.json "작업 내용"`. 2026년 11월 리허설에서 프로젝트 설정의 allow 무시 경고가 남아도 `--settings`로 전달한 allow는 적용되는 것을 확인했습니다. 사용할 프로필을 먼저 해당 설정 파일에 병합하세요.
- Stop 게이트는 `HEAD` 대비 `GATE_PATHS`의 변경(스테이징·미추적 포함)이 없으면 테스트를 생략합니다. 기본은 `src tests`이며 스크립트 상단 변수나 환경변수로 바꿀 수 있습니다. Git 저장소가 아니거나 `HEAD`가 없으면 기존처럼 테스트합니다.

## 참고 링크

공식 링크는 도구 버전이 확정된 뒤 이 절에만 추가합니다.
