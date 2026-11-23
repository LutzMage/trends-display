# Trends Display

> **Portfolio project — not a commercial product.** This is a proof of concept built for learning and demonstration. It is not intended for production use, and seeded content comes from public Bluesky accounts for internal demos only.

A Pinterest-like visual discovery feed. Users browse a masonry grid of image and text posts, and every interaction refines a semantic profile of the user. The feed is then re-ranked by vector similarity between that profile and post embeddings produced by an AI service.

## Tech stack

| Layer | Technologies |
|-------|--------------|
| **Frontend** | React 19 · TypeScript 6 · Vite 8 · Tailwind CSS 4 · React Router 8 · oxlint |
| **Backend** | Ruby 3.4 · Ruby on Rails 8.1 (API-only) · Puma · Solid Queue · Solid Cache · rack-cors · image_processing / libvips |
| **Auth** | Email + password (bcrypt) · Google through Auth0 (OIDC + PKCE) · session JWT (ruby-jwt) in an HttpOnly cookie |
| **Data** | PostgreSQL 17+ · pgvector (via the `neighbor` gem) |
| **AI** | OpenAI-compatible API (LM Studio locally): `nomic-embed-text-v1.5` for embeddings, `gemma-3-4b-it` for image descriptions |
| **Quality** | Minitest · RuboCop (rails-omakase) · Brakeman · bundler-audit · GitHub Actions |

## Features

- **Masonry feed** with responsive columns (2–5) and cursor-based infinite scroll.
- **Personalised ranking**: cosine distance between the user's profile vector and post embeddings, with a newest-first fallback for new users.
- **Embedding pipeline**: background jobs embed post text and an AI-generated description of each image.
- **User profiles** built from weighted, time-decayed interaction signals (like, save, share, dwell time…).
- **Post detail view** pinned in the grid at `/posts/:id`, with deep links, loading/not-found/error states and an entrance animation.
- **Interactions** on the open post: like (pink heart) and save, both undoable; comments with initials avatars; a share modal for Facebook, X, Instagram, Discord, Messenger and WhatsApp with Copy link; and image download. Each action feeds the user's profile.
- **Authentication**: sign in with email + password or with Google (Auth0). The backend issues a JWT in an `HttpOnly`, `Secure`, `SameSite=Strict` cookie, revokes it on sign-out, rate-limits sign-in and rejects cross-site writes. The feed is personalised for the signed-in user.

**Planned:** sign-up, impression and dwell-time tracking, a saved-posts page, and post creation with image upload. See [`intent/intent.md`](intent/intent.md).

## Architecture

```
React SPA ──JSON + session cookie──▶ Rails API ──▶ PostgreSQL + pgvector
    │                                  │  │                ▲
    └─ "Continue with Google" ─▶ Auth0 ◀┘  └─ enqueue ─▶ Solid Queue jobs ──▶ AI service
       (redirect)          (code exchange,              (embeddings, user profile)
                            ID-token check)
```

## Getting started

