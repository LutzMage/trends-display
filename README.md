# Trends Display

> **Portfolio project — not a commercial product.** This is a proof of concept built for learning and demonstration. It is not intended for production use, and seeded content comes from public Bluesky accounts for internal demos only.

A Pinterest-like visual discovery feed. Users browse a masonry grid of image and text posts, and every interaction refines a semantic profile of the user. The feed is then re-ranked by vector similarity between that profile and post embeddings produced by an AI service.

## Tech stack

| Layer | Technologies |
|-------|--------------|
| **Frontend** | React 19 · TypeScript 6 · Vite 8 · Tailwind CSS 4 · React Router 8 · oxlint |
| **Backend** | Ruby 3.4 · Ruby on Rails 8.1 (API-only) · Puma · Solid Queue · Solid Cache · rack-cors · image_processing / libvips |
| **Data** | PostgreSQL 17+ · pgvector (via the `neighbor` gem) |
| **AI** | OpenAI-compatible API (LM Studio locally): `nomic-embed-text-v1.5` for embeddings, `gemma-3-4b-it` for image descriptions |
| **Quality** | Minitest · RuboCop (rails-omakase) · Brakeman · bundler-audit · GitHub Actions |

## Features

- **Masonry feed** with responsive columns (2–5) and cursor-based infinite scroll.
- **Personalised ranking**: cosine distance between the user's profile vector and post embeddings, with a newest-first fallback for new users.
- **Embedding pipeline**: background jobs embed post text and an AI-generated description of each image.
- **User profiles** built from weighted, time-decayed interaction signals (like, save, share, dwell time…).
- **Post detail view** pinned in the grid at `/posts/:id`, with deep links, loading/not-found/error states and an entrance animation.

**Planned:** authentication, interaction tracking from the UI, and post creation with image upload. See [`intent/intent.md`](intent/intent.md).

## Architecture

```
React SPA ──JSON──▶ Rails API ──▶ PostgreSQL + pgvector
                       │                  ▲
                       └─ enqueue ─▶ Solid Queue jobs ──▶ AI service
                                    (embeddings, user profile)
```

## Getting started

### Prerequisites
- Ruby 3.4.10, Node.js 22.22+, PostgreSQL 17+ with the `pgvector` extension, and libvips.
- An OpenAI-compatible AI server (e.g. [LM Studio](https://lmstudio.ai)) serving an embedding model and a vision model.

### Configuration
Create `backend/.env`:

```bash
EMBEDDINGS_URL="http://localhost:1234/v1"
EMBED_MODEL="nomic-ai/text-embedding-nomic-embed-text-v1.5"
VISION_MODEL="gemma-3-4b-it"
BLUESKY_API_URL="https://public.api.bsky.app/xrpc/app.bsky.feed.getAuthorFeed"
BLUESKY_HANDLERS_API="https://public.api.bsky.app/xrpc"
# Optional, defaults shown:
# BACKEND_DATABASE_USERNAME=trends_display
# BACKEND_DATABASE_PASSWORD=devpassword
```

The frontend reads `VITE_API_URL` (default `http://localhost:3000`).

### Install and run

```bash
# Backend
cd backend
bundle install
bin/rails db:prepare           # creates the primary and queue databases
bin/rails server -p 3000       # API on http://localhost:3000
bin/jobs                       # Solid Queue worker (separate terminal)

# Frontend
cd frontend
npm install
npm run dev                    # SPA on http://localhost:5173
```

### Seed data

```bash
cd backend
bin/rails runner script/handles_by_interest.rb   # find image-heavy Bluesky accounts per interest
bin/rails runner script/ingestion.rb             # import their image posts (idempotent)
bin/rails runner script/fake_likes.rb            # add synthetic likes to steer a demo user's profile (set USER_ID first)
```

## Useful commands

| Task | Command |
|------|---------|
| Backend tests | `cd backend && bin/rails test` |
| Backend lint (autofix) | `cd backend && bin/rubocop -a` |
| Security scan | `cd backend && bin/brakeman && bin/bundler-audit` |
| Frontend lint (autofix) | `cd frontend && npx oxlint --fix` |
| Frontend type-check + build | `cd frontend && npm run build` |
| Health check | `curl http://localhost:3000/up` |

## API

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/feed?cursor=&limit=&user_id=` | Feed page: `{ posts, next_cursor }`. `user_id` personalises the feed until authentication lands. |
| GET | `/api/posts/:id` | Single post |
| POST | `/api/posts` | Create a post (`{ post: { text, media_type?, media_url? } }`) |

## Project structure

```
backend/    Rails API: models, FeedQuery, UserProfileBuilder, IaService, jobs, seed scripts
frontend/   React SPA: views, components, hooks, API client
intent/     Product intent: goals, requirements, business rules
specs/      Feature specs, implementation plans and checklists
```

Development is spec-driven: each feature has a spec, a plan and a checklist under `specs/`, traced back to the requirements in `intent/`.
