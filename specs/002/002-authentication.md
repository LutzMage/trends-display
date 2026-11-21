# SPEC-002 — Authentication (email + password, and Google via Auth0)

| Field        | Value |
|--------------|-------|
| Spec ID      | SPEC-002 |
| Status       | Implemented |
| Branch       | `add-authentication` |
| Intent trace | FR-AUTH-02…07, FR-AUTH-08 (Google sign-in), NFR-06, NFR-07 |
| Deferred     | FR-AUTH-01 (sign-up / user creation), protected frontend views (§7) |
| Last updated | 2026-11-21 ([CL-001](clarification_001.md): log out clears the pinned post) |

---

## 1. Summary

Users can sign in with **email + password** or with **Google** (through Auth0). The backend issues its own **JWT** and stores it in an **HttpOnly, Secure, SameSite=Strict cookie**. The SPA never reads or stores the token. It asks `GET /api/me` who is signed in.

Once signed in, the feed is personalised for that user, which replaces the temporary `?user_id=` parameter. Creating a post requires a session. Every user gets a **required password**. In this iteration all existing users share one random password, kept in an environment variable. User creation, including through Google, is out of scope: a Google account can only sign in if its verified email matches an existing user.

### User stories
> As a **Browser**, I want to sign in with my email and password, or with my Google account, so that the feed is personalised for me.

> As a **Developer**, I want a reusable way to require a signed-in user, so that future views and endpoints (for example "Edit profile") can be protected with one line.

---

## 2. Scope

### 2.1 In scope
- A **Log in** page at `/login` with an email + password form and a **Continue with Google** button.
- `POST /api/auth/sign_in`, `DELETE /api/auth/sign_out` and `GET /api/me`.
- Google sign-in through Auth0: `GET /api/auth/google` and `GET /api/auth/google/callback`.
- A session JWT in an HttpOnly, Secure, SameSite=Strict cookie, with server-side revocation on sign-out.
- A required password for every user (`users.password_digest NOT NULL`), backfilled from an environment variable.
- `GET /api/feed` personalised for the signed-in user. Anonymous visitors get the newest-first feed. `?user_id=` is removed.
- `POST /api/posts` requires a session. The author is always the signed-in user.
- A header that shows **Log in**, or **@username** with **Log out**.
- A reusable backend guard (`require_authentication`) and a documented pattern for protected frontend views (§7).

### 2.2 Out of scope
- Sign-up and any user creation, including on first Google sign-in.
- Password reset, password change, MFA, "remember me", refresh tokens.
- Identity providers other than Google.
- Logging out of the Auth0 / Google SSO session.
- Linking or unlinking a Google account in the UI.
- Protected frontend views. None exist yet; §7 describes how they will work.
- A job that prunes expired rows from `revoked_tokens`.
- A frontend test runner.

---

## 3. UX and behaviour

### 3.1 Routes
| Path | Renders |
|------|---------|
| `/`, `/posts/:id` | The feed, as in SPEC-001. The header now shows the session state. |
| `/login` | The Log in page. If the user is already signed in, it redirects to `/`. |

`/login` is a sibling of the feed layout route, so the feed is not rendered behind it.

### 3.2 Log in page
- A centred card with the "Trends" title (a link to `/`), plus:
  - **Email** (`type="email"`, `autocomplete="email"`, required).
  - **Password** (`type="password"`, `autocomplete="current-password"`, required).
  - A **Log in** submit button. It is disabled and reads "Logging in…" while the request is in flight.
  - A divider ("or") and a **Continue with Google** button. It is a plain link to `${API_URL}/api/auth/google` (a full-page navigation), not a fetch.
- On success, the app navigates to `/` and the feed loads for the signed-in user.
- On failure, the message appears above the form in an element with `role="alert"`. The password field is cleared, and the typed email is kept.
- The page also shows the message for a `?error=` code from the Google callback:

| `error` | Message |
|---------|---------|
| `google_cancelled` | "Google sign-in was cancelled." |
| `no_account` | "There is no account for this Google email." |
| `email_unverified` | "Your Google email address is not verified." |
| `google_failed` | "Google sign-in failed. Please try again." |
| anything else | "Google sign-in failed. Please try again." |

