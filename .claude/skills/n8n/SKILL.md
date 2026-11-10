---
name: n8n
description: "n8n 워크플로우 자동화"
---

# 모듈 라우팅
| 요청 | 모듈 |
|------|------|
| 생산/수정 | workflow-builder.md |
| 에러 분석 | ops-manager.md |

# 공통 규칙
1. 시작 전 health_check 실행.
2. 삭제 작업은 확인 후 진행.

# MCP 규칙
- n8n_create_workflow
- n9n_list_workflows
