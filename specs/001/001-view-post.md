# SPEC-001 — View Post from the feed

| Field        | Value |
|--------------|-------|
| Spec ID      | SPEC-001 |
| Status       | Draft |
| Branch       | `add-post-view` |
| Intent trace | FR-INT-01 (post detail view), FR-FEED-08 (image / text card rendering) |
| Deferred     | FR-INT-02…07 (interaction recording and actions), FR-FEED-10 in the detail view (author shown on cards only) |
| Last updated | 2026-10-19 |

---

## 1. Summary

When a user clicks a post in the feed grid, a **View Post** component opens at the **top-left of the page**. It shows the post larger, with its full text and three interaction icons: like, comment and share. The feed grid keeps flowing to the right of View Post and below it, as in Pinterest's close-up view. The post gets its own URL (`/posts/:id`), so the view survives a reload and can be shared as a link.

In this iteration the icons are **visual only**. Like and comment each show a count of `0`.

### User story
> As a **Browser**, I want to click a post in the feed to see it larger, with its full description and interaction icons, without losing my place in the feed.

---

## 2. Scope

### 2.1 In scope
- Navigating from a feed card to `/posts/:id`.
- The View Post component: media (image or text card), full text description, and the action row (like + `0`, comment + `0`, share).
- Loading the post from `GET /api/posts/:id`, including on deep links and reloads.
- Pinning View Post at the top-left of the grid while the feed keeps rendering around it.
- Loading, not-found and error states for View Post.
- Updating the backend `show` endpoint so it returns the same shape as feed posts.

### 2.2 Out of scope
- Any behaviour on the like, comment and share icons (no handlers, no API calls).
- Recording `click`, `view` or `impression` interactions.
- Real interaction counts. Both counts are hardcoded to `0`.
- Author block, timestamp, close (X) button, related-posts logic.
- Authentication.
- Comment threads UI.
- A frontend test runner.

---

## 3. UX and behaviour

### 3.1 Routes
| Path | Renders |
|------|---------|
| `/` | The feed grid (current behaviour). |
| `/posts/:id` | The feed grid with View Post pinned in its top-left area. |

- `FeedView` **stays mounted** across `/` ↔ `/posts/:id`. Loaded pages, cursor and scroll-loading state are **not** reset when the user opens or leaves a post.
- The page heading **"Trends"** links to `/`.
- The browser Back and Forward buttons move between `/` and the posts the user has opened.

### 3.2 Opening a post
- Every feed card is a link to `/posts/{id}` and can be reached and activated with the keyboard (Tab + Enter).
- After navigating, the window scrolls to the top so View Post is visible.
- Clicking another card while a post is open replaces the pinned post and scrolls to the top again.
- The open post is **excluded from the grid**, so it never appears twice on screen.

### 3.3 Layout

View Post spans the **first 2 columns** of the masonry grid. The remaining columns sit to its right, and the 2 left columns continue below it.

```
≥ 1280 px (5 columns)                     768–1023 px (3 columns)
+------------------+ +---+ +---+ +---+    +------------------+ +---+
|                  | |   | |   | |   |    |                  | |   |
|    VIEW POST     | +---+ |   | +---+    |    VIEW POST     | +---+
|   (2 columns)    | +---+ +---+ +---+    |   (2 columns)    | +---+
|                  | |   | +---+ |   |    |                  | |   |
+------------------+ +---+ |   | +---+    +------------------+ +---+
+---+ +---+          +---+ +---+ +---+    +---+ +---+          +---+
|   | |   |          |   | |   | |   |    |   | |   |          |   |
+---+ +---+          +---+ +---+ +---+    +---+ +---+          +---+

< 768 px (2 columns): View Post spans the full width; the grid continues below.
```

| Breakpoint (from `useColumnCount`) | Columns | View Post span |
|------------------------------------|---------|----------------|
| < 768 px | 2 | 2 (full width) |
| ≥ 768 px | 3 | 2 |
| ≥ 1024 px | 4 | 2 |
| ≥ 1280 px | 5 | 2 |

Rule: `headerSpan = min(columns, 2)`.

### 3.4 View Post content

Top to bottom:

1. **Media**
   - Image posts (`media_type === "image"`): the full image at its natural aspect ratio. It is not cropped, and its height is capped at about `80vh` (`object-contain`). `alt` is the post text.
   - Text-only posts, or an image that fails to load: the same **gradient text card** used in the feed (`from-rose-100 to-amber-100`).