- Every control has a visible label, can be reached with the keyboard, and shows a visible focus outline (NFR-08).

### 3.3 Header
The feed header keeps the "Trends" link (SPEC-001) and adds, on the right:

| Session state | Shows |
|---------------|-------|
| Loading (`GET /api/me` in flight) | Nothing, so the header does not flicker. |
| Signed out | A **Log in** link to `/login`. |
| Signed in | `@username` and a **Log out** button. |

**Log out** calls `DELETE /api/auth/sign_out`, switches the header to "Log in", **closes any open post (navigates to `/`)**, and reloads the feed from the top. See [CL-001](clarification_001.md).

### 3.4 Google sign-in (what the user sees)
1. The user clicks **Continue with Google** and leaves the app for Auth0's Google page.
2. They choose a Google account and consent.
3. They land back on `/`, signed in.
4. If they cancel, or the account cannot be used, they land on `/login` with one of the messages from §3.2.

### 3.5 Session lifetime
- A session lasts **24 hours** from sign-in. After that, `GET /api/me` returns `401` and the header shows **Log in**. There is no silent refresh.
- Reloading the page keeps the session, because the cookie survives reloads.
- The feed reloads from the top whenever the signed-in user changes (sign-in or sign-out), because personalisation changes.
- Signing out also closes the open post ([CL-001](clarification_001.md)).

---

## 4. Security model

### 4.1 Session token
| Property | Value |
|----------|-------|
| Format | JWT, `HS256` |
| Signing key | `JWT_SECRET` (env, at least 32 random bytes) |
| Claims | `sub` (user id, as a string), `jti` (random UUID), `iat`, `exp` (`iat` + 24 h) |
| Validation | Signature, `exp` (no leeway), a present `jti` that is not in `revoked_tokens`, and an existing user for `sub` |

The token is **never** included in a JSON body or a URL. It only travels in the cookie.

### 4.2 Session cookie
| Attribute | Value | Why |
|-----------|-------|-----|
| Name | `td_session` | |
| `HttpOnly` | yes | JavaScript cannot read the token (XSS cannot steal it). |
| `Secure` | yes | Sent over HTTPS only. Browsers treat `http://localhost` as secure, except Safari (§10). |
| `SameSite` | `Strict` | Not sent on cross-site requests, which blocks CSRF. |
| `Path` | `/` | |
| `Domain` | not set | Host-only cookie. |
| `Max-Age` | 86400 (24 h) | Matches the token's `exp`. |

`SameSite=Strict` works in development because `http://localhost:5173` (SPA) and `http://localhost:3000` (API) are the **same site**: ports are not part of the site. In production, the SPA and the API must also share a registrable domain, for example `app.example.com` and `api.example.com` (§10).

### 4.3 Sign-out and revocation
`DELETE /api/auth/sign_out`:
1. Records the token's `jti` and `exp` in `revoked_tokens`.
2. Expires the cookie.
3. Returns `204`.

A revoked token is rejected even if someone kept a copy. The endpoint is idempotent: it returns `204` with no session or an invalid one.

### 4.4 Google through Auth0 (OIDC Authorization Code flow + PKCE, backend-driven)
The backend is a **confidential client** (an Auth0 "Regular Web Application"). The browser never sees Auth0 tokens; the backend turns a verified Google identity into its own session cookie.

1. **Start**: `GET /api/auth/google`.
   1. Generate a random `state`, a random `nonce` and a PKCE `code_verifier`.
   2. Store them, with a timestamp, in an **encrypted** cookie `td_oauth`: HttpOnly, Secure, **SameSite=Lax**, Max-Age 600, `Path=/api/auth/google`.
   3. Redirect `302` to `https://{AUTH0_DOMAIN}/authorize` with these parameters:
      - `response_type=code`
      - `client_id`
      - `redirect_uri={AUTH0_CALLBACK_URL}`
      - `scope=openid email profile`
      - `connection=google-oauth2`
      - `state`
      - `nonce`
      - `code_challenge=BASE64URL(SHA256(code_verifier))`
      - `code_challenge_method=S256`

   `Lax` is required for `td_oauth`: the callback is a top-level navigation coming *from* Auth0 (a cross-site request), and a `Strict` cookie would not be sent on it.
