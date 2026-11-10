---
name: n8n
description: "n8n 워크플로우 자동화. n8n-mcp로 워크플로우를 생성·수정하거나, 실행 에러를 분석하거나, n8n 사용법을 설명할 때 사용한다. 예: '워크플로우 만들어줘', '이 워크플로우 수정해줘', '실행이 실패한 원인 찾아줘', 'n8n 노드 사용법 알려줘'."
---

# 모듈 라우팅
요청에 맞는 파일을 먼저 읽고 진행한다.

| 요청 | 읽을 파일 |
|------|-----------|
| 생성/수정 | [references/workflow-builder.md](references/workflow-builder.md) |
| 에러 분석 | [references/ops-manager.md](references/ops-manager.md) |
| 사용법 설명/교육 | [references/teaching-guide.md](references/teaching-guide.md) |

# 공통 규칙
항상 지킬 공통 규칙은 `.claude/rules/n8n/`에 있으며 세션 시작 시 자동으로 로드된다.

# MCP 규칙
- n8n_create_workflow
- n8n_list_workflows
