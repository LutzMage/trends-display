# Implementation Plan — SPEC-002 Authentication

| Field | Value |
|-------|-------|
| Spec | [002-authentication.md](002-authentication.md) |
| Intent | [intent/intent.md](../../intent/intent.md): FR-AUTH-02…08, NFR-06, NFR-07, NFR-08 |
| Branch | `add-authentication` |
| Status | Ready for implementation once P-1 is approved |

## 1. Context
SPEC-002 adds:
- email + password sign-in,
- Google sign-in through Auth0,
- a backend-issued session JWT in an `HttpOnly`, `Secure`, `SameSite=Strict` cookie,
- a required password for every user,
- and API changes: the feed is personalised from the session, and `POST /api/posts` requires sign-in.

The plan follows the project rules:
- **AGENTS.md**: read the intent and the spec first. Write the **test first**. Never install a dependency without approval. Finish by running the unit tests and the linters (with autofix).
- **Intent NFR-06/07**: secrets live only in `backend/.env` and are never committed or logged. CORS allows only the SPA origin.
- **Intent NFR-08**: the Log in page has labels, keyboard access and `role="alert"` errors.
- **Intent NFR-10**: English for code, identifiers and UI text.

**Testing approach**: test-first applies to the **backend**, the same as in SPEC-001. The frontend has no test runner, so it is checked with `npm run lint`, `npm run build` and the manual checks in §11.

## 2. Prerequisites and approvals
| # | Item | Action |
|---|------|--------|
| P-1 | Gems `bcrypt ~> 3.1.7` (resolves to 3.1.22, released 2026-03-18) and `jwt 3.3.0` (released 2026-09-11) | **Ask for approval**. Then uncomment `bcrypt` in the `Gemfile`, add `gem "jwt", "3.3.0"`, and run `bundle install`. |
| P-2 | Local secrets | Append to `backend/.env` (gitignored by `/.env*`): <ul><li>`DEFAULT_USER_PASSWORD` from `openssl rand -base64 18`</li><li>`JWT_SECRET` from `openssl rand -hex 32`</li><li>`FRONTEND_URL=http://localhost:5173`</li><li>`AUTH0_CALLBACK_URL=http://localhost:3000/api/auth/google/callback`</li><li>empty `AUTH0_DOMAIN`, `AUTH0_CLIENT_ID` and `AUTH0_CLIENT_SECRET`</li></ul> Never print the generated values in chat or logs; tell the owner which file holds them. |
| P-3 | Auth0 tenant (owner, spec §6.5) | Only needed for the manual Google checks in §11. The automated tests stub Auth0. |
| P-4 | Test-suite baseline | Run `cd backend && bin/rails test` and record it (expected: 3 runs, 13 assertions, 0 failures). |
| P-5 | Branch | Create `add-authentication` from an up-to-date `main`. |

## 3. Phase 1 — Backend foundations (test first)

### 3.1 Test infrastructure: `test/test_helper.rb`
| Change | Why |
|--------|-----|
| Before `require_relative "../config/environment"`, set `ENV["EMBED_MODEL"] = "test-model"`, then `ENV["JWT_SECRET"] ||= "test-jwt-secret-#{'x' * 32}"`, `ENV["AUTH0_DOMAIN"] ||= "example.auth0.test"`, `ENV["AUTH0_CLIENT_ID"] ||= "test-client"` and `ENV["AUTH0_CLIENT_SECRET"] ||= "test-secret"`. | CI has no `.env`. `IaService::EMBED_MODEL` must match the fixtures' `test-model` for a ranked feed (Phase 4). dotenv does not overwrite variables that are already set. |
| A `stub_singleton(klass, method, callable) { … }` helper that swaps a class method and restores it in `ensure`. | Minitest 6.1 no longer ships `minitest/mock`, and adding `minitest-mock` would need approval. Parallel test workers are separate processes, so the swap is isolated. |
| A `sign_in_as(user)` helper for integration tests: `https!` plus `cookies[:td_session] = SessionToken.issue(user)`. | Tests of protected endpoints do not depend on the sign-in endpoint. |