2. **Callback**: `GET /api/auth/google/callback?code=…&state=…`.
   1. If Auth0 returned `error=access_denied`, fail with `google_cancelled`.
   2. Read and delete `td_oauth`. If it is missing or expired, or its `state` differs from the query, fail with `google_failed`.
   3. Exchange `code` at `https://{AUTH0_DOMAIN}/oauth/token` with `grant_type=authorization_code`, `client_id`, `client_secret`, `code_verifier` and `redirect_uri`. A non-200 response fails with `google_failed`.
   4. Verify the `id_token`, or fail with `google_failed`:
      - its RS256 signature against Auth0's JWKS (`https://{AUTH0_DOMAIN}/.well-known/jwks.json`, cached),
      - `iss == https://{AUTH0_DOMAIN}/`,
      - `aud` includes `AUTH0_CLIENT_ID`,
      - `exp` is not past,
      - `nonce` equals the stored nonce.
   5. If `email_verified` is not `true`, fail with `email_unverified`.
   6. Find the user by email, ignoring case. If there is none, fail with `no_account`. **No user is created.**
   7. Start a session (§4.1, §4.2) and redirect `302` to `{FRONTEND_URL}/`.

   Every failure redirects `302` to `{FRONTEND_URL}/login?error=<code>` and never sets a session.

### 4.5 CSRF and CORS
- The SPA calls the API cross-origin and same-site, so every `fetch` uses `credentials: 'include'`.
- CORS allows **only** `FRONTEND_URL` with `credentials: true`. A wildcard origin is not allowed with credentials.
- CSRF protection:
  - `SameSite=Strict` means the session cookie is never sent from another site.
  - Request bodies are JSON (`Content-Type: application/json`), which a cross-origin HTML form cannot send without a CORS preflight.
- **Should (defence in depth)**: state-changing requests (`POST`, `PUT`, `PATCH`, `DELETE`) whose `Origin` header is present and is not `FRONTEND_URL` get `403 { "error": "Forbidden origin" }`. Requests without `Origin`, such as curl or tests, are allowed.

### 4.6 Passwords
- `has_secure_password` (bcrypt). Only `users.password_digest` is stored, and it becomes **NOT NULL**.
- Existing users are backfilled with the digest of one shared random password, read from `DEFAULT_USER_PASSWORD` (§6.4). The seed script uses the same variable for new users.
- Passwords are never logged. The existing `filter_parameters` entry `:passw` already covers `password`.
- A wrong password and an unknown email return the **same** `401` and message, so the API does not reveal which emails exist.

### 4.7 Rate limiting
`POST /api/auth/sign_in` is limited to **10 requests per 3 minutes per IP**, using Rails 8's built-in `rate_limit` (no gem). Above that, it returns `429 { "error": "Too many attempts. Try again later." }`.

The limiter uses its own `ActiveSupport::Cache::MemoryStore` (`store:` option), because the test environment's cache store is `:null_store`. This store is per process, which is acceptable for the PoC (§10).

---

## 5. API

All responses are JSON. "User" means `{ "id": 7, "username": "alice", "email": "alice@example.com" }`.

| Method | Path | Auth | Request | Responses |
|--------|------|------|---------|-----------|
| POST | `/api/auth/sign_in` | — | `{ "email", "password" }` | `200` User + `Set-Cookie: td_session` · `401 { "error": "Invalid email or password" }` (also when a field is missing) · `429` |
| DELETE | `/api/auth/sign_out` | optional | — | `204` + expired `td_session` cookie |
| GET | `/api/me` | required | — | `200` User · `401 { "error": "Not authenticated" }` |
| GET | `/api/auth/google` | — | — | `302` to Auth0 + `Set-Cookie: td_oauth` |
| GET | `/api/auth/google/callback` | — | `?code&state` or `?error` | `302` to `{FRONTEND_URL}/` + `td_session`, or `302` to `{FRONTEND_URL}/login?error=<code>` |
| GET | `/api/feed?cursor=&limit=` | optional | — | As before. Ranked for the signed-in user; newest first when anonymous. **`user_id` is removed and ignored.** |
| POST | `/api/posts` | **required** | `{ "post": { "text", "media_type?", "media_url?" } }` | `201` · `401` · `422`. **`user_id` is no longer accepted**; the author is the signed-in user. |
| GET | `/api/posts/:id` | — | — | Unchanged (SPEC-001). |