2. **Text description**: the full post text, with no line clamp and line breaks preserved (`whitespace-pre-line`).
   - For text-only posts the text card already shows the text, so the description below it is omitted to avoid duplication.
3. **Action row**, left to right:

   ```
   [♡] 0     [💬] 0     [↗]
   ```

   | Icon | Accessible name | Count shown | Behaviour |
   |------|-----------------|-------------|-----------|
   | Heart (outline) | "Like" | `0` | None |
   | Speech bubble (outline) | "Comment" | `0` | None |
   | Share / arrow-out | "Share" | — | None |

   - Icons are **inline SVG** components. No icon library is added.
   - Each icon is a `<button type="button">` with an `aria-label` and **no click handler**. It is not disabled, so it keeps its normal focus and hover styling and is ready for later wiring.
   - Counts come from props `likeCount` and `commentCount`, both defaulting to `0`. In this iteration callers do not pass them.

Visual style follows the existing cards: white surface, `rounded-2xl`, `shadow-sm ring-1 ring-black/5`, neutral text colours, Tailwind utilities only.

### 3.5 States of the pinned slot
| State | Trigger | UI |
|-------|---------|----|
| Instant | The post is already in the loaded feed. | Render it from the feed data straight away while the request confirms it. |
| Loading | No local data and the request is in flight. | Skeleton block in the pinned slot (`animate-pulse`, neutral-200), same footprint as View Post. |
| Loaded | Request succeeded. | View Post as described in §3.4. |
| Not found | API returns `404`. | "Post not found." plus a link "Back to feed" → `/`. The grid still renders. |
| Error | Network failure or a 5xx response. | Error message plus a **Retry** button that repeats the request (`role="alert"`). The grid still renders. |

When the user leaves (navigates to another post or to `/`), any in-flight request is aborted.

---

## 4. API

### 4.1 `GET /api/posts/:id` (changed)

**Response `200`**: identical to a feed item (`Post#feed_json`):

```json
{
  "id": 123,
  "text": "Watercolor study of a mountain lake",
  "media_type": "image",
  "media_url": "https://cdn.example.com/img/123.jpg",
  "created_at": "2026-10-19T12:00:00Z",
  "user": { "id": 7, "username": "painter.bsky.social" }
}
```

**Response `404`**:

```json
{ "error": "Post not found" }
```

Today the endpoint renders the raw model (`render json: Post.find(...)`), without `user` and with extra columns. It changes to the shape above so that the frontend can reuse the `FeedPost` type.

---

## 5. Implementation notes

### 5.1 Backend
| File | Change |
|------|--------|
| `backend/app/controllers/api/posts_controller.rb` | `show` loads `Post.includes(:user).find(params[:id])` and renders `post.feed_json`. Rescue `ActiveRecord::RecordNotFound` → `404 { error: "Post not found" }`. |
| `backend/test/controllers/api/posts_controller_test.rb` | Add tests: `200` with keys `id, text, media_type, media_url, created_at, user{id, username}`, and `404` with an error body for an unknown id. |

### 5.2 Frontend
| File | Change |
|------|--------|
| `frontend/src/main.tsx` | Wrap `<App />` in `<BrowserRouter>`. |
| `frontend/src/App.tsx` | `<Routes>` with a layout route `element={<FeedView />}`, an index child, and a `posts/:postId` child (child elements render nothing), so `FeedView` stays mounted. |
| `frontend/src/api/posts.ts` (new) | `fetchPost(id: number, signal?: AbortSignal): Promise<FeedPost>`. Reuses `FeedPost` and the `API_URL` convention from `api/feed.ts`. On `404` it throws a `PostNotFoundError` so the UI can tell it apart from other failures. |
| `frontend/src/hooks/usePost.ts` (new) | `usePost(id, initial?: FeedPost)` → `{ post, status: 'loading' \| 'ready' \| 'not-found' \| 'error', error, retry }`. Aborts on id change or unmount. Follows the `AbortController` pattern in `useFeed.ts`. |
| `frontend/src/components/TextCard.tsx` (new) | The gradient text card, extracted from `PostCard`. Prop `clamp` limits lines on feed cards; View Post shows the full text. |
| `frontend/src/components/ViewPost.tsx` (new) | Presentational: `{ post: FeedPost; likeCount?: number; commentCount?: number }`. Renders §3.4. Also owns the image-error fallback, as `PostCard` does today. |
| `frontend/src/components/PostCard.tsx` | Wrap the card in `<Link to={`/posts/${post.id}`}>` and use `TextCard`. |
| `frontend/src/components/MasonryGrid.tsx` | New optional props `header?: ReactNode` and `headerSpan?: number`. When `header` is set, the first `headerSpan` buckets render inside a wrapper with `header` above them. The other buckets render as today. The round-robin bucket distribution is unchanged. |
| `frontend/src/views/FeedView.tsx` | Read `postId` with `useParams()`. If present: use `usePost(postId, postsFromFeed.find(...))`, pass the View Post (or a state from §3.5) as `header` with `headerSpan = Math.min(columns, 2)`, filter that post out of `items`, and call `window.scrollTo({ top: 0 })` when `postId` changes. Make the "Trends" heading a `<Link to="/">`. |