### 3.2 Passwords: `User`
| Step | Detail | AC / FR |
|------|--------|---------|
| Test (red) `test/models/user_test.rb` | <ul><li>A new user without a password is invalid.</li><li>`authenticate("password")` returns the user for the right password and `false` for a wrong one.</li><li>`email` is stored stripped and lower-cased.</li></ul> | FR-AUTH-07 |
| Fixtures `users.yml` | Add `password_digest: <%= BCrypt::Password.create("password", cost: BCrypt::Engine::MIN_COST) %>`. Emails are already lower-case. | — |
| Model | `has_secure_password`, plus `normalizes :email, with: ->(e) { e.strip.downcase }`. | — |
| Migration `BackfillUserPasswords` | <ol><li>Raise a clear error if `ENV["DEFAULT_USER_PASSWORD"]` is blank.</li><li>Raise if any two emails differ only by case.</li><li>`UPDATE users SET email = LOWER(TRIM(email))`.</li><li>Compute **one** `BCrypt::Password.create(...)` and `update_all(password_digest:)` where it is null.</li><li>`change_column_null :users, :password_digest, false`.</li></ol> The `down` direction only makes the column nullable again. | AC-21 |
| `script/ingestion.rb` | `user_for`: `u.password = ENV.fetch("DEFAULT_USER_PASSWORD")`. | — |

### 3.3 `SessionToken` (`app/services/session_token.rb`)
| Step | Detail |
|------|--------|
| Test (red) `test/services/session_token_test.rb` | <ul><li>`issue(user)` → `decode` returns `sub == user.id.to_s`, a UUID `jti` and `exp == iat + 24.hours`.</li><li>After `travel 24.hours + 1.second`, `decode` returns `nil`.</li><li>A token with a changed payload or signature returns `nil`.</li><li>A token signed with `alg: none` or another secret returns `nil`.</li></ul> |
| Implement | `TTL = 24.hours`. Signs with `JWT.encode(payload, ENV.fetch("JWT_SECRET"), "HS256")`. `decode` calls `JWT.decode(token, secret, true, algorithm: "HS256", required_claims: %w[sub jti exp])`, rescues `JWT::DecodeError`, and returns `nil` on failure. |

### 3.4 `RevokedToken`
- Migration `CreateRevokedTokens`: `jti` (string, not null, unique index), `expires_at` (datetime, not null), and timestamps.
- Model: `validates :jti, presence: true, uniqueness: true`.
- `RevokedToken.revoke!(claims)` uses `insert_all` with `unique_by: :jti`, so revoking the same token twice is harmless.

### 3.5 Cookies and CORS
| File | Change |
|------|--------|
| `config/application.rb` | `config.middleware.use ActionDispatch::Cookies`. API mode leaves it out. |
| `app/controllers/application_controller.rb` | `include ActionController::Cookies` and `include Authentication`. |
| `config/initializers/cors.rb` | `origins ENV.fetch("FRONTEND_URL", "http://localhost:5173")` and `credentials: true`. The default keeps CI and boot working without `.env`. |

### 3.6 `Authentication` concern (`app/controllers/concerns/authentication.rb`)
- `current_user`, memoised. It reads `cookies[:td_session]` → `SessionToken.decode` → rejects the token when `RevokedToken.exists?(jti:)` → `User.find_by(id: claims["sub"])`.
- `require_authentication` renders `401 { error: "Not authenticated" }` unless there is a `current_user`.
- `start_session(user)` sets `cookies[:td_session] = { value: SessionToken.issue(user), httponly: true, secure: true, same_site: :strict, path: "/", expires: SessionToken::TTL.from_now }`. Rails sends `Max-Age` for `expires:` given as a duration; check it, and if needed pass `max_age:` explicitly.
- `end_session` revokes the current token's claims, if any, and calls `cookies.delete(:td_session, path: "/", same_site: :strict, secure: true)`.

The concern is exercised through the Phase 2 controller tests.

## 4. Phase 2 — Email + password endpoints (test first)

### 4.1 Write failing tests
Every test calls `https!` first, so the `Secure` cookie is written (spec §6.4).