Any endpoint guarded by `require_authentication` returns `401 { "error": "Not authenticated" }` when there is no valid session.

---

## 6. Implementation notes

### 6.1 Backend
| File | Change |
|------|--------|
| `Gemfile` | Uncomment `bcrypt ~> 3.1.7`. Add `jwt` (§6.6). |
| `config/application.rb` | API-only apps have no cookie middleware: add `config.middleware.use ActionDispatch::Cookies`. |
| `config/initializers/cors.rb` | `origins ENV.fetch("FRONTEND_URL")` and `credentials: true`. |
| `app/controllers/application_controller.rb` | `include ActionController::Cookies` and `include Authentication`. |
| `app/controllers/concerns/authentication.rb` (new) | `current_user` (decode `td_session`, check `revoked_tokens`, load the user, memoise), `require_authentication` (for `before_action`; renders the 401), `start_session(user)` (issues the token, sets the cookie), and `end_session` (revokes the token, deletes the cookie). Optionally the `Origin` check from §4.5. |
| `app/services/session_token.rb` (new) | `SessionToken.issue(user)` returns the JWT; `SessionToken.decode(token)` returns the claims or `nil`. Uses `JWT_SECRET` and a `TTL = 24.hours` constant. |
| `app/services/auth0_client.rb` (new) | In the style of `IaService`: `authorize_url(state:, nonce:, code_challenge:)` and `exchange_code(code:, code_verifier:, nonce:)`, which return verified ID-token claims or raise `Auth0Client::Error`. Uses `Net::HTTP` (as `IaService` does) and `jwt` for JWKS verification. This is the single seam that tests stub. |
| `app/controllers/api/auth/sessions_controller.rb` (new) | `create` (sign in, rate limited) and `destroy` (sign out). |
| `app/controllers/api/auth/google_controller.rb` (new) | `start` and `callback` (§4.4). |
| `app/controllers/api/me_controller.rb` (new) | `show`, behind `before_action :require_authentication`. |
| `app/controllers/api/feed_controller.rb` | `FeedQuery.new(user: current_user, …)`. Delete the `user_id` line. `FeedQuery` is unchanged. |
| `app/controllers/api/posts_controller.rb` | `before_action :require_authentication, only: :create`. Build the post with `current_user.posts.new(post_params)`, and drop `:user_id` from `post_params`. |
| `app/models/user.rb` | `has_secure_password`. Store emails lower-cased (`normalizes :email, with: ->(e) { e.strip.downcase }`), so lookups by email ignore case. |
| `app/models/revoked_token.rb` (new) | `jti` (unique) and `expires_at`. |
| `config/routes.rb` | Under `namespace :api`: the routes from §5. |
| `script/ingestion.rb` | `user_for` sets `u.password = ENV.fetch("DEFAULT_USER_PASSWORD")` for new users. |
| `test/fixtures/users.yml` | Add `password_digest: <%= BCrypt::Password.create("password") %>`. Lower-case emails. |

### 6.2 Data
| Migration | Change |
|-----------|--------|
| `BackfillUserPasswords` | Compute **one** `BCrypt::Password.create(ENV.fetch("DEFAULT_USER_PASSWORD"))` and `update_all(password_digest: …)` where it is null. Lower-case existing emails. Then `change_column_null :users, :password_digest, false`. It fails loudly if the variable is missing. |
| `CreateRevokedTokens` | `revoked_tokens(jti string NOT NULL unique, expires_at datetime NOT NULL, timestamps)`. |

