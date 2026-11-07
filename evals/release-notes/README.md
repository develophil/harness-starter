# release-notes 평가

`fixtures/changes.json`은 수동 반복 작업 후보의 입력 계약을 그대로 보존한 기준 데이터입니다. 세 케이스는 전체 변환, 호환성 변경, 누락·중복 방지를 각각 검사합니다.

## 비교 절차

1. 스킬 변경 전 결과를 `baseline.md` 표에 기록합니다.
2. `claude plugin eval skills/release-notes --eval-dir evals/release-notes --ablation with-without`으로 스킬 사용/미사용 점수 차이를 구합니다.
3. 다른 도구는 동일한 세 prompt를 실행하고 각 `graders/criteria.md`를 사람이 같은 척도로 채점합니다.
4. 변경 전·후 점수, 실패 케이스, 비용을 한 줄씩 남깁니다.

# 버전 확인: 공개 문서의 eval 디렉터리와 채점기 스키마는 설치 버전에서 재검증합니다.

