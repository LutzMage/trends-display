# Checklist — SPEC-002 Authentication

Source: [plan.md](plan.md) · Spec: [002-authentication.md](002-authentication.md)

## Prerequisites
- [x] **P-1** Get approval for `bcrypt ~> 3.1.7` (3.1.22) and `jwt 3.3.0`, then add them to the `Gemfile` and run `bundle install`.
- [x] **P-2** Add `DEFAULT_USER_PASSWORD`, `JWT_SECRET`, `FRONTEND_URL`, `AUTH0_CALLBACK_URL` and empty `AUTH0_*` entries to `backend/.env`. Never print the values.
- [ ] **P-3** (Owner) Create the Auth0 tenant and app, enable `google-oauth2`, and fill in `AUTH0_*` (spec §6.5). Needed only for Phase 9.
- [x] **P-4** Run `bin/rails test` and record the baseline.
  - Baseline (2026-11-20): `3 runs, 13 assertions, 0 failures`.
- [x] **P-5** Create branch `add-authentication` from `main`.

## Phase 1 — Backend foundations (test first)
- [x] `test_helper.rb`: force `EMBED_MODEL=test-model`, set default test secrets, and add the `stub_singleton` and `sign_in_as` helpers.
- [x] Test (red): `User` requires a password, `authenticate` works, and email is normalised.
- [x] `users.yml`: add `password_digest`.
- [x] `User`: add `has_secure_password` and `normalizes :email`.
- [x] Migration `BackfillUserPasswords`: guard the env var and case collisions, lower-case emails, set one shared digest, then `NOT NULL`.
- [x] `script/ingestion.rb`: new users get `DEFAULT_USER_PASSWORD`.
- [x] Test (red): `SessionToken` issue/decode, expiry, tampering, and `alg: none` / wrong secret.
- [x] `SessionToken`: HS256, 24 h TTL, required claims.
- [x] Migration `CreateRevokedTokens`, plus the `RevokedToken` model with `revoke!`.
- [x] `config/application.rb`: `ActionDispatch::Cookies` middleware.
- [x] `ApplicationController`: include `ActionController::Cookies` and `Authentication`.
- [x] `cors.rb`: `FRONTEND_URL` origin with `credentials: true`.
- [x] `Authentication` concern: `current_user`, `require_authentication`, `start_session` and `end_session`.

## Phase 2 — Email + password endpoints (test first)
- [x] Test (red): sign-in success with the cookie attributes and no token in the body (AC-01).
- [x] Test (red): sign-in with an email in mixed case (AC-02).
- [x] Test (red): wrong password, unknown email or missing field → the same `401` (AC-03).
- [x] Test (red): the 11th attempt → `429` (AC-04).
- [x] Test (red): `/api/me` → `200` signed in, and `401` for each invalid case (AC-05, AC-06).
- [x] Test (red): sign-out revokes the token and clears the cookie; it is idempotent (AC-07, AC-08).
- [x] Routes: `api/auth/sign_in`, `api/auth/sign_out` and `api/me`.
- [x] `Api::Auth::SessionsController` with the rate limit and its own store.
- [x] `Api::MeController`.
- [x] Tests green, and `bin/rubocop -a` is clean.

## Phase 3 — Google through Auth0 (test first)
- [x] Test (red): `Auth0Client.authorize_url` parameters.
- [x] Test (red): `exchange_code` returns claims for a valid token, and raises for a bad signature, `iss`, `aud`, `exp` or `nonce`, or a token-endpoint error.
- [x] `Auth0Client`: `authorize_url`, `exchange_code`, `fetch_jwks` (cached) and `post_token`.
- [x] Test (red): `GET /api/auth/google` redirect and the `td_oauth` cookie attributes (AC-09).
- [x] Test (red): callback success (AC-10).
- [x] Test (red): callback failures: cancelled, state, missing or expired cookie, no account (no user created), unverified, exchange error (AC-11…15).
- [x] Routes: `api/auth/google` and `api/auth/google/callback`.
- [x] `Api::Auth::GoogleController`: `start` (state, nonce, PKCE, encrypted cookie) and `callback` (spec §4.4).
- [x] Tests green, and `bin/rubocop -a` is clean.

## Phase 4 — Feed and posts use the session (test first)
- [x] `embeddings.yml`: add a `two_profile` user-profile embedding.
- [x] Test (red): feed is newest-first when anonymous, `user_id` is ignored, and it is ranked when signed in (AC-16, AC-17).
- [x] Test (red): `POST /api/posts` → `401` when anonymous; the author is the current user; `422` for invalid input (AC-18, AC-19).
- [x] `FeedController`: use `current_user` and remove `user_id`.
- [x] `PostsController`: `require_authentication` on `create`, `current_user.posts.new`, and drop `:user_id` from the permitted params.
- [x] Tests green, and `bin/rubocop -a` is clean.

## Phase 5 — Origin check (Should)
- [x] Test (red): a foreign `Origin` on `POST`/`DELETE` → `403`; the SPA origin, no `Origin`, and `GET` all pass (AC-20).
- [x] `before_action` for state-changing methods.

## Phase 6 — Frontend
- [ ] `api/auth.ts`: `User`, `InvalidCredentialsError`, `signIn`, `signOut` and `fetchMe`.
- [ ] `api/feed.ts` and `api/posts.ts`: `credentials: 'include'`; remove `userId`.
- [ ] `hooks/useFeed.ts`: remove the `userId` option.
- [ ] `auth/AuthProvider.tsx` and `useAuth()`.
- [ ] `main.tsx`: wrap `App` in `AuthProvider`.
- [ ] `App.tsx`: `/login` route; key `FeedView` by user id and wait for the auth status.
- [ ] `LoginView.tsx`: the form, the `?error=` messages, the Google link, and the redirect when signed in.
- [ ] `FeedView.tsx`: header Log in / `@username` + Log out.

## Phase 7 — Documentation
- [ ] `README.md`: new env var names (no values), Auth0 setup pointer, auth endpoints, stack.
- [ ] `intent.md` §9.1: installed bcrypt and jwt versions.

## Phase 8 — Quality gates
- [ ] `cd backend && bin/rails test`
- [ ] `cd backend && bin/rubocop -a && bin/brakeman && bin/bundler-audit`
- [ ] `cd frontend && npx oxlint --fix && npm run lint`
- [ ] `cd frontend && npm run build`
- [ ] Push, and confirm CI is green (all four jobs).

## Phase 9 — Manual acceptance (Chrome, Edge or Firefox)
- [ ] AC-21: no user without a `password_digest`; a seeded user signs in with `DEFAULT_USER_PASSWORD`.
- [ ] AC-22: the header shows **Log in** when signed out.
- [ ] AC-23, AC-29: sign-in lands on `/` with `@username`, the feed reloads, the session survives a reload, and the cookie flags are HttpOnly, Secure and SameSite Strict.
- [ ] AC-24: a wrong password shows the alert, clears the password and keeps the email.
- [ ] AC-25, AC-26: Google with a matching account signs in; no account or a cancel shows the right message.
- [ ] AC-27: **Log out** → **Log in** in the header and a newest-first feed.
- [ ] AC-28: `/login` while signed in redirects to `/`.
- [ ] AC-30: keyboard-only use of the Log in page.
- [ ] Spec status → Implemented.