| File | Tests | AC |
|------|-------|----|
| `test/controllers/api/auth/sessions_controller_test.rb` | <ul><li>Sign in: `200`, the body equals `{id, username, email}`, no `token` key, and `Set-Cookie` contains `td_session=`, `httponly`, `secure`, `samesite=strict`, `max-age=86400` and `path=/` (compared case-insensitively).</li><li>An email in mixed case still signs in.</li><li>A wrong password, an unknown email and a missing field each give `401` with the same body and no cookie.</li><li>11 attempts give `429` on the 11th.</li><li>Sign-out with a session: `204`, the cookie is expired, and `GET /api/me` with the old token gets `401`.</li><li>Sign-out without a session: `204`.</li></ul> | AC-01…04, 07, 08 |
| `test/controllers/api/me_controller_test.rb` | <ul><li>`200` with the User when signed in.</li><li>`401` with no cookie, an expired token (`travel`), a tampered token, a revoked token, or a token for a deleted user.</li></ul> | AC-05, 06 |

The rate-limit store is a class constant, so `setup` clears it (`RATE_LIMIT_STORE.clear`). Otherwise other sign-in tests in the same process would count towards the limit.

### 4.2 Implement
| File | Change |
|------|--------|
| `config/routes.rb` | <ul><li>Inside `namespace :api`: `namespace :auth { post "sign_in", to: "sessions#create"; delete "sign_out", to: "sessions#destroy"; get "google", to: "google#start"; get "google/callback", to: "google#callback" }`.</li><li>`get "me", to: "me#show"`.</li></ul> |
| `app/controllers/api/auth/sessions_controller.rb` | <ul><li>`RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new`, and `rate_limit to: 10, within: 3.minutes, only: :create, store: RATE_LIMIT_STORE, with: -> { render json: { error: "Too many attempts. Try again later." }, status: :too_many_requests }`.</li><li>`create`: `user = User.find_by(email: params[:email].to_s.strip.downcase)&.authenticate(params[:password].to_s)`. On success, `start_session(user)` and render `user_json`. Otherwise render the `401`.</li><li>`destroy`: `end_session` and `head :no_content`.</li></ul> |
| `app/controllers/api/me_controller.rb` | `before_action :require_authentication`, then `render json: current_user.slice(:id, :username, :email)`. |

Run the tests until they pass, then run `bin/rubocop -a`.

## 5. Phase 3 — Google through Auth0 (test first)

### 5.1 `Auth0Client` (`app/services/auth0_client.rb`)
| Step | Detail |
|------|--------|
| Test (red) `test/services/auth0_client_test.rb` | Generate an RSA key in the test (`OpenSSL::PKey::RSA.new(2048)`) and its JWKS (`JWT::JWK.new(key).export`). Stub `Auth0Client.fetch_jwks` and `Auth0Client.post_token` with `stub_singleton`. <ul><li>`authorize_url` contains every parameter from spec §4.4.</li><li>`exchange_code` returns the claims for a valid ID token.</li><li>It raises `Auth0Client::Error` for: a bad signature (another key), the wrong `iss`, the wrong `aud`, an expired `exp`, a nonce mismatch, or a non-200 response from the token endpoint.</li></ul> |
| Implement | <ul><li>`class Error < StandardError`.</li><li>`authorize_url(state:, nonce:, code_challenge:)` builds `https://#{AUTH0_DOMAIN}/authorize?…` with `URI.encode_www_form`.</li><li>`exchange_code(code:, code_verifier:, nonce:)` calls `post_token(...)`, raises on non-200, then runs `JWT.decode(id_token, nil, true, algorithms: ["RS256"], jwks: jwks_loader, iss: "https://#{domain}/", verify_iss: true, aud: client_id, verify_aud: true)` and compares `nonce`.</li><li>`fetch_jwks` is a `Net::HTTP.get` of `/.well-known/jwks.json`. It is cached in a class variable, and the cache is cleared on `kid_not_found`.</li><li>`post_token(params)` is a `Net::HTTP.post_form` to `/oauth/token`.</li><li>Network and JWT errors are wrapped in `Error`.</li></ul> These are the same HTTP primitives `IaService` uses, with no new gem. |