### 6.3 Frontend
| File | Change |
|------|--------|
| `src/api/auth.ts` (new) | `type User`; `signIn(email, password)` (throws `InvalidCredentialsError` on 401, a generic `Error` otherwise); `signOut()`; `fetchMe()` (returns `User \| null`, where 401 means `null`). All use `credentials: 'include'`. |
| `src/api/feed.ts`, `src/api/posts.ts` | Add `credentials: 'include'`. Remove the `userId` parameter from `fetchFeed`. |
| `src/hooks/useFeed.ts` | Remove `userId`. |
| `src/auth/AuthProvider.tsx` (new) | React context (no library) exposing `{ user, status: 'loading' \| 'signed-in' \| 'signed-out', signIn, signOut }`. Calls `fetchMe()` once on mount. Also exports `useAuth()`. |
| `src/main.tsx` | Wrap `<App />` in `<AuthProvider>` inside `<BrowserRouter>`. |
| `src/App.tsx` | Add `<Route path="login" element={<LoginView />} />` as a sibling of the feed layout route. |
| `src/views/LoginView.tsx` (new) | §3.2. Uses `useAuth().signIn`, `useNavigate` and `useSearchParams` (for `error`). Redirects to `/` when `status === 'signed-in'`. |
| `src/views/FeedView.tsx` | Header right side (§3.3). Reload the feed when `user?.id` changes, for example by keying the feed state on it. |

### 6.4 Configuration
Everything lives in `backend/.env`, which is ignored by git (`/.env*`) and **never committed**. The README lists the variable names without their values.

| Variable | Value |
|----------|-------|
| `DEFAULT_USER_PASSWORD` | Random, generated at implementation time (for example `openssl rand -base64 18`). It is shared privately with the project owner. |
| `JWT_SECRET` | At least 32 random bytes (for example `openssl rand -hex 32`). |
| `AUTH0_DOMAIN` | Tenant domain, for example `trends-display.us.auth0.com`. |
| `AUTH0_CLIENT_ID` / `AUTH0_CLIENT_SECRET` | From the Auth0 application. |
| `AUTH0_CALLBACK_URL` | `http://localhost:3000/api/auth/google/callback` |
| `FRONTEND_URL` | `http://localhost:5173` (used by CORS, redirects and the `Origin` check). |

The test environment uses fixed dummy values. Tests never reach Auth0. The frontend needs no new variables.

Rails writes `Secure` cookies over plain HTTP only when `always_write_cookie` is enabled, which is the default in **development** and not in test. Integration tests therefore call `https!` before making requests.

### 6.5 Auth0 setup (manual, by the project owner)
1. Create an Auth0 tenant (the free plan is enough).
2. Create an application of type **Regular Web Application**.
3. Set **Allowed Callback URLs** to `http://localhost:3000/api/auth/google/callback`.
4. Under **Authentication → Social**, enable **google-oauth2** for this application. Auth0's development keys are acceptable for the PoC; production needs your own Google OAuth client.
5. Copy the domain, client ID and client secret into `backend/.env`.
6. Make sure the Google account you will test with has the same email as an existing user. Set it with `bin/rails runner`, since there is no sign-up.

### 6.6 Dependencies requiring approval
Under `AGENTS.md`, these must be **approved before installation**:

| Dependency | Why | Notes |
|------------|-----|-------|
| `bcrypt` (gem) `~> 3.1.7` | `has_secure_password` | Already commented out in the `Gemfile`, and listed in intent §12. |
| `jwt` (gem, ruby-jwt) | Signs and verifies our HS256 session token, and verifies Auth0's RS256 ID token against its JWKS. | Pin an exact release that is at least 2 weeks old at implementation time. |

No npm packages are added.

**Considered and rejected**:
- `omniauth-auth0` + `omniauth-rails_csrf_protection`: they need Rails session middleware and CSRF-token form POSTs, which an API-only app does not have, for a flow that fits in one small service.
- `@auth0/auth0-react`: it keeps the Auth0 tokens in the browser, which defeats the HttpOnly cookie.

