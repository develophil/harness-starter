# 권한 프로필 조각

각 프로필의 세 파일은 완성 설정이 아니라 검토용 조각입니다. `apply.sh`는 선택한 프로필만 `.harness/profiles/$PROFILE/`에 원래 이름 그대로 복사하며 기존 설정에 자동 병합하지 않습니다.

1. 대상 프로젝트와 사용자 설정의 우선순위를 확인합니다.
2. 조각의 허용·차단 규칙을 검토합니다.
3. 기존 `.claude/settings.json`, `.codex/config.toml`, `.codex/rules/`에 항목별로 병합합니다.
4. 허용 사례와 차단 사례를 각각 실행합니다.

# 확인(2026-10-04 문서): Claude 규칙은 `Tool` 또는 `Tool(specifier)`, Codex `prefix_rule(pattern, decision=allow|prompt|forbidden, justification, match, not_match)`.
# ⚠️ 미확인: `Read(./.env*)` 글롭 동작은 설치 버전에서 실측합니다.
# Codex 프로필에 훅을 넣었다면 적용 후 `/hooks`에서 신뢰 승인합니다. Claude `PermissionRequest` 훅의 판정은 `hookSpecificOutput.decision.behavior`(PreToolUse의 `permissionDecision`과 다름).
# ⚠️ 미확인: `[permissions.*]` 베타는 정식화 전까지 `sandbox_mode`와 병용하지 않습니다.
