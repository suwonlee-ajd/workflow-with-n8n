---
name: n8n
description: "n8n 워크플로우 자동화. n8n-mcp로 워크플로우를 생성·수정·분석하거나, 실행 에러를 분석하거나, 운영 상 모티터링·디버깅, 컨텐츠 생성을 지원하며, n8n 사용법을 설명할 때 사용하며 다음 키워드에 트리거. 예: 'n8n', 'n8n 워크플로우', 'n8n 자동화', '워크플로우 목록 보여줘', '이 워크플로우 정보 알려줘', '워크플로우 만들어줘', '이 워크플로우 수정해줘', '실행이 실패한 원인 찾아줘', 'n8n 노드 사용법 알려줘'."
---

# n8n 워크플로우 자동화 스킬

n8n-mcp-skills 등 n8n 도구를 활용하여 워크플로우를 생성하고, 운영하는 스킬.

## 모듈 라우팅
요청에 맞는 파일을 먼저 읽고 진행한다.

| 요청 | 읽을 파일 |
|------|-----------|
| 생성/수정 | [references/workflow-builder.md](references/workflow-builder.md) |
| 에러 분석 | [references/ops-manager.md](references/ops-manager.md) |
| 사용법 설명/교육 | [references/teaching-guide.md](references/teaching-guide.md) |
| 복합 요청 | 해당 모듈 복수로드 (우선순위:  → builder → teaching) |

의도가 불분명하면 사용자에게 확인.

## 시작 안내
이 스킬이 로드되면 사용자에게 다음 안내를 출력.
> n8n 스킬이 로드되었습니다. 아래 명령을 해보세요:
> - "워크플로우 목록 보여줘"
> - "Slack 알림 워크플로우 만들어줘"
> - "전체 워크플로우 이름 컨벤션 정리해줘"
> - "에러 리포트 보여줘"
> - "워크플로우 연결해줘"

## 안전 확인

삭제는 `.claude/rules/n8n/common.md`의 HARD RULE만 따른다 (아래 확인 절차로 대체 불가).
삭제 외 파괴적 작업(전체 업데이트, 롤백, 일괄 변경)은 실행 전에 사용자에게 확인을 구한다:
1. 수행할 작업을 요약한다 (대상, 변경 내용, 영향 범위)
2. "진행할까요?" 확인을 받는다
3. 확인 후 실행한다

## 에러 대응 가이드

MCP 도구 호출 실패 시 아래 안내를 사용자에게 제공한다:

| 에러 상황 | 안내 |
|----------|------|
| MCP 연결 실패 / 도구 미발견 | "n8n MCP 서버가 연결되지 않았습니다. README 6장 순서대로 `services/n8n-mcp`에서 `npm ci`를 실행하고 `services/n8n/.env`에 `N8N_API_KEY`를 넣은 뒤, Claude Code를 다시 시작해 `/mcp`에서 `n8n-mcp` 연결을 확인해주세요. n8n이 꺼져 있으면 `bin/n8n.sh start`로 먼저 실행해주세요." |
| HTTP 401 / 인증 실패 | "API 키가 만료되었거나 잘못되었습니다. n8n → Settings → n8n API에서 키를 새로 만들어 `services/n8n/.env`의 `N8N_API_KEY`를 바꾼 뒤 Claude Code를 다시 시작해주세요." |
| HTTP 403 / 권한 부족 | "이 작업에는 Owner 권한이 필요합니다. n8n 관리자에게 문의해주세요." |
| 노드 미발견 (search_nodes 결과 없음) | "이 노드는 커뮤니티 노드일 수 있습니다. n8n → Settings → Community Nodes에서 먼저 설치해주세요." |
| n8n_test_workflow 실패 | 비활성 워크플로우면 아래 '테스트 제약사항'의 활성화 확인 진행. webhook/form/chat 외 트리거면 "이 트리거 타입은 테스트를 지원하지 않습니다. n8n UI에서 수동으로 테스트해주세요." |