---

## 7. Future protected views (designed, not built)
No view needs protection yet, so nothing below is implemented in this spec. It records how protection will work so that later specs (for example "Edit profile") only need to add a few lines.

- **API**: add `before_action :require_authentication` to the controller or action. It already returns `401` and exposes `current_user`.
- **Frontend**: add a `RequireAuth` layout route, then nest protected routes under it.
  - It renders `<Outlet />` when `status === 'signed-in'` and nothing while `status === 'loading'`.
  - Otherwise it redirects to `/login?redirect=<current path>`.
- **Redirect back**: `LoginView` then navigates to `redirect` instead of `/`, accepting only paths that start with `/` to avoid open redirects. The Google flow carries the same value through the `td_oauth` cookie.

---

## 8. Acceptance criteria

### API
| # | Given | When | Then |
|---|-------|------|------|
| AC-01 | A user with a known password | `POST /api/auth/sign_in` with the right email and password | `200` with the User. `Set-Cookie: td_session=…; Path=/; Max-Age=86400; Secure; HttpOnly; SameSite=Strict`. The body contains no token. |
| AC-02 | — | Sign in with an email in different letter case | It succeeds (emails are case-insensitive). |
| AC-03 | — | Sign in with a wrong password, an unknown email or a missing field | `401 { "error": "Invalid email or password" }` in every case. No cookie. |
| AC-04 | 10 sign-in attempts from one IP within 3 minutes | An 11th attempt | `429 { "error": "Too many attempts. Try again later." }` |
| AC-05 | A valid session cookie | `GET /api/me` | `200` with the User. |
| AC-06 | No cookie, or an expired, tampered or revoked token, or a token for a deleted user | `GET /api/me` | `401 { "error": "Not authenticated" }` |
| AC-07 | A valid session | `DELETE /api/auth/sign_out` | `204`. The cookie is expired, and a later request with the old token gets `401`. |
| AC-08 | No session | `DELETE /api/auth/sign_out` | `204` |
| AC-09 | — | `GET /api/auth/google` | `302` to `https://{AUTH0_DOMAIN}/authorize` with `connection=google-oauth2`, `response_type=code`, `code_challenge_method=S256`, `state`, `nonce` and `redirect_uri`. Sets `td_oauth` (HttpOnly, Secure, SameSite=Lax, Max-Age 600). |
| AC-10 | A valid `td_oauth`, and Auth0 returns a verified email that matches a user | Callback | Session cookie set, `td_oauth` deleted, `302` to `{FRONTEND_URL}/`. |
| AC-11 | — | Callback with `error=access_denied` | `302` to `/login?error=google_cancelled`. No session. |
| AC-12 | `td_oauth` is missing or expired, or `state` does not match | Callback | `302` to `/login?error=google_failed`. No session. |
| AC-13 | Auth0 returns a verified email that matches no user | Callback | `302` to `/login?error=no_account`. **No user is created.** |
| AC-14 | Auth0 returns `email_verified: false` | Callback | `302` to `/login?error=email_unverified`. |
| AC-15 | The code exchange fails, or the ID token has a bad signature, `iss`, `aud`, `exp` or `nonce` | Callback | `302` to `/login?error=google_failed`. |
| AC-16 | Signed in, with a profile embedding | `GET /api/feed` | Ranked for that user, excluding their own posts (FR-FEED-04/06). A `user_id` parameter is ignored. |
| AC-17 | Anonymous | `GET /api/feed` | Newest first (FR-FEED-05). |
| AC-18 | Anonymous | `POST /api/posts` | `401 { "error": "Not authenticated" }`. No post is created. |
| AC-19 | Signed in | `POST /api/posts` with another `user_id` in the body | `201`. The post belongs to the signed-in user. |
| AC-20 | — | A `POST`/`DELETE` with `Origin: https://evil.example` (**Should**) | `403 { "error": "Forbidden origin" }` |
| AC-21 | Migrations have run | Inspect `users` | Every row has a `password_digest`, and the column is `NOT NULL`. Any seeded user can sign in with `DEFAULT_USER_PASSWORD`. |

