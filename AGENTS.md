# AGENTS.md — Trends Display
## Proyect
Pinterest-like application: a feed with different interactive posts, and a recommendation system. Backend: Ruby on Rails (API-only), and frontend React + Vite + Typescript. External AI service. Postgres Database for data layer.

## Commands
- Run server: `cd backend/ && bin/rails server -p 3000`
- Run UI: `cd frontend/ && npm run dev`
- Tests: `cd backend/ && bin/rails test`
- Lint: `cd backend/ && bin/rubocop` and `cd frontend/ && npm run lint`

## Style and conventions
English language for code and messages.

## Rules
- Read `intent/intent.md` and the active spec before modifying the code.
- Execute one step of the checklist at time. This rule does not apply for: Prerequisites, Documentation and Quality gates. Do not execute the Manual acceptance. After each step, ask for validation.
- Do not install gems and/or npm libraries without asking.
- Always create the test first, and try to accomplish the criteria with the code.

## Finally
- Execute unitary tests
- Execute linters + autofix if applicable
- Modify the README.md if it's necessary