# 공통 규칙
항상 지킬 공통 규칙은 `.claude/rules/n8n/`에 있으며 세션 시작 시 자동으로 로드된다.

## 작업 패턴

### 작업 시작 전 항상 실행
- `n8n_health_check`로 n8n 인스턴스 상태 확인.

### 노드 검색 패턴
```
search_nodes(쿼리) → get_node(노드타입) → validate_node(노드 설정 검증)
```

### 워크플로우 생성 패턴
```
validate_workflow(JSON 사전 검증) → n8n_create_workflow(생성) → n8n_test_workflow(테스트)
```

### 워크플로우 수정 패턴
- 부분 수정: `n8n_update_partial_workflow` (노드 추가/삭제/수정, 연결 변경 등)
- 전체 교체: `n8n_update_full_workflow` (구조 대폭 변경 시)
- 수정 전 `n8n_get_workflow`로 현재 상태 반드시 확인

### 검증 도구 구분
- `validate_workflow`: JSON 페이로드 사전 검증 (생성 전)
- `n8n_validate_workflow`: ID 기반 사후 검증 (생성/수정 후)
- `validate_node`: 개별 노드 설정 검증

### 테스트 제약사항
- `N8N_MCP_ACCESS_TOKEN` 미설정이라 `n8n_test_workflow`는 기본 방식(`auto`/`trigger`)만 사용 가능: webhook/form/chat 트리거만 지원하며, 워크플로우가 활성 상태여야 동작 (`prepare`·`pinned`·`direct` 방식 불가)
- 스케줄/크론 기반 워크플로우는 사용자에게 n8n UI에서 수동 테스트 안내
- 비활성 워크플로우는 테스트 전 사용자에게 활성화 방식 확인:
  1. 1회성 — 활성화 → 테스트 → 비활성화로 원복 (테스트 실패 시에도 원복)
  2. 계속 사용 — 활성화 → 테스트 → 활성 유지
  - 활성화/비활성화: `n8n_update_partial_workflow`의 `activateWorkflow` / `deactivateWorkflow`

### 안전 원칙
- 삭제는 HARD RULE(`.claude/rules/n8n/common.md`), 그 밖의 파괴적 작업은 '안전 확인' 절차 후 실행
- 롤백(`n8n_workflow_versions`)은 n8n-mcp가 수정 직전 자동 저장한 스냅샷만 대상
  - n8n UI에서 고친 내용은 스냅샷에 없음 → 롤백 시 덮어써짐 (롤백 직전 상태는 자동 백업)
  - `source: "native"`(n8n 자체 이력)는 `N8N_MCP_ACCESS_TOKEN` 미설정으로 사용 불가
  - 롤백 전 `mode: "list"`·`"get"`으로 되돌릴 스냅샷을 고르고 `"diff"`로 바뀔 내용 확인 → 덮어쓰기 영향과 함께 사용자 확인
  - 스냅샷이 없는 워크플로우(UI에서 만들거나 import한 것)는 수정·삭제 전 아래 단일 워크플로우 백업 실행
- 단일 워크플로우 백업 (`bin/n8n.sh export`는 실행마다 폴더를 비우고 다시 쓰므로 백업용으로 쓰지 않음)
  ```bash
  mkdir -p data/backups/workflows
  docker exec n8n n8n export:workflow --id=<ID> --output=/tmp/backup-<ID>.json
  docker cp n8n:/tmp/backup-<ID>.json data/backups/workflows/<ID>_$(date +%Y%m%d-%H%M%S).json
  docker exec n8n rm -f /tmp/backup-<ID>.json
  ```
  - 복원: README 3장의 단일 파일 import 사용 (`bin/n8n.sh import`는 폴더 전체를 덮어쓰고 모두 비활성화하므로 사용하지 않음). 복원된 워크플로우는 비활성 상태
- 도구 사용법이 불확실하면 `tools_documentation`으로 확인