### Prerequisites
- Ruby 3.4.13, Node.js 22.22+, PostgreSQL 17+ with the `pgvector` extension, and libvips.
- An OpenAI-compatible AI server (e.g. [LM Studio](https://lmstudio.ai)) serving an embedding model and a vision model.
- Optional, for Google sign-in: an [Auth0](https://auth0.com) tenant. See [Auth0 setup](#auth0-setup).
- A Chromium browser or Firefox for local development. Safari rejects `Secure` cookies on `http://localhost`, so the session would not stick.

### Configuration
Create `backend/.env` (it is gitignored; never commit it):

```bash
EMBEDDINGS_URL="http://localhost:1234/v1"
EMBED_MODEL="nomic-ai/text-embedding-nomic-embed-text-v1.5"
VISION_MODEL="gemma-3-4b-it"
BLUESKY_API_URL="https://public.api.bsky.app/xrpc/app.bsky.feed.getAuthorFeed"
BLUESKY_HANDLERS_API="https://public.api.bsky.app/xrpc"

# Authentication
DEFAULT_USER_PASSWORD="<openssl rand -base64 18>"   # shared password of the seeded users
JWT_SECRET="<openssl rand -hex 32>"                 # signs session tokens
FRONTEND_URL="http://localhost:5173"                # CORS origin and redirect target
AUTH0_DOMAIN="<your-tenant>.us.auth0.com"
AUTH0_CLIENT_ID="<from the Auth0 application>"
AUTH0_CLIENT_SECRET="<from the Auth0 application>"
AUTH0_CALLBACK_URL="http://localhost:3000/api/auth/google/callback"

# Optional, defaults shown:
# BACKEND_DATABASE_USERNAME=trends_display
# BACKEND_DATABASE_PASSWORD=devpassword
# DOWNLOAD_HOSTS=cdn.bsky.app                       # comma-separated image hosts the download endpoint may fetch from
```

The frontend reads `VITE_API_URL` (default `http://localhost:3000`).

### Auth0 setup
Only needed for **Continue with Google**; email + password works without it.
1. Create an Auth0 tenant and a **Regular Web Application**.
2. Set **Allowed Callback URLs** to `http://localhost:3000/api/auth/google/callback`.
3. Enable the **google-oauth2** social connection for the application.
4. Copy the domain, client ID and client secret into `backend/.env`.
5. There is no sign-up yet, so give an existing user the email of your Google account.

Details: [SPEC-002 §6.5](specs/002/002-authentication.md).

### Install and run

```bash
# Backend
cd backend
bundle install
bin/rails db:prepare           # creates the databases and runs migrations (needs DEFAULT_USER_PASSWORD if users exist)
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

Seeded users sign in with their email and `DEFAULT_USER_PASSWORD`. To see a steered profile, sign in as that user.

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
| GET | `/api/feed?cursor=&limit=` | Feed page: `{ posts, next_cursor }`. Ranked for the signed-in user, newest first when anonymous. |
| GET | `/api/posts/:id` | Single post, with `like_count`, `comment_count`, and the viewer's `liked` and `saved` |
| POST | `/api/posts` | Create a post as the signed-in user (`{ post: { text, media_type?, media_url? } }`). `401` when signed out. |
| PUT / DELETE | `/api/posts/:id/like` | Like or unlike (signed in). Returns `{ liked, like_count }`. |
| PUT / DELETE | `/api/posts/:id/save` | Save or unsave (signed in). Returns `{ saved }`. |
| GET | `/api/posts/:id/comments` | `{ comments }`: the 100 newest, each with its author. |
| POST | `/api/posts/:id/comments` | Add a comment as the signed-in user (`{ comment: { body } }`, 1–250 characters). |
| POST | `/api/posts/:id/interactions` | Record `click`, `share` or `download` for the signed-in user (`{ event_type }`). |
| GET | `/api/posts/:id/download` | The post's image as a file. Only fetched from `DOWNLOAD_HOSTS`. |
| POST | `/api/auth/sign_in` | `{ email, password }` → the user, and sets the `td_session` cookie. Limited to 10 attempts per 3 minutes per IP. |
| DELETE | `/api/auth/sign_out` | Revokes the session and clears the cookie (`204`). |
| GET | `/api/me` | The signed-in user, or `401`. |
| GET | `/api/auth/google` | Redirects to Google through Auth0. |
| GET | `/api/auth/google/callback` | Auth0 callback: signs in and redirects to the SPA, or to `/login?error=…`. |

The session is a cookie, so browser requests need `credentials: 'include'`. `POST`, `PUT`, `PATCH` and `DELETE` requests from a foreign `Origin` get `403`.

## Project structure

```
backend/    Rails API: models, FeedQuery, UserProfileBuilder, IaService, jobs, seed scripts
frontend/   React SPA: views, components, hooks, API client
intent/     Product intent: goals, requirements, business rules
specs/      Feature specs, implementation plans and checklists
```

Development is spec-driven: each feature has a spec, a plan and a checklist under `specs/`, traced back to the requirements in `intent/`.
