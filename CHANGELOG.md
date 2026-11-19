# 변경 기록

이 저장소의 버전별 변경 내용이다. 버전은 `main` 병합 커밋에 붙이는 태그를 따른다 ([docs/code-style.md](docs/code-style.md) '버전 태그').

## [0.11.1] - 2026-11-19

### 변경

- 설명 스티키 노트 규칙 보완 (`.claude/skills/n8n/references/workflow-builder.md`)
  - 적용 범위: `example-1~3` 을 뺀 모든 워크플로우
  - 문체: 요약·본문 모두 두괄식·명사형 종결
  - 위치·크기: 맨 왼쪽 노드와 x 를 맞추고 가장 위 노드보다 60px 이상 위, 최소 480x200, 내용이 늘면 위쪽으로 키움
  - 기존 워크플로우를 고칠 때 스티키가 없거나 규칙과 다르면 보완안을 함께 보여 주고 승인받아 고침
- `docs/code-style.md` 1장: 주석 문체(두괄식·명사형)를 n8n 스티키 노트·노드 `notes` 에도 적용한다고 명시

## [0.11.0] - 2026-11-19

### 호환성

- 반영: `bin/n8n.sh restart` (로고 파일 연결)

### 추가

- `assets/ajd-logo.png`: n8n 스티키 노트용 회사 로고 (50x50 px). 표준 디렉터리 구조에 `assets/` 추가
- `services/n8n/docker-compose.yml`: 로고를 n8n 편집기 static 폴더에 읽기 전용 연결 → `/static/ajd-logo.png`. 컨테이너를 다시 만들어도 유지
- 설명 스티키 노트 규칙 (`.claude/skills/n8n/references/workflow-builder.md`): 모든 워크플로우의 캔버스 왼쪽 위에 로고·제목·1~2줄 요약

### 변경

- `README.md`: 주요 설정 6번(스티키 노트 로고), 4장 버전 업그레이드에 로고 확인 단계
- `docs/architecture.md`, `docs/code-style.md`, `CLAUDE.md`: 로고 연결, 스티키 규칙 링크, `assets/` 디렉터리

## [0.10.1] - 2026-11-19

### 호환성

- n8n 컨테이너를 공식 이미지 대신 로컬 빌드 이미지 `n8n-local:<N8N_VERSION>-node<N8N_NODE_VERSION>` 로 실행
  - 반영: `services/n8n/.env` 에 `N8N_NODE_VERSION=26.13.1` 추가 → `bin/n8n.sh restart`
  - 이 값이 없으면 `start` 뿐 아니라 `stop`·`backup` 등 compose 를 쓰는 `bin/n8n.sh` 명령이 모두 실패하므로, 받은 뒤 가장 먼저 추가
- n8n-mcp 2.103.1: `cd services/n8n-mcp && npm ci` 뒤 Claude Code 세션을 새로 시작

### 추가

- `services/n8n/Dockerfile`: n8n 공식 이미지의 Node.js 를 26.13.1 로 교체
  - 이유: [Node.js 보안 권고](https://asec.ahnlab.com/ko/96589/)(ASEC, 2026-11-17, CVE-2026-123863 등 7건)의 해결 버전보다 공식 이미지의 Node 가 낮음 (2.44.7 은 26.12.1, 최신 2.48.5·2.49.1 도 26.13.0)
  - 빌드 중단 조건: `N8N_NODE_VERSION` 형식 오류, 공식 이미지의 Node 가 `N8N_NODE_VERSION` 이상이거나 메이저가 다름, 교체 뒤 `node -v` 가 다름
  - node 이미지는 n8n 이미지와 같은 `alpine3.24` 로 고정, `ENV NODE_VERSION` 도 실제 버전으로
- `services/n8n/.dockerignore`: 빌드 컨텍스트 전부 제외 (`.env` 가 빌드로 넘어가지 않도록)

### 변경

- `services/n8n/docker-compose.yml`: n8n 서비스에 `build`·`pull_policy: never`. 이미지 태그가 없을 때만 빌드
- `bin/n8n.sh restart`: 컨테이너를 내리기 전에 이미지를 먼저 빌드. 빌드가 실패하면 기존 컨테이너를 그대로 두고 중단
- n8n-mcp 2.103.0 → 2.103.1 (도구 29개 그대로)
- `README.md` 6장: 호스트 Node 도 보안 권고의 해결 버전 이상을 쓰도록 안내
- 문서: 교체 이유·되돌릴 조건은 Dockerfile 주석에 두고 README·`docs/architecture.md` 는 링크, 되돌리는 방법 (`README.md` 4장), Compose 빌드 규칙 (`docs/code-style.md` 3장·9장)

## [0.10.0] - 2026-11-18

### 호환성

- 백업 폴더 이름을 날짜 8자리에서 일시 12자리(`YYYYMMDDHHMM`)로 변경: `<BACKUP_DIR>/<YYYYMMDDHHMM>/<서비스명>/`
- 백업 워크플로우 `[메인] 운영: n8n 데이터 백업` 도 `bin/n8n.sh backup` 과 같은 `<BACKUP_DIR>/<YYYYMMDDHHMM>/n8n/` 에 저장
- n8n 컨테이너의 백업 폴더 연결 변경: `<BACKUP_DIR>/n8n-workflow` → `<BACKUP_DIR>` 전체를 `~/.n8n-files/backups` 로. 반영하려면 `bin/n8n.sh restart`
- 기존 `<YYYYMMDD>/`, `n8n-workflow/` 백업은 그대로 두며 옮기지 않음

### 변경

- `bin/n8n.sh backup`: 실행 시각 스탬프의 앞 12자리로 폴더를 만듦. 파일 이름의 `<시각>`(`YYYYMMDD_HHMMSS`)은 그대로
- `services/n8n/docker-compose.yml`: 백업 폴더 전체 연결, 주석 갱신
- 백업 워크플로우의 저장 위치와 현재 결과물(볼륨 `n8n_backup_<시각>.tar.gz`, 워크플로우 JSON `n8n_workflows_<시각>/<ID>.json`, 실행 기록·데이터 테이블 JSON)을 문서에 반영 (`README.md`, `docs/architecture.md`, `docs/code-style.md`)
- 문서: n8n 워크플로우에서 `bin/n8n.sh backup` 의 볼륨 백업·DB 덤프도 읽을 수 있음을 명시
- `docs/code-style.md`: '날짜와 파일 위치' 에 백업 폴더 일시 형식 추가
- n8n 스킬: 전체 백업·단일 워크플로우 백업 경로를 새 규칙으로

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

[0.10.0]: https://github.com/suwonlee-ajd/workflow-with-n8n/compare/v0.9.2...v0.10.0
[0.9.2]: https://github.com/suwonlee-ajd/workflow-with-n8n/compare/v0.9.1...v0.9.2
[0.9.1]: https://github.com/suwonlee-ajd/workflow-with-n8n/compare/v0.9.0...v0.9.1
[0.9.0]: https://github.com/suwonlee-ajd/workflow-with-n8n/compare/v0.8.0...v0.9.0
[0.8.0]: https://github.com/suwonlee-ajd/workflow-with-n8n/compare/v0.7.0...v0.8.0
[0.7.0]: https://github.com/suwonlee-ajd/workflow-with-n8n/releases/tag/v0.7.0
