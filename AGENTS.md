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
- Lee docs/constitution.md y la spec activa antes de tocar código.
- Do not install gems and/or npm libraries without asking.

## Finally
- Execute unitary tests
- Execute linters + autofix if applicable