### 5.3 Dependency requiring approval
| Package | Version | Reason |
|---------|---------|--------|
| `react-router` | 8.4.0 (exact) | Client-side routing for `/posts/:id`, used in declarative mode (`BrowserRouter`, `Routes`, `Route`, `Link`, `useParams`). |

Per `AGENTS.md`, `react-router` must be **approved before installation**. No other packages are added. The Vite dev server already serves `index.html` for unknown paths, so deep links work in development without extra configuration.

---

## 6. Acceptance criteria

| # | Given | When | Then |
|---|-------|------|------|
| AC-01 | The feed is loaded | I click a card | The URL becomes `/posts/{id}`, the page scrolls to the top, and View Post appears in the top-left area. |
| AC-02 | View Post is open for an image post | — | The full, uncropped image is shown, with the full text below it and then the action row. |
| AC-03 | View Post is open for a text-only post | — | The gradient text card with the full text is shown in place of the image, followed by the action row. The text is not duplicated. |
| AC-04 | The post's image fails to load | — | View Post falls back to the gradient text card. |
| AC-05 | View Post is open | I look at the action row | I see a like icon followed by `0`, a comment icon followed by `0`, and a share icon with no count. |
| AC-06 | View Post is open | I click (or press Enter on) like, comment or share | Nothing happens: no navigation, no request, no count change. |
| AC-07 | — | I open `/posts/{id}` directly or reload it | The post is fetched and shown pinned, and the feed loads around it. |
| AC-08 | — | I open `/posts/999999` (missing) | The pinned slot shows "Post not found." with a "Back to feed" link. The grid still loads. |
| AC-09 | The API is unreachable | I open a post that is not in the loaded feed | An error with **Retry** is shown. Retry repeats the request. |
| AC-10 | I opened a post from the feed | I press the browser Back button | I return to `/`. The previously loaded feed is still there, with no full reload. |
| AC-11 | View Post is open | I click another card in the grid | The pinned post is replaced, the URL updates, and the page scrolls to the top. |
| AC-12 | View Post is open | I scan the grid | The open post does not appear among the grid cards. |
| AC-13 | Viewport ≥ 768 px | View Post is open | View Post spans 2 columns. The remaining 1–3 columns render to its right. |
| AC-14 | Viewport < 768 px | View Post is open | View Post spans the full width, with the 2-column grid below. |
| AC-15 | View Post is open | I scroll to the bottom | Infinite scroll keeps loading feed pages as it does on `/`. |
| AC-16 | Keyboard only | I Tab through the feed | Each card is focusable and Enter opens it. In View Post, the three icon buttons are focusable and announce "Like", "Comment" and "Share". |
| AC-17 | — | `GET /api/posts/:id` for an existing post | `200` with the `feed_json` shape, including `user.username`. |
| AC-18 | — | `GET /api/posts/:id` for an unknown id | `404` with `{ "error": "Post not found" }`. |

---

## 7. Testing and verification

**Automated (backend)**
- `cd backend && bin/rails test`: new `Api::PostsControllerTest` cases for AC-17 and AC-18.
- `cd backend && bin/rubocop`

**Static checks (frontend)**
- `cd frontend && npm run lint` (oxlint)
- `cd frontend && npm run build` (runs `tsc -b`, which catches type errors)

**Manual (frontend)**: run `bin/rails server -p 3000` and `npm run dev`, then go through AC-01 to AC-16 at widths of 375, 800, 1100 and 1400 px.

---

## 8. Known limitations
- The round-robin distribution in `MasonryGrid` does not account for the header's height, so the two left columns end up shorter than the right ones. This is acceptable for the PoC. A later improvement could place each item in the shortest column.
- Counts are static `0` until interactions are wired up (FR-INT-05/06/07).
- No `click` or `view` events are recorded yet, so opening a post does not affect the user profile (FR-INT-03/04).
