# Implementation Plan — SPEC-001 View Post

| Field | Value |
|-------|-------|
| Spec | [001-view-post.md](001-view-post.md) |
| Intent | [intent/intent.md](../../intent/intent.md): FR-INT-01, FR-FEED-08 |
| Branch | `add-post-view` |
| Status | Ready for implementation |

## 1. Context
SPEC-001 adds a **View Post** that is pinned in the top-left of the feed grid and opened by clicking a card. It shows the image (or text card), the full text, and like `0` / comment `0` / share icons that do nothing yet. The plan follows the project rules:

- **AGENTS.md**: read the intent and the spec first. Write the **test first**. Never install a dependency without approval. Finish by running unit tests and linters (with autofix).
- **Intent NFR-09**: backend quality gates are Minitest + RuboCop. Frontend quality gates are oxlint + the `tsc` build.
- **Intent NFR-08**: accessibility (alt text, `role="alert"`, keyboard reachability).
- **Intent NFR-10**: English for code, identifiers and UI text.
- **Intent §12**: dependencies need approval.

**Testing approach (decided)**: test-first applies to the **backend**. The frontend has no test runner, and adding one is out of scope for SPEC-001. Frontend work is therefore verified with `npm run lint`, `npm run build` (tsc) and the manual acceptance checklist in §8.

## 2. Prerequisites and approvals
| # | Item | Action |
|---|------|--------|
| P-1 | `react-router@8.4.0` (released 2026-09-15; needs Node ≥ 22.22, local is 24.16) | **Ask for approval**, then run `cd frontend && npm install react-router@8.4.0 --save-exact`. 8.5.0 was released 2026-10-19 and is too new to adopt. |
| P-2 | Test-suite baseline | Run `cd backend && bin/rails test` before changing anything and record the result. |
| P-3 | Broken fixtures (expected to break P-2) | `fixtures :all` loads every fixture, and the current scaffolds violate DB constraints and enums. Fix them as part of Phase 1 (see 3.1). |

## 3. Phase 1 — Backend (test first)

### 3.1 Repair fixtures (needed for any test to run)
| File | Problem | Fix |
|------|---------|-----|
| `test/fixtures/users.yml` | Both rows use `MyString` for username and email, which breaks the unique indexes. | `one`: `alice` / `alice@example.com`. `two`: `bob` / `bob@example.com`. `password_digest` removed. |
| `test/fixtures/posts.yml` | `media_type: MyString` is not a valid enum value. | `one`: an image post (`media_type: image`, `media_url: https://example.com/one.jpg`, `user: one`). `two`: a text-only post (no media columns, `user: two`). |
| `test/fixtures/interactions.yml` | `event_type: MyString` is not a valid enum value. | `event_type: like`. |
| `test/fixtures/embeddings.yml` | Invalid polymorphic reference. `vector` and `embedding_model` (both NOT NULL) are missing. | `embeddable: one (Post)`, `embedding_type: text`, `embedding_model: test-model`, `dimensions: 3`, and `vector: <%= ([0.0] * 768).to_json %>`. |
| `test/fixtures/feed_items.yml` | Valid. | No change. |

Re-run `bin/rails test`. The suite should load and pass, since the existing tests are empty stubs.

### 3.2 Write failing tests: `test/controllers/api/posts_controller_test.rb`
| Test | Assertion | Spec |
|------|-----------|------|
| `show returns the post in feed shape` | `GET /api/posts/:id` for `posts(:one)` returns `200`. The JSON keys are exactly `id, text, media_type, media_url, created_at, user`, `user` equals `{ "id", "username" }`, and `media_type == "image"`. | AC-17 |
| `show returns text-only posts with null media` | `posts(:two)` returns `200` with `media_type` and `media_url` both `nil`. | AC-17, AC-03 |
| `show returns 404 for an unknown post` | `GET /api/posts/0` returns `404` with body `{ "error" => "Post not found" }`. | AC-18 |

Run the tests and confirm they fail (red). Today the endpoint renders the raw model with no `user`, and its 404 has a different body.

### 3.3 Implement: `app/controllers/api/posts_controller.rb`
- Add `rescue_from ActiveRecord::RecordNotFound` → `render json: { error: "Post not found" }, status: :not_found`.
- `show`: `render json: Post.includes(:user).find(params[:id]).feed_json`. Reuse `Post#feed_json` ([backend/app/models/post.rb](../../backend/app/models/post.rb)) rather than adding a serializer.
- Leave `create` unchanged.