### UI (manual)
| # | Given | When | Then |
|---|-------|------|------|
| AC-22 | Signed out, on `/` | I look at the header | A **Log in** link. |
| AC-23 | On `/login` | I submit a valid email and password | I land on `/`. The header shows `@username` and **Log out**, and the feed reloads from the top. |
| AC-24 | On `/login` | I submit a wrong password | "Invalid email or password" appears in a `role="alert"` element. The password field is cleared and the email is kept. |
| AC-25 | On `/login` | I click **Continue with Google** and finish with a matching account | I go through Auth0/Google and land on `/`, signed in. |
| AC-26 | Google sign-in fails (cancelled, no account, unverified) | I land on `/login?error=…` | The matching message from §3.2 is shown. |
| AC-27 | Signed in | I click **Log out** | The header shows **Log in**, and the feed reloads newest-first (see CL-001). |
| AC-28 | Signed in | I open `/login` | I am redirected to `/`. |
| AC-29 | Signed in | I reload the page | I am still signed in. |
| AC-30 | Keyboard only | I use the Log in page | Every field and button is reachable with Tab, has a visible label and focus outline, and Enter submits the form. |
| AC-31 | Signed in, with a post open at `/posts/{id}` | I click **Log out** | The URL is `/`, no post is pinned, the header shows **Log in**, and the feed reloads newest-first ([CL-001](clarification_001.md)). |

---

## 9. Testing and verification

**Automated (backend, test first)**. Minitest integration tests call `https!` so that `Secure` cookies are written (§6.4).
- `test/controllers/api/auth/sessions_controller_test.rb`: AC-01 to AC-04, AC-07, AC-08. For AC-01, assert the cookie attributes from the `Set-Cookie` header.
- `test/controllers/api/me_controller_test.rb`: AC-05 and AC-06. Build expired and tampered tokens with `SessionToken` and `travel_to`.
- `test/controllers/api/auth/google_controller_test.rb`: AC-09 to AC-15. `Auth0Client.exchange_code` is stubbed (it returns claims or raises `Auth0Client::Error`), so tests never reach the network.
- `test/services/auth0_client_test.rb`: ID-token verification (signature, `iss`, `aud`, `exp`, `nonce`) with a locally generated RSA key and JWKS.
- `test/controllers/api/feed_controller_test.rb`: AC-16 and AC-17.
- `test/controllers/api/posts_controller_test.rb`: AC-18 and AC-19.
- `test/models/user_test.rb`: `has_secure_password`, a required password, and email normalisation.
- AC-20 (Should), if implemented.
- `cd backend && bin/rails test` and `bin/rubocop -a`.

**Static checks (frontend)**: `cd frontend && npm run lint` and `npm run build`.

**Manual**: run `bin/rails server -p 3000` and `npm run dev` with a configured Auth0 tenant, then go through AC-22 to AC-31 in Chrome, Edge or Firefox (not Safari, §10). AC-21 is checked with `bin/rails runner`.

---

## 10. Known limitations and risks
- **Safari** does not accept `Secure` cookies on `http://localhost`, so local development needs Chrome, Edge or Firefox. Production must use HTTPS.
- **Same-site deployment**: `SameSite=Strict` requires the SPA and the API to share a registrable domain. Hosting them on unrelated domains would need a different cookie strategy.
- **Auth0 SSO session**: sign-out ends only the app session. The Auth0/Google session remains, so the next **Continue with Google** may sign in without a prompt.
- **Shared password**: every existing user has the same password until password change or reset exists. Acceptable for an internal PoC; `DEFAULT_USER_PASSWORD` must stay private.
- **Revoked tokens** accumulate until a pruning job exists. Rows can be deleted once `expires_at` is past.
- **Rate limiting** uses an in-process memory store, so it resets on restart and is not shared between processes.
- **Fixed 24 h sessions**: there is no refresh. A user active at hour 23 is signed out at hour 24.
- **Demo steering**: `script/fake_likes.rb` targets a user id. To see the effect, sign in as that user. `?user_id=` no longer exists.
