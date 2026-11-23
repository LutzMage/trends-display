# Clarification 001 — Clear the pinned post on log out

| Field | Value |
|-------|-------|
| ID | CL-001 |
| Spec | [SPEC-002 — Authentication](002-authentication.md) |
| Status | Approved (project owner) |
| Date | 2026-11-21 |
| Amends | Spec §3.3 (Header → Log out), §3.5 (Session lifetime), AC-27. Adds AC-31. |
| Checklist | [Phase 10](checklist.md#phase-10--clarification-001-clear-the-pinned-post-on-log-out) |

---

## 1. Problem
If a post is open (`/posts/:id`) when the user clicks **Log out**:
1. `signOut` in `frontend/src/auth/AuthProvider.tsx` clears the user.
2. `frontend/src/App.tsx` keys the feed by user (`key={user?.id ?? 'anonymous'}`), so the feed remounts and reloads anonymously.
3. The URL is still `/posts/:id`, so the `posts/:postId` route keeps the **same post pinned** above the anonymous feed.

That post was opened from the signed-in user's personalised feed. Once the user logs out, the feed is a different one, and the post no longer belongs on top of it.

## 2. Rule
**Logging out always lands on `/` with no pinned post**, and the feed reloads newest-first.

## 3. Behaviour
- **Applies to every log out from the UI.** Today that is only the header **Log out** button. Any future sign-out entry point (for example on an "Edit profile" view) follows the same rule.
- **Replace, don't push.** The app navigates to `/` with `replace`, so the open post's URL is not left as the current history entry. The browser's Back button goes to whatever came before it.
- **Order.** Navigate to `/` first, then end the session. The anonymous feed then mounts without a `postId`: it never requests the pinned post again, and it loads once.
- **Unchanged:**
  - Sign-in (email and Google) already lands on `/`.
  - Opening a post while signed out works as in SPEC-001.
  - Older history entries: pressing Back further can still reopen a post URL. That is normal browser history, not a pinned post carried across the log out.
- **Out of scope:** a session that expires or is revoked while a post is open. No log-out action happens, and the header only changes after the next `GET /api/me`.

## 4. Spec changes
These are applied by the first step of checklist Phase 10.

| Section | Change |
|---------|--------|
| §3.3 Header | "**Log out** calls `DELETE /api/auth/sign_out`, switches the header to 'Log in', **closes any open post (navigates to `/`)**, and reloads the feed from the top. See CL-001." |
| §3.5 Session lifetime | Add: "Signing out also closes the open post (CL-001)." |
| AC-27 | Keep the wording; add "(see CL-001)". |
| AC-31 (new) | *Given* I am signed in with a post open at `/posts/{id}`. *When* I click **Log out**. *Then* the URL is `/`, no post is pinned, the header shows **Log in**, and the feed reloads newest-first. |

## 5. Implementation notes
- Only `frontend/src/auth/AuthProvider.tsx` changes. `signOut` calls `navigate('/', { replace: true })` (from `useNavigate()`; `AuthProvider` already sits inside `BrowserRouter` in `main.tsx`), then calls the API and clears the user.
- The rule lives in `signOut`, not in the header button, so it holds "whenever the user logs out".
- `FeedView`, `App` and the backend do not change.

## 6. Verification
- The frontend has no test runner (plan §1), so the code is checked with `npx oxlint --fix`, `npm run lint` and `npm run build`.
- Backend tests are unaffected; `bin/rails test` still runs as a gate.
- Manual: AC-31, in Chrome, Edge or Firefox.