Run the tests again; they should pass. Then run `bin/rubocop -a`.

## 4. Phase 2 — Frontend routing foundation (after P-1)
| File | Change |
|------|--------|
| `frontend/src/main.tsx` | Wrap `<App />` in `<BrowserRouter>` (import from `react-router`). |
| `frontend/src/App.tsx` | `<Routes><Route path="/" element={<FeedView />}><Route index element={null} /><Route path="posts/:postId" element={null} /></Route></Routes>`. Because the layout route stays mounted, the feed state survives navigation (AC-10). `FeedView` needs no `<Outlet />`. |

Check: in React Router, child params are merged into the parent match, so `useParams()` inside `FeedView` returns `postId`. If that turns out not to hold, use `useMatch('/posts/:postId')` instead.

## 5. Phase 3 — Frontend data layer
| File | Change |
|------|--------|
| `frontend/src/api/feed.ts` | `export` the existing `API_URL` constant so it can be reused. Nothing else changes. |
| `frontend/src/api/posts.ts` (new) | `export class PostNotFoundError extends Error {}` and `fetchPost(id: number, signal?: AbortSignal): Promise<FeedPost>`. A `404` throws `PostNotFoundError`, and any other non-OK status throws `Error(\`Post request failed (${status})\`)`, following the pattern in `fetchFeed`. |
| `frontend/src/hooks/usePost.ts` (new) | `usePost(id: number \| null, initial?: FeedPost)` → `{ post, status: 'loading' \| 'ready' \| 'not-found' \| 'error', error, retry }`. |

`usePost` details, following `useFeed`'s `AbortController` pattern in [useFeed.ts](../../frontend/src/hooks/useFeed.ts):
- The effect depends on `[id, attempt]` only. `initial` is read through a ref so that a new object identity does not trigger a refetch.
- When the effect starts, set `post = initial ?? null` and `status = initial ? 'ready' : 'loading'`. This gives the instant render required by spec §3.5.
- Success sets `post` and `'ready'`. A `PostNotFoundError` sets `'not-found'`. Any other error sets `'error'`, **but only if there is no `post` to show**, so a failed confirmation of feed data keeps the post on screen.
- The request is aborted on cleanup, and errors from aborted requests are ignored.
- `retry` increments `attempt`.
- `id === null` resets the state and makes no request.

## 6. Phase 4 — Frontend components
| File | Change |
|------|--------|
| `frontend/src/components/TextCard.tsx` (new) | Takes the gradient block from `PostCard`, with props `{ text: string; clamp?: boolean }`. `clamp` applies `line-clamp-6` on feed cards. View Post shows the full text. |
| `frontend/src/components/icons.tsx` (new) | `HeartIcon`, `CommentIcon` and `ShareIcon` as inline outline SVGs (24×24, `stroke="currentColor"`, `aria-hidden`). No icon library. |
| `frontend/src/components/ViewPost.tsx` (new) | Props `{ post: FeedPost; likeCount?: number; commentCount?: number }`, with counts defaulting to `0`. It has its own `imageFailed` state, as `PostCard` does. Content in order: (1) the image (`w-full object-contain max-h-[80vh] bg-neutral-100`, `alt={post.text}`, `onError` falls back to `TextCard`), or `TextCard` for text-only posts; (2) the full text (`whitespace-pre-line`), **shown only when the image is rendered**, to avoid duplicating the text (AC-03); (3) the action row: three `<button type="button" aria-label=…>` elements with no `onClick`, where the like and comment buttons are followed by `<span>{count}</span>`. Card styling matches `PostCard` (`rounded-2xl bg-white shadow-sm ring-1 ring-black/5`). |
| `frontend/src/components/PostCard.tsx` | Wrap the card in `<Link to={\`/posts/${post.id}\`} className="block rounded-2xl focus-visible:outline-2 …">` (AC-16). Replace the inline gradient block with `<TextCard text={post.text} clamp />`. |
| `frontend/src/components/MasonryGrid.tsx` | New optional props `header?: ReactNode` and `headerSpan?: number`. With `span = header ? Math.min(headerSpan ?? 1, columns) : 0`, it renders a left wrapper (`style={{ flex: span }}`, `flex-col gap-4`) containing `header` and then a row of `buckets.slice(0, span)`, followed by `buckets.slice(span)` as ordinary columns. The round-robin bucketing stays the same, and without a `header` the output matches today's. |
| `frontend/src/views/FeedView.tsx` | See below. |

