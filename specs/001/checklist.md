# Checklist — SPEC-001 View Post

Source: [plan.md](plan.md) · Spec: [001-view-post.md](001-view-post.md)

## Prerequisites
- [x] **P-1** Get approval for `react-router@8.4.0`, then install it with `--save-exact`.
- [x] **P-2** Run `bin/rails test` and record the baseline result.
  - Baseline (2026-10-19): `0 runs, 0 assertions, 0 failures` — every test file is an empty stub, so fixtures are never loaded.
  - `RAILS_ENV=test bin/rails db:fixtures:load` fails: `PG::NotNullViolation` on `embeddings.embedding_model`. The first real test will fail until the Phase 1 fixture fixes are done.

## Phase 1 — Backend (test first)
- [x] Fix `users.yml`: give both users a unique username and email.
- [x] Fix `posts.yml`: `one` is an image post with an https URL, `two` is text-only.
- [x] Fix `interactions.yml`: use a valid `event_type` (`like`).
- [x] Fix `embeddings.yml`: polymorphic `one (Post)`, plus model, type, dimensions and a 768-length vector.
- [x] Re-run `bin/rails test` and confirm the suite loads and passes.
- [x] Test (red): `show` returns `200` in `feed_json` shape (AC-17).
- [x] Test (red): `show` returns null media for a text-only post.
- [x] Test (red): `show` returns `404` with `{ "error": "Post not found" }` (AC-18).
- [x] `PostsController`: add `rescue_from RecordNotFound` that returns a 404 JSON body.
- [x] `PostsController#show`: render `Post.includes(:user).find(...).feed_json`.
- [x] Tests green, and `bin/rubocop -a` is clean.

## Phase 2 — Routing
- [x] `main.tsx`: wrap the app in `BrowserRouter`.
- [x] `App.tsx`: layout route `/` → `FeedView`, with an `index` child and a `posts/:postId` child.
- [x] Verify that `useParams` returns `postId` inside `FeedView`; if not, fall back to `useMatch`.

## Phase 3 — Data layer
- [x] `api/feed.ts`: export `API_URL`.
- [x] `api/posts.ts`: add `fetchPost(id, signal)` and `PostNotFoundError`.
- [x] `hooks/usePost.ts`: loading, ready, not-found and error states, instant render from feed data, abort on change, `retry`.

## Phase 4 — Components
- [x] `TextCard.tsx`: extract the gradient card from `PostCard`, with an optional `clamp` prop.
- [x] `icons.tsx`: Heart, Comment and Share as inline SVGs.
- [x] `ViewPost.tsx`: image or text card, full text, and like `0` / comment `0` / share buttons with no handlers.
- [x] `PostCard.tsx`: wrap the card in a `Link` to `/posts/:id` and use `TextCard`.
- [x] `MasonryGrid.tsx`: add `header` and `headerSpan` props for the pinned top-left block.
- [x] `FeedView.tsx`: read `postId`, call `usePost`, render the `PinnedPost` states, and filter the open post out of the grid.
- [x] `FeedView.tsx`: set `headerSpan = min(columns, 2)` and scroll to the top when `postId` changes.
- [x] `FeedView.tsx`: render the grid whenever a post is open, and make "Trends" a link to `/`.

## Phase 4b — UX additions (spec §3.6, added 2026-11-20)
- [x] `index.css`: add the `pin-in` keyframes and the `animate-pin-in` utility in `@theme`.
- [x] `ViewPost.tsx`: play the entrance animation with `motion-safe:animate-pin-in`.
- [x] `icons.tsx`: add `ArrowLeftIcon`.
- [x] `ViewPost.tsx`: add the Back button in the top-left corner (`navigate(-1)`, or `/` when there is no in-app history).
- [x] Re-run the Phase 5 quality gates.

## Phase 5 — Quality gates
- [x] `cd backend && bin/rails test`
- [x] `cd backend && bin/rubocop -a`
- [x] `cd frontend && npx oxlint --fix && npm run lint`
- [x] `cd frontend && npm run build`

## Phase 6 — Manual acceptance (375 / 800 / 1100 / 1400 px)
- [x] AC-01, AC-11: clicking a card opens and pins it and scrolls to the top. Clicking another card swaps the pinned post.
- [x] AC-02 to AC-04: image post, text-only post, and broken-image fallback.
- [x] AC-05, AC-06: icons show the `0` counts, and clicking them does nothing (no requests).
- [x] AC-07 to AC-09: deep link and reload, the 404 message, and the error with Retry.
- [x] AC-10: Back returns to the feed without reloading it.
- [x] AC-12: the open post does not appear in the grid.
- [x] AC-13, AC-14: View Post spans 2 columns at ≥ 768 px and the full width below that.
- [x] AC-15: infinite scroll still works while a post is open.
- [x] AC-16: keyboard navigation works and the icon buttons have accessible names.
- [x] AC-19: View Post animates in when opened or swapped, and appears instantly with reduced motion.
- [x] AC-20: the Back button returns to the previous page, or to `/` after a direct link.