### 5.2 `Api::Auth::GoogleController`
| Step | Detail | AC |
|------|--------|----|
| Test (red) `test/controllers/api/auth/google_controller_test.rb` | <ul><li>**start**: `302`. Parse `Location` and assert its host and the `connection`, `response_type`, `code_challenge_method`, `state`, `nonce` and `redirect_uri` parameters. `Set-Cookie` for `td_oauth` has `httponly`, `secure`, `samesite=lax`, `max-age=600` and `path=/api/auth/google`.</li><li>**callback**: call `start` first in the same integration session (the cookie jar keeps `td_oauth`) and read `state` from its `Location`. Stub `Auth0Client.exchange_code`. Cover: success (`302` to `FRONTEND_URL/`, `td_session` set, `td_oauth` deleted), `error=access_denied`, a wrong `state`, no `td_oauth`, an expired `td_oauth` (`travel 11.minutes`), an unknown email (and `assert_no_difference "User.count"`), `email_verified: false`, and `exchange_code` raising.</li></ul> | AC-09…15 |
| Implement | <ul><li>**start**: create `state`, `nonce` and `verifier` with `SecureRandom.urlsafe_base64(32)`, and `challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)`. Set `cookies.encrypted[:td_oauth] = { value: { state:, nonce:, verifier:, at: Time.current.to_i }, httponly: true, secure: true, same_site: :lax, path: "/api/auth/google", expires: 10.minutes.from_now }`, then `redirect_to Auth0Client.authorize_url(...), allow_other_host: true`.</li><li>**callback**: follow spec §4.4 step 2 in order, deleting `td_oauth` first. Failures go to `redirect_to "#{FRONTEND_URL}/login?error=#{code}", allow_other_host: true`. Never redirect to a URL taken from params (no open redirect).</li></ul> | — |