`FeedView` changes:
- `const postId = Number(useParams().postId) || null`.
- `const initial = posts.find(p => p.id === postId)`, and `const { post, status, error, retry } = usePost(postId, initial)`.
- `items = postId ? posts.filter(p => p.id !== postId) : posts` (AC-12).
- `header` is a small local `PinnedPost` component:
  - `ready` renders `<ViewPost key={post.id} post={post} />`. The `key` resets the image-error state when the post changes.
  - `loading` renders a skeleton block (`h-96 animate-pulse rounded-2xl bg-neutral-200`).
  - `not-found` renders "Post not found." and `<Link to="/">Back to feed</Link>`.
  - `error` renders `role="alert"` with the message and a **Retry** button wired to `retry`.
- `headerSpan = Math.min(columns, 2)`, using the existing `useColumnCount` ([useColumnCount.ts](../../frontend/src/hooks/useColumnCount.ts)).
- Render `MasonryGrid` whenever `items.length > 0 || postId`. The full-page `FeedSkeleton` appears only when no post is open and the first page is still loading.
- `useEffect(() => { if (postId) window.scrollTo({ top: 0 }) }, [postId])` (AC-01, AC-11).
- The "Trends" `<h1>` content becomes `<Link to="/">Trends</Link>`.
- The infinite-scroll sentinel and `useFeed` stay as they are (AC-15).

## 7. Phase 5 — Quality gates (AGENTS.md "Finally")
1. `cd backend && bin/rails test`: all green, including the 3 new tests.
2. `cd backend && bin/rubocop -a`: clean.
3. `cd frontend && npx oxlint --fix`, then `npm run lint`: clean.
4. `cd frontend && npm run build`: `tsc -b` and the Vite build succeed.

## 8. Phase 6 — Manual acceptance (frontend)
Start `bin/rails server -p 3000` and `npm run dev`, then go through each check at viewport widths of **375, 800, 1100 and 1400 px**:

| AC | Check |
|----|-------|
| AC-01, AC-11 | Clicking a card changes the URL to `/posts/{id}`, scrolls to the top and pins the post. Clicking another card swaps the pinned post. |
| AC-02, AC-03, AC-04 | Image post, text-only post, and a broken image (edit the URL in devtools) all display correctly. |
| AC-05, AC-06 | Icons show `♡ 0`, `💬 0` and `↗`. Clicking them does nothing; the Network tab shows no requests. |
| AC-07, AC-08, AC-09 | Reloading `/posts/{id}` works. `/posts/999999` shows "Post not found". With the API stopped, a post that is not in the feed shows the error, and Retry recovers once the API is back. |
| AC-10 | The browser Back button returns to the feed without reloading it. |
| AC-12 | The open post is not in the grid. |
| AC-13, AC-14 | The pinned block spans 2 columns at ≥ 768 px and the full width at < 768 px. |
| AC-15 | Infinite scroll still loads pages while a post is open. |
| AC-16 | Tab + Enter opens a card. The icon buttons are focusable and announce their names. |
| AC-17, AC-18 | Covered by the backend tests (Phase 1). |

## 9. Task order and files
1. P-2 baseline → 3.1 fixtures → 3.2 red tests → 3.3 controller → green + RuboCop.
2. P-1 approval and install → Phase 2 routing.
3. Phase 3: `api/posts.ts`, `usePost.ts`.
4. Phase 4: `TextCard` → `icons` → `ViewPost` → `PostCard` → `MasonryGrid` → `FeedView`.
5. Phase 5 quality gates → Phase 6 manual acceptance.

Files touched:
- **Backend (6)**: `posts_controller.rb`, `posts_controller_test.rb`, and 4 fixtures.
- **Frontend (11)**: `package.json`, `package-lock.json`, `main.tsx`, `App.tsx`, `api/feed.ts`, `api/posts.ts`, `hooks/usePost.ts`, `components/{TextCard,icons,ViewPost,PostCard,MasonryGrid}.tsx`, `views/FeedView.tsx`.

## 10. Risks and notes
- The round-robin distribution leaves the two left columns shorter, as the spec's known limitation says. The flex-grow approach makes the left sub-columns about `gap/2` narrower than the right ones, which is visually negligible.
- If `useParams` in the layout route does not return `postId`, fall back to `useMatch` (Phase 2).
- No interaction events are sent. That is intentional and deferred to FR-INT-03/04.
