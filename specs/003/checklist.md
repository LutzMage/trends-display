# Checklist — SPEC-003 Post interactions

Source: [plan.md](plan.md) · Spec: [003-interactions.md](003-interactions.md)

## Prerequisites
- [x] **P-1** Run `bin/rails test` and record the baseline (expected: 65 runs, 200 assertions, 0 failures).
  - Baseline (2026-11-23, after `bundle install` for image_processing 2.2.0): `65 runs, 200 assertions, 0 failures`.
- [x] **P-2** Confirm the branch is `feature/add-interactions` and the tree is clean.
  - 2026-11-23: on `feature/add-interactions`; the only change is the new `specs/003/`.
- [x] **P-3** Get approval to copy the six service logos' SVG paths from Simple Icons (CC0). No package.
  - Approved 2026-11-23.
- [x] **P-4** Count duplicate `like`/`save` rows in the dev database (read-only), and report the number before the Phase 1 migration.
  - 2026-11-23: 10 likes, 0 saves, **0 duplicates**. The migration will delete nothing.

## Phase 1 — Data model (test first)
- [x] Test (red): `Comment` validations, strip, the `comment` interaction on create, and `api_json` (AC-09, AC-10).
- [x] `comments.yml`: three comments on `posts(:one)`, 3, 2 and 1 days old.
- [x] Migration `CreateComments`, the `Comment` model, and `has_many :comments` on `Post` and `User`.
- [x] Test (red): `download` type enqueues a profile update; destroying a like or save enqueues one; a duplicate like or save is rejected; a duplicate click is not (AC-15).
- [x] Migration `AddUniqueLikeAndSaveToInteractions`: delete duplicates (oldest kept, count printed), then the partial unique index.
- [x] `Interaction`: the `download` enum value and `after_destroy_commit`. `UserProfileBuilder::WEIGHTS`: `download` 1.5.
  - Done as one `after_commit … on: [ :create, :destroy ]`: separate `after_create_commit` and `after_destroy_commit` callbacks for the same method override each other.
- [x] Tests green, and `bin/rubocop -a` is clean.
  - 2026-11-23: `78 runs, 222 assertions, 0 failures`.

## Phase 2 — Post detail (test first)
- [x] Test (red): `GET /api/posts/:id` returns `like_count`, `comment_count`, `liked` and `saved`, both anonymous and signed in; update the exact-keys test (AC-01, AC-02).
- [x] `PostScoped` concern: move the `404` rescue out of `PostsController`, and add the lazy `current_post`.
- [x] `Post#detail_json(viewer)` and `PostsController#show`.
- [x] Tests green, and `bin/rubocop -a` is clean.
  - 2026-11-23: `81 runs, 232 assertions, 0 failures`.

## Phase 3 — Like and save (test first)
- [x] Test (red): likes `PUT`/`DELETE`, idempotent with one job each; anonymous `401`; unknown post `404`; foreign origin `403` (AC-03, AC-04, AC-06, AC-07, AC-16).
- [x] Test (red): saves `PUT`/`DELETE`; anonymous `401`; unknown post `404` (AC-05, AC-06, AC-07).
- [x] Routes `resource :like` and `resource :save`, plus the `InteractionToggle` concern.
- [x] `Api::LikesController` and `Api::SavesController`.
- [x] Tests green, and `bin/rubocop -a` is clean.
  - 2026-11-23: `90 runs, 283 assertions, 0 failures`.

## Phase 4 — Comments and interactions endpoints (test first)
- [x] Test (red): comments `GET` newest first; `POST` `201`/`422`; anonymous `401`; unknown post `404` (AC-06…AC-10).
- [x] `Api::CommentsController` and its routes.
- [x] Test (red): interactions `click`/`share`/`download` → `201`; other types → `422`; anonymous `401`; unknown post `404` (AC-06, AC-07, AC-11, AC-12).
- [x] `Api::InteractionsController` and its route.
- [x] Tests green, and `bin/rubocop -a` is clean.
  - 2026-11-23: `100 runs, 371 assertions, 0 failures`.

## Phase 5 — Download (test first)
- [x] Test (red): `ImageDownload`: allowlist (no request for other hosts or `http`), status, type, network error, and the 10 MB cap (AC-14).
- [x] `ImageDownload` service.
  - Live check 2026-11-23: a seeded `cdn.bsky.app` image downloads (image/webp, 546 KB); `example.com` is refused without a request.
- [x] Test (red): `GET /api/posts/:id/download` → `200` attachment, `404` text-only, `422` host not allowed, `502` unavailable, `404` unknown post (AC-07, AC-13, AC-14).
- [x] Route and `PostsController#download`.
- [x] Tests green, and `bin/rubocop -a` is clean.
  - 2026-11-23: `112 runs, 408 assertions, 0 failures`.

## Phase 6 — Frontend data layer
- [ ] `api/posts.ts`: `PostStats` and `Post` types; `fetchPost` returns the stats.
- [ ] `api/interactions.ts`: `setLiked`, `setSaved`, `fetchComments`, `createComment`, `recordInteraction` and `downloadImage`.
- [ ] `hooks/usePost.ts`: `update(patch)`.
- [ ] `hooks/useComments.ts`.

## Phase 7 — Frontend components
- [ ] `icons.tsx`: `DownloadIcon`, `BookmarkIcon`, `CloseIcon` and the six service logos.
- [ ] `Avatar.tsx`.
- [ ] `CommentsSection.tsx`.
- [ ] `ShareDialog.tsx`.
- [ ] `PostActions.tsx`.
- [ ] `ViewPost.tsx` (actions, comments, `click` recording) and `FeedView.tsx` (`PinnedPost` passes `update`).

## Phase 8 — Documentation
- [ ] `intent/intent.md`: spec §6.5 changes, v0.3.
- [ ] `README.md`: features, new endpoints, `DOWNLOAD_HOSTS`.

## Phase 9 — Quality gates
- [ ] `cd backend && bin/rails test`
- [ ] `cd backend && bin/rubocop -a && bin/brakeman && bin/bundler-audit`
- [ ] `cd frontend && npx oxlint --fix && npm run lint`
- [ ] `cd frontend && npm run build`
- [ ] Push, and confirm CI is green (only when the owner asks).

## Phase 10 — Manual acceptance (Chrome, Edge or Firefox; 375 and 1400 px)
- [ ] AC-17: action-row order; no Download on a text-only post.
- [ ] AC-18, AC-19: Like (pink, count ±1) and Save toggle, and survive a reload.
- [ ] AC-20: signed out, Like, Save and Comment go to `/login`; comments are visible with "Log in to comment".
- [ ] AC-21: 2 comments, View all / Show less, scroll box, "No comments yet."
- [ ] AC-22: posting a comment with Enter; Post disabled when blank; 250-character limit.
- [ ] AC-23: Share modal targets, Copy link, closing, and focus back on Share.
- [ ] AC-24: Download saves `trends-post-{id}.{ext}`, and shows the alert when the API is down.
- [ ] AC-25: one `click` per opening, plus `share` and `download` rows; nothing when signed out.
- [ ] AC-26: like or save with the API down reverts and shows the alert.
- [ ] AC-27: keyboard only, `aria-pressed`, and the modal keeps focus.
- [ ] Spec status → Implemented.