## 6. Phase 4 — Feed and posts use the session (test first)
| Step | Detail | AC |
|------|--------|----|
| Fixture `embeddings.yml` | Add `two_profile`: `embeddable: two (User)`, `embedding_type: user_profile`, `embedding_model: test-model`, `vector` = `[1,0,0…]`. | — |
| Test (red) `test/controllers/api/feed_controller_test.rb` | Compare the **distinct** post ids: the feed wraps around (FR-FEED-07) so posts repeat, and fixture ids are hashes, so `id DESC` order is not `[two, one]`. <ul><li>Anonymous: both posts.</li><li>`?user_id=<two>` while anonymous gives the same as no parameter.</li><li>Signed in as `two`: ranked, so only post `one` appears (two's own post is excluded).</li></ul> | AC-16, 17 |
| Test (red) `posts_controller_test.rb` | <ul><li>`POST` anonymous: `401`, and `assert_no_difference "Post.count"`.</li><li>Signed in, with `user_id` of another user in the body: `201` and `Post.last.user == current user`.</li><li>Signed in with blank text: `422` with `errors`.</li></ul> | AC-18, 19 |
| Implement | <ul><li>`FeedController#index`: `FeedQuery.new(user: current_user, …)`. Delete the `user_id` line and update the comment.</li><li>`PostsController`: add `before_action :require_authentication, only: :create`, use `current_user.posts.new(post_params)`, and change `post_params` to `params.expect(post: [ :text, :media_type, :media_url ])`.</li></ul> | — |

## 7. Phase 5 — Origin check (Should)
- **Test (red)**, in a new `test/controllers/api/origin_check_test.rb`:
  - `POST /api/auth/sign_in` with `Origin: https://evil.example` → `403 { error: "Forbidden origin" }`.
  - With `Origin: http://localhost:5173` → normal handling.
  - With no `Origin` → normal handling.
  - `GET` requests are never blocked.
- **Implement**: a `before_action` in `ApplicationController` (or in `Authentication`) for `POST`, `PUT`, `PATCH` and `DELETE` only, which renders `403` when `request.origin` is present and differs from `FRONTEND_URL`. The Auth0 callback is a `GET`, so it is unaffected. CORS preflights are answered earlier by `Rack::Cors`.

## 8. Phase 6 — Frontend
| File | Change |
|------|--------|
| `src/api/auth.ts` (new) | <ul><li>`type User = { id: number; username: string; email: string }`.</li><li>`class InvalidCredentialsError`.</li><li>`signIn(email, password)` sends a `POST` with a JSON body; a `401` throws `InvalidCredentialsError`, and any other non-OK status throws `Error`.</li><li>`signOut()` sends `DELETE`.</li><li>`fetchMe(signal?)`: `200` returns the `User`, `401` returns `null`, and anything else throws.</li><li>All use `credentials: 'include'` and `API_URL` from `api/feed.ts`.</li></ul> |
| `src/api/feed.ts` | Add `credentials: 'include'`. Remove `userId` from `FetchFeedParams` and `fetchFeed`. |
| `src/api/posts.ts` | Add `credentials: 'include'`. |
| `src/hooks/useFeed.ts` | Remove the `userId` option and its dependency. |
| `src/auth/AuthProvider.tsx` (new) | <ul><li>Context `{ user, status, signIn, signOut }`.</li><li>On mount, `fetchMe` with an `AbortController`: success → `'signed-in'`, `null` → `'signed-out'`, and an error → `'signed-out'` (the feed still works anonymously).</li><li>`signIn` sets the user. `signOut` calls the API, ignores its errors, and clears the user.</li><li>The context and its types live in `src/auth/AuthContext.ts`, and `useAuth()` (which throws outside the provider) in `src/hooks/useAuth.ts`. Fast refresh needs a component file to export only components.</li></ul> |
| `src/main.tsx` | `<BrowserRouter><AuthProvider><App /></AuthProvider></BrowserRouter>`. |
| `src/App.tsx` | <ul><li>Add `<Route path="login" element={<LoginView />} />` as a sibling of the `/` layout route.</li><li>Render the feed layout as `<FeedView key={user?.id ?? 'anonymous'} />`, and only once `status !== 'loading'` (nothing is rendered until then; marked as a `shortcut:`, because `GET /api/me` is local and fast).</li></ul> The feed is then fetched once for the right user, and it reloads from the top whenever the user changes (spec §3.5). |
| `src/views/LoginView.tsx` (new) | <ul><li>Spec §3.2: a labelled email and password, and a submit button disabled with the text "Logging in…" while busy.</li><li>An error `role="alert"`, including the `?error=` messages from a small map.</li><li>The password is cleared on failure.</li><li>"Continue with Google" is an `<a href={`${API_URL}/api/auth/google`}>`.</li><li>`<Navigate to="/" replace />` when signed in.</li><li>The same card style as `ViewPost` (`rounded-2xl bg-white shadow-sm ring-1 ring-black/5`).</li></ul> |
| `src/views/FeedView.tsx` | Header right side (spec §3.3) using `useAuth()`. Nothing while loading; a `Log in` link; or `@username` plus a `Log out` button. Uses the existing focus-outline classes. |

## 9. Phase 7 — Documentation
- `README.md`:
  - Configuration: add `DEFAULT_USER_PASSWORD`, `JWT_SECRET`, `FRONTEND_URL` and the `AUTH0_*` names, without values.
  - A short "Auth0 setup" pointer to spec §6.5.
  - API table: the auth endpoints, and `user_id` removed from the feed.
  - Stack: bcrypt, jwt and Auth0.
- `intent/intent.md` §9.1: replace "pending approval" with the installed versions (`bcrypt 3.1.22`, `jwt 3.3.0`).
- Spec header: Status → Implemented, once Phase 9 passes.

## 10. Phase 8 — Quality gates (AGENTS.md "Finally")
1. `cd backend && bin/rails test`: all green.
2. `cd backend && bin/rubocop -a`, `bin/brakeman` and `bin/bundler-audit`: clean.
3. `cd frontend && npx oxlint --fix`, then `npm run lint`: clean.
4. `cd frontend && npm run build`: succeeds.
5. CI: `db:test:prepare` loads `schema.rb` and does not run the backfill migration, so CI needs no `DEFAULT_USER_PASSWORD`. Confirm this on the first push.

## 11. Phase 9 — Manual acceptance
Start `bin/rails db:migrate`, `bin/rails server -p 3000` and `npm run dev` with Auth0 configured (P-3). Use Chrome, Edge or Firefox.

| AC | Check |
|----|-------|
| AC-21 | `bin/rails runner 'p User.where(password_digest: nil).count'` prints `0`. Any seeded user signs in with `DEFAULT_USER_PASSWORD`. |
| AC-22 | Signed out: the header shows **Log in**. |
| AC-23, AC-29 | Sign in on `/login` → `/` with `@username` and **Log out**, and the feed reloads. A reload keeps the session. In DevTools → Application → Cookies, `td_session` shows HttpOnly ✓, Secure ✓ and SameSite Strict. |
| AC-24 | A wrong password shows the alert. The password is cleared and the email kept. |
| AC-25, AC-26 | Continue with Google using a matching account → signed in on `/`. A non-matching account → `/login` with "There is no account for this Google email." Cancelling on the consent screen → the cancelled message. |
| AC-27 | **Log out** → header shows **Log in**, and the feed reloads newest-first. |
| AC-28 | Opening `/login` while signed in redirects to `/`. |
| AC-30 | Keyboard only: Tab through the fields and buttons; Enter submits; the focus outline is visible. |
| AC-01…20 | Covered by the backend tests. |

## 12. Task order and files
1. P-1 → P-5.
2. Phase 1: test helper → passwords → `SessionToken` → `RevokedToken` → cookies/CORS → `Authentication`.
3. Phase 2: sessions + me.
4. Phase 3: `Auth0Client` → Google controller.
5. Phase 4: feed + posts.
6. Phase 5: Origin check.
7. Phase 6: frontend.
8. Phase 7: docs.
9. Phase 8: gates.
10. Phase 9: manual checks.

Files touched:

**Backend** (about 30 files):
- `Gemfile`, `Gemfile.lock`
- `config/application.rb`, `config/routes.rb`, `config/initializers/cors.rb`
- `app/controllers/application_controller.rb`, `app/controllers/concerns/authentication.rb`
- `app/controllers/api/{me,feed,posts}_controller.rb`, `app/controllers/api/auth/{sessions,google}_controller.rb`
- `app/services/{session_token,auth0_client}.rb`
- `app/models/{user,revoked_token}.rb`
- 2 migrations and `db/schema.rb`
- `script/ingestion.rb`
- `test/test_helper.rb`, `test/fixtures/{users,embeddings}.yml`
- 8 test files: `models/user`, `services/{session_token,auth0_client}`, `controllers/api/{me,feed,posts,origin_check}`, `controllers/api/auth/{sessions,google}`

**Frontend** (9 files):
- `api/{auth,feed,posts}.ts`
- `hooks/useFeed.ts`
- `auth/{AuthProvider.tsx,AuthContext.ts}`, `hooks/useAuth.ts`
- `main.tsx`, `App.tsx`
- `views/{LoginView,FeedView}.tsx`

**Docs**: `README.md`, `intent/intent.md`, the spec header and `checklist.md`.

**Local only, never committed**: `backend/.env`.

## 13. Risks and notes
- **No `minitest/mock`** in Minitest 6.1. Use the `stub_singleton` helper (§3.1) rather than adding a gem.
- **`Secure` cookies in tests**: Rails writes them over plain HTTP only in development (`always_write_cookie`). Every integration test that reads cookies must call `https!` first.
- **Rate-limit store**: it is a per-process `MemoryStore`. Clear it in test `setup`. Parallel workers are separate processes, so they don't interfere.
- **Email lower-casing**: the backfill migration could collide with the unique index if two emails differ only by case. The migration checks for that first and stops with a clear message. Seeded emails are already lower-case (`parameterize`).
- **dotenv in test**: `backend/.env` is also loaded in the test environment. The test helper uses `||=` (except `EMBED_MODEL`, which it forces), so tests never depend on real values and never call Auth0.
- **Encrypted `td_oauth` cookie**: it needs `secret_key_base`. Development and test derive it automatically; production uses credentials (`config/master.key` exists locally and is not committed).
- **Brakeman**: redirects use `FRONTEND_URL` and `AUTH0_DOMAIN` from the environment, never params. If Brakeman still flags `allow_other_host`, document the false positive in `config/brakeman.ignore` with a note rather than weakening the check.
- **Feed gating on `status`**: if `GET /api/me` is slow, the first paint of the feed waits for it. It's a local request, so acceptable for the PoC. Revisit if it is noticeable.
- **Auth0 development keys** show a warning on Google's consent screen and must not be used in production (spec §6.5).
