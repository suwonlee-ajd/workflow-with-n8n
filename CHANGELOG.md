# 변경 기록

이 저장소의 버전별 변경 내용이다. 버전은 `main` 병합 커밋에 붙이는 태그를 따른다 ([docs/code-style.md](docs/code-style.md) '버전 태그').

## [0.9.2] - 2026-11-18

### 추가

- `.claude/rules/n8n/common.md`: 세션 역할(`repo`·`mcp`)과 작업지시서(`.claude/tasks/<받을 세션>/`) 규칙. 작업을 모두 끝내면 작업지시서를 지움

### 변경

- `.claude/rules/n8n/common.md`: 제목을 'workflow-with-n8n 공통 규칙'으로 바꾸고, 적용 범위를 저장소 전체로 넓힘 (HARD RULES·일반 규칙은 n8n 작업에만)
- `CLAUDE.md`, `README.md`: 세션 역할·작업지시서 위치 안내

## [0.9.1] - 2026-11-18

### 변경

- 백업 워크플로우 `[메인] 운영: n8n 데이터 백업` 이 워크플로우마다 파일(`n8n_workflow_<시각>_<ID>.json`)로 저장하고 매일 18:00 에 자동 실행되는 것을 문서에 반영 (`README.md`, `docs/architecture.md`, `docs/code-style.md`)
- `docs/code-style.md`: 노드 `typeVersion` 은 실행 중인 n8n 이 지원하는 값으로 쓰는 규칙 추가

## [0.9.0] - 2026-11-18

### 추가

- `BACKUP_DIR` (`services/n8n/.env`): 백업 경로 지정. 비우면 `data/backups`, 다른 위치는 절대 경로
- n8n 컨테이너에 `<BACKUP_DIR>/n8n-workflow` 연결: 백업 워크플로우 `[메인] 운영: n8n 데이터 백업` 의 저장 위치

### 변경

- `bin/n8n.sh`: 백업 경로를 `BACKUP_DIR` 에서 읽음. 상대 경로면 중단
- `services/n8n/.env.example`: `.env` 와 같은 구역 구성(기본·n8n·DB)으로 정리
- `README.md`, `docs/architecture.md`, n8n 스킬: 백업 경로·백업 워크플로우 설명 추가
- `docs/code-style.md`: 백업 위치 표, `.env.example` 구역·줄끝 주석 규칙 갱신

## [0.8.0] - 2026-11-18

### 호환성

- 기본 포트를 n8n `5678`, n8n-admin `3000` 으로 변경 (`services/n8n/.env.example`, `.mcp.json`, 문서)
- 기존 포트를 계속 쓰려면 `services/n8n/.env` 의 `N8N_PORT`·`N8N_WEBHOOK_URL` 은 그대로 두고, `.mcp.json` 의 `N8N_API_URL` 을 같은 포트로 맞춤

### 추가

- `CHANGELOG.md`
- `docs/code-style.md`: PR 메시지·버전 태그 규칙, `docs/` 문서 머리(문서 버전·최종 수정 표)와 frontmatter 규칙
- `docs/` 문서에 문서 버전·최종 수정 표

### 변경

- `docs/code-style.md`: 목록·표 항목을 명사형으로 정리, 문서 링크 보강
- `CLAUDE.md`: 버전 태그·PR 규칙은 요약과 링크만 남김, 서비스에 속하지 않는 작업의 브랜치 이름(`feature/docs/*`) 허용
- `README.md`, `docs/architecture.md`: 포트를 기본값으로 표기

## [0.7.0] - 2026-11-18

첫 태그. 그때까지 `main` 에 병합된 내용을 묶음.

### 추가

- n8n 백업에 워크플로우 JSON 포함, 백업·로그 저장 경로 분리 (PR #1)
- 주간 운영 리포트를 n8n 스킬 모듈로 추가 (PR #2)
- 코드 스타일 문서 초안 (PR #3)
- README 뱃지·참조 섹션 (PR #4)
- 중지·재시작 전 컨테이너 로그 저장, 컨테이너 로그 크기 제한, 로깅·아키텍처 문서
- n8n-admin 대시보드 서브모듈과 실행 스크립트
- n8n 워크플로우 네이밍·그룹 컨벤션
- n8n 스킬 모듈, 삭제 HARD RULE, `.env.example`, n8n-mcp 연동 안내

### 변경

- n8n-mcp 2.103.0 으로 업데이트
- 스크립트·설정 주석을 코드 스타일 규칙에 맞춤 (PR #3)

[0.9.2]: https://github.com/suwonlee-ajd/workflow-with-n8n/compare/v0.9.1...v0.9.2
[0.9.1]: https://github.com/suwonlee-ajd/workflow-with-n8n/compare/v0.9.0...v0.9.1
[0.9.0]: https://github.com/suwonlee-ajd/workflow-with-n8n/compare/v0.8.0...v0.9.0
[0.8.0]: https://github.com/suwonlee-ajd/workflow-with-n8n/compare/v0.7.0...v0.8.0
[0.7.0]: https://github.com/suwonlee-ajd/workflow-with-n8n/releases/tag/v0.7.0
