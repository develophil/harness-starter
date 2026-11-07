#!/usr/bin/env bash
# 스타터 키트의 선택 레이어를 대상 프로젝트에 복사합니다.
set -euo pipefail

usage() {
  printf '사용: %s 대상경로 [--layer all|core|loops|profiles|evals|metrics] [--profile explore|build] [--dry-run] [--yes]\n' "$0" >&2
}

[[ $# -gt 0 && "$1" != -* ]] || { usage; exit 2; }
TARGET="$1"; shift
LAYER="all"; PROFILE="explore"; DRY_RUN=0; YES=0
while (($#)); do
  case "$1" in
    --layer) [[ $# -ge 2 ]] || { printf '오류: --layer 값이 필요합니다.\n' >&2; exit 2; }; LAYER="$2"; shift 2 ;;
    --profile) [[ $# -ge 2 ]] || { printf '오류: --profile 값이 필요합니다.\n' >&2; exit 2; }; PROFILE="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --yes) YES=1; shift ;;
    *) printf '오류: 알 수 없는 옵션 %s\n' "$1" >&2; usage; exit 2 ;;
  esac
done
case "$LAYER" in all|core|loops|profiles|evals|metrics) ;; *) printf '오류: 잘못된 레이어 %s\n' "$LAYER" >&2; exit 2 ;; esac
case "$PROFILE" in explore|build) ;; *) printf '오류: 잘못된 프로필 %s\n' "$PROFILE" >&2; exit 2 ;; esac

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCES=(); DESTINATIONS=()
add_file() { SOURCES+=("$1"); DESTINATIONS+=("$2"); }
add_tree() {
  local source="$1" destination="${2:-$1}" file relative
  while IFS= read -r -d '' file; do
    relative="${file#"$SOURCE_ROOT/$source/"}"
    add_file "$source/$relative" "$destination/$relative"
  done < <(find "$SOURCE_ROOT/$source" -type f -print0 | sort -z)
}
add_core() {
  local item
  for item in .gitignore README.md AGENTS.md CLAUDE.md GEMINI.md; do add_file "$item" "$item"; done
  for item in hooks skills .claude .gemini docs templates scripts; do add_tree "$item"; done
  add_tree skills .agents/skills
  add_file profiles/README.md profiles/README.md
  add_tree .codex
}
add_profile() { add_tree "profiles/$PROFILE" ".harness/profiles/$PROFILE"; }
case "$LAYER" in
  all) add_core; add_tree loops; add_profile; add_tree evals; add_tree metrics ;;
  core) add_core ;;
  loops) add_tree loops ;;
  profiles) add_profile ;;
  evals) add_tree evals ;;
  metrics) add_tree metrics ;;
esac

if (( ! DRY_RUN )); then mkdir -p "$TARGET"; fi
for index in "${!SOURCES[@]}"; do
  source="$SOURCE_ROOT/${SOURCES[$index]}"; destination="$TARGET/${DESTINATIONS[$index]}"
  if (( DRY_RUN )); then printf '[예정] %s -> %s\n' "${SOURCES[$index]}" "$destination"; continue; fi
  if [[ -e "$destination" && $YES -eq 0 ]]; then
    reply=""; read -r -p "덮어쓸까요? $destination [y/N] " reply || true
    [[ "$reply" == "y" || "$reply" == "Y" ]] || { printf '[건너뜀] %s\n' "$destination"; continue; }
  fi
  mkdir -p "$(dirname "$destination")"
  cp -p "$source" "$destination"
  printf '[적용] %s\n' "$destination"
done

if (( ! DRY_RUN )); then
  printf '\n다음 단계 (대상 폴더: %s)\n' "$TARGET"
  printf '1. 이 폴더에서 claude를 한 번 대화형으로 열어 폴더 신뢰를 승인하세요.\n'
  printf '   미신뢰 폴더에서는 프로젝트 .claude/settings.json의 permissions.allow가 무시됩니다.\n'
  printf '2. 헤드리스·CI에서는 대상 폴더에서 설정을 명시하세요: claude -p --settings .claude/settings.json "작업 내용"\n'
fi
