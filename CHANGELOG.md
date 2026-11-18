# 변경 기록

이 저장소의 버전별 변경 내용이다. 버전은 `main` 병합 커밋에 붙이는 태그를 따른다 ([docs/code-style.md](docs/code-style.md) '버전 태그').

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

[0.8.0]: https://github.com/suwonlee-ajd/workflow-with-n8n/compare/v0.7.0...v0.8.0
[0.7.0]: https://github.com/suwonlee-ajd/workflow-with-n8n/releases/tag/v0.7.0
