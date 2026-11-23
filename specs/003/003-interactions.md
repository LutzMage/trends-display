# SPEC-003 — Post interactions (click, like, comment, share, download, save)

| Field        | Value |
|--------------|-------|
| Spec ID      | SPEC-003 |
| Status       | Draft |
| Branch       | `feature/add-interactions` |
| Intent trace | FR-INT-01, FR-INT-03, FR-INT-05…09, new FR-INT-11 (comments) and FR-INT-12 (download), FR-AUTH-05 |
| Deferred     | FR-INT-02 (`impression`), FR-INT-04 (dwell `view`), a list of saved posts |
| Last updated | 2026-11-23 |

---

## 1. Summary

The action row of the open post (View Post, SPEC-001) becomes functional. A signed-in user can **like** a post (the heart turns pink), **save** it, **comment** on it, **share** it to six services from a modal, and **download** its image. Opening a post records a **click**. Like and save are toggles: clicking again undoes them.

Every action feeds the user profile, as the existing interactions already do (`UserProfileBuilder`). Undoing a like or a save removes its signal. Anonymous visitors can read comments, share and download. Actions that belong to a user send them to **Log in**.

### User stories
> As a **Browser**, I want to like, save, comment on, share and download posts, so that I can react to what I find and keep or pass on what I like.

> As a **PoC evaluator**, I want those actions recorded as interactions, so that I can see them change the personalised feed.

---

## 2. Scope

### 2.1 In scope
- Action row order: **Like · Comment · Download · Save · Share**. Download and Save are new and sit to the left of Share.
- **Like** and **Save** toggles, stored once per user and post, with the like count. The liked heart is pink and filled.
- A **comments section** below the post text: the 2 newest comments, **View all N comments** to expand, and an input to add one. Each comment shows an initials avatar, the `@username` and the text.
- A **Share** modal: Facebook, X, Instagram, Discord, Messenger and WhatsApp, then the post link with a **Copy link** button.
- **Download** of the post image through the API. The button is hidden on text-only posts.
- Recording `click` (opening a post), `share` and `download` as interactions.
- `GET /api/posts/:id` returns counts and the viewer's like and save state.
- Signed-out behaviour (§3.2).

### 2.2 Out of scope
- `impression` and dwell `view` events (FR-INT-02, FR-INT-04).
- A page or list of saved posts, boards or collections. Save only stores the relation.
- Editing, deleting, replying to, liking or reporting comments. Mentions, links and formatting in comments.
- Comment pagination beyond the 100 newest, and real-time comment updates.
- Like, comment or save counts on feed cards.
- Uploaded user avatars. Avatars are initials only.
- Returning to the post after **Log in** (login still lands on `/`).
- Downloading text-only posts (for example as an image).
- Open Graph or social preview tags for shared links.
- Rate limits on comments and interactions.
- A frontend test runner.

---

## 3. UX and behaviour

### 3.1 Action row
The row sits below the post text, as in SPEC-001. Buttons are icon buttons with an `aria-label` and the existing focus ring.

| # | Button | Shows | Click (signed in) |
|---|--------|-------|-------------------|
| 1 | **Like** | Heart and the like count. Liked: filled pink heart (`text-pink-500`, filled). Not liked: outline heart. `aria-pressed` reflects the state. | Toggles the like (§3.3). |
| 2 | **Comment** | Speech bubble and the comment count. | Moves focus to the comment input (§3.5). |
| 3 | **Download** | Download arrow. **Not rendered for text-only posts**, or when the image failed to load. | Downloads the image (§3.7). |
| 4 | **Save** | Bookmark. Saved: filled. Not saved: outline. `aria-pressed` reflects the state. | Toggles the save (§3.4). |
| 5 | **Share** | Share icon. `aria-haspopup="dialog"`. | Opens the Share modal (§3.6). |

- The post shown first may come from the feed, without counts or state. Until `GET /api/posts/:id` returns, **Like** and **Save** are disabled and no counts are shown. This avoids a "0" that then jumps.
- A failed like, save or download shows one short message in a `role="alert"` element under the row. It goes away on the next action.

### 3.2 Signed-out behaviour
Recording interactions requires a session (FR-AUTH-05).

| Action | Signed out |
|--------|------------|
| Like, Save, Comment button | Navigates to `/login`. |
| Comments section | Comments are visible. In place of the input: "**Log in** to comment" (link to `/login`). |
| Share, Download | Work as for a signed-in user. No interaction is recorded. |
| Opening a post | No `click` is recorded. |

### 3.3 Like
- Clicking toggles at once (optimistic): the heart fills pink and the count goes up by 1, or the reverse.
- The request is `PUT` (like) or `DELETE` (unlike) on `/api/posts/:id/like`. The response's `like_count` replaces the optimistic count.
- While its request is in flight, the button ignores clicks. This keeps one request per button and the final state predictable.
- On failure, the button reverts to its previous state and count, and the row shows "Could not update. Please try again."
- A like is stored once per user and post. Liking twice is a no-op. Unliking removes the like and its profile signal.

### 3.4 Save
- Same toggle, optimistic update, in-flight and failure rules as Like, on `/api/posts/:id/save`.
- No count is shown.
- Save only stores the relation between the user and the post. Nothing in the UI lists saved posts yet.

### 3.5 Comments section
Placed below the action row, inside the View Post card. The default view stays short: at most 2 comments plus the input.

**Content**
- Heading: "Comments". When there are none: "No comments yet."
- Each comment, in a row:
  1. an **initials avatar**: a 32 px circle with the first letter of the username in upper case. Its colour is picked from a fixed palette by user id, so a user always gets the same colour. `aria-hidden`, since the username follows.
  2. `@username` in semibold;
  3. the comment text (`whitespace-pre-line`, wraps).
- Order: **newest first**.

**Collapsed and expanded**
- Collapsed (default): the 2 newest comments.
- When there are more than 2: a **View all N comments** button. It expands the full list inline, in a box with a fixed maximum height (about 18 rem) that scrolls inside. The post never grows more than that box.
- Expanded: a **Show less** button collapses it back to 2.
- The list comes from one request when the post opens (`GET /api/posts/:id/comments`, up to the 100 newest). Expanding needs no new request.
- If that request fails: "Could not load comments." with a **Retry** button, in `role="alert"`.

**Adding a comment (signed in)**
- Below the list: a labelled text input, "Add a comment", with `maxLength` 250, and a **Post** button.
- **Post** is disabled while the input is blank or a request is in flight. Enter submits.
- On success: the new comment appears at the top of the list, the count in the action row goes up by 1, and the input clears.
- On failure: the text stays, and the API's message (or "Could not post the comment. Please try again.") shows in `role="alert"` under the input.
- Comment rules: 1–250 characters after trimming leading and trailing spaces.

### 3.6 Share modal
Opened by **Share**. It uses a native `<dialog>` with `showModal()`. **Escape**, the close (×) button and a click on the backdrop close it. Focus returns to the **Share** button.

**Layout, top to bottom**
1. Title "Share" and the × button.
2. Six targets in a grid, each a button with the service's icon and name: Facebook, X, Instagram, Discord, Messenger, WhatsApp.
3. The post link in a read-only text field, with a **Copy link** button next to it.

The **post link** is `{window.location.origin}/posts/{id}`. In development that is `http://localhost:5173/posts/{id}`.

| Target | Action |
|--------|--------|
| Facebook | Opens `https://www.facebook.com/sharer/sharer.php?u={link}` in a new tab. |
| X | Opens `https://x.com/intent/tweet?url={link}` in a new tab. |
| WhatsApp | Opens `https://wa.me/?text={link}` in a new tab. |
| Instagram | Copies the link, shows "Link copied. Paste it in Instagram.", and opens `https://www.instagram.com/` in a new tab. |
| Discord | Copies the link, shows "Link copied. Paste it in Discord.", and opens `https://discord.com/app` in a new tab. |
| Messenger | Copies the link, shows "Link copied. Paste it in Messenger.", and opens `https://www.messenger.com/` in a new tab. |
| **Copy link** | Copies the link. The button reads "Copied!" for 2 seconds. |

- `{link}` is URL-encoded. Only the link is shared, never the post text.
- New tabs open with `noopener,noreferrer`.
- Messages are announced through an `aria-live="polite"` region inside the modal.
- If the clipboard is unavailable, the link field is selected and the message reads "Press Ctrl+C to copy the link."
- Signed in: each target click and each **Copy link** records a `share` interaction.

### 3.7 Download
- Only for posts whose image is shown (`media_type: "image"` and the image loaded).
- Clicking fetches `GET /api/posts/:id/download` and saves the file as `trends-post-{id}.{ext}`, where `ext` comes from the image type (`jpg`, `png`, `webp` or `gif`).
- The button is disabled while the download is in flight.
- On failure, the row shows "Could not download the image."
- Signed in: a successful download records a `download` interaction.

### 3.8 Opening a post (`click`)
- Signed in: each time View Post opens for a post, the app records **one** `click` for it. Opening it from a card, from a link, or by reloading `/posts/{id}` all count as opening it.
- Re-renders do not record extra clicks, and neither do React StrictMode's double effects in development. Opening another post and coming back records a new click.
- Recording never blocks the view. Failures are ignored (FR-INT-08).

---

## 4. Data model and profile

### 4.1 `interactions` (changed)
- **One like and one save per user and post.** A partial unique index on `(user_id, post_id, event_type) WHERE event_type IN ('like', 'save')`. Other event types stay an append-only log.
- The migration first deletes duplicate `like` and `save` rows for the same user and post, keeping the oldest, and prints how many it removed. Then it adds the index.
- **New event type `download`** in the `Interaction` enum. The column is a string, so the type itself needs no schema change.
- **Undo removes the row.** Destroying a profile-affecting interaction (an unlike or unsave) enqueues `UpdateUserProfileJob`, as creating one already does.
- A like is an `Interaction` with `event_type: like`, and a save is one with `event_type: save`. No new tables are needed for them. `like_count` counts the post's `like` rows, using the existing `(post_id, event_type)` index.

### 4.2 `comments` (new)
| Column | Type | Notes |
|--------|------|-------|
| `user_id` | bigint, FK, NOT NULL | The author. |
| `post_id` | bigint, FK, NOT NULL | |
| `body` | string(250), NOT NULL | 1–250 characters after strip. |
| timestamps | | |

- Index on `(post_id, created_at)` for the newest-first list.
- `Post has_many :comments, dependent: :destroy`, and `User has_many :comments`.
- Creating a comment also records a `comment` interaction in the same transaction, so the profile counts it (weight 1.2).

### 4.3 Profile weights
| Event | Weight | Change |
|-------|--------|--------|
| `download` | **1.5** | New. The same as `save` and `share`: keeping the image is a strong signal. |
| `click`, `like`, `comment`, `save`, `share` | 0.3, 1.0, 1.2, 1.5, 1.5 | Unchanged. |

The per-post clamp (−2.0 to 3.0), time decay and signal window are unchanged. Repeated shares or downloads of one post cannot push its weight past 3.0.

---

## 5. API

All responses are JSON unless stated. "Comment" means `{ "id", "body", "created_at", "user": { "id", "username" } }`. Every endpoint below returns `404 { "error": "Post not found" }` for an unknown post. Endpoints marked **required** return `401 { "error": "Not authenticated" }` without a session (SPEC-002). State-changing requests keep the foreign-origin check (`403`, SPEC-002 AC-20).

| Method | Path | Auth | Request | Responses |
|--------|------|------|---------|-----------|
| GET | `/api/posts/:id` | optional | — | `200` the post as before, plus `like_count`, `comment_count`, `liked` and `saved`. `liked` and `saved` are `false` when anonymous. |
| PUT | `/api/posts/:id/like` | **required** | — | `200 { "liked": true, "like_count": n }`. Idempotent. |
| DELETE | `/api/posts/:id/like` | **required** | — | `200 { "liked": false, "like_count": n }`. Idempotent. |
| PUT | `/api/posts/:id/save` | **required** | — | `200 { "saved": true }`. Idempotent. |
| DELETE | `/api/posts/:id/save` | **required** | — | `200 { "saved": false }`. Idempotent. |
| GET | `/api/posts/:id/comments` | — | — | `200 { "comments": Comment[] }`: newest first, at most 100. |
| POST | `/api/posts/:id/comments` | **required** | `{ "comment": { "body" } }` | `201` Comment · `422 { "errors": string[] }` |
| POST | `/api/posts/:id/interactions` | **required** | `{ "event_type" }` | `201` (empty body) for `click`, `share` or `download` · `422 { "errors": ["Event type is not allowed"] }` for any other value |
| GET | `/api/posts/:id/download` | — | — | `200` the image bytes, with the upstream `Content-Type` and `Content-Disposition: attachment; filename="trends-post-{id}.{ext}"` · `404 { "error": "Post has no image" }` · `422 { "error": "Download is not available for this image" }` (host not allowed) · `502 { "error": "Image unavailable" }` |

**Why like and save have their own endpoints.** They are states that toggle, and `PUT`/`DELETE` make them idempotent. `POST /interactions` stays for one-off events. It rejects `like`, `save` and `comment`, which have their own endpoints, and every type this spec doesn't record (`impression`, `view`, …).

**Download and SSRF.** The image URL is user data, so the API fetches only from an **allowlist of hosts**: `DOWNLOAD_HOSTS`, comma-separated, defaulting to `cdn.bsky.app`, the seed image host. It fetches over `https` only and never sends a request to any other host.
- The fetch does not follow redirects, and has a 5 s connect timeout and a 10 s read timeout.
- The response must be `200` with an `image/jpeg`, `image/png`, `image/webp` or `image/gif` content type, and at most **10 MB**.
- Anything else returns `502`.

---

## 6. Implementation notes

### 6.1 Backend
- **Routes**, nested under `resources :posts`:
  - `resource :like` and `resource :save`, each `only: [:update, :destroy]`;
  - `resources :comments, only: [:index, :create]`;
  - `resources :interactions, only: :create`;
  - `get :download, on: :member`.
- **Controllers** (`Api::LikesController`, `Api::SavesController`, `Api::CommentsController`, `Api::InteractionsController`, and `download` on `Api::PostsController`):
  - Use `require_authentication` where §5 says **required**.
  - Find the post with `Post.find`, and rescue `RecordNotFound` to the existing `404` shape.
- **Idempotent toggles:**
  - `PUT` uses `find_or_create_by!` on `(user, post, event_type)`. A concurrent duplicate insert raises `RecordNotUnique`, which is rescued and treated as success.
  - `DELETE` uses `destroy_by`.
- **`Interaction`:** add `download` to the enum, and add `after_destroy_commit :enqueue_profile_update, if: :affects_profile?`.
- **`UserProfileBuilder::WEIGHTS`:** add `"download" => 1.5`.
- **`Comment` model:**
  - `belongs_to :user` and `belongs_to :post`;
  - `normalizes :body, with: :strip`;
  - `validates :body, presence: true, length: { maximum: 250 }`;
  - an `after_create` that records the `comment` interaction inside the same transaction.
- **`Post` JSON:**
  - `feed_json` is unchanged; the feed stays light.
  - `show` merges `like_count`, `comment_count`, `liked` and `saved` for `current_user`, which is `nil` when anonymous.
- **Download:**
  - A small service fetches the image with `Net::HTTP`, using the timeouts and the host, type and size checks from §5.
  - The controller replies with `send_data` and `disposition: "attachment"`.
  - Tests stub the service, so they never reach the network.

### 6.2 Frontend
- **`src/api/interactions.ts`:** `setLiked(id, liked)`, `setSaved(id, saved)`, `fetchComments(id, signal)`, `createComment(id, body)`, `recordInteraction(id, type)` and `downloadImage(id)`.
  - Every call uses `credentials: 'include'`.
  - `recordInteraction` is fire-and-forget and swallows errors.
  - `downloadImage` returns a `Blob`. The caller saves it through an object URL and a temporary `<a download>`, then revokes the URL.
- **`src/api/posts.ts`:** a `PostDetail` type, which is `FeedPost` plus `like_count`, `comment_count`, `liked` and `saved`.
- **`ViewPost`:**
  - Replace the static `likeCount` and `commentCount` props with the detail state.
  - Wire the five buttons.
  - Record the `click` with a ref guard keyed by post id, so StrictMode double effects record one click.
- **New components:**
  - `ShareDialog.tsx`, using native `<dialog>`;
  - `CommentsSection.tsx`;
  - `Avatar.tsx` (initials).
- **Icons in `icons.tsx`:**
  - Add `DownloadIcon`, `BookmarkIcon` and `CloseIcon`.
  - Add the six service logos as inline SVG, with paths copied from the CC0 Simple Icons set. No icon library is installed.
  - `HeartIcon` and `BookmarkIcon` accept a filled state.
- Signed-out navigation to `/login` uses `useNavigate`. The session comes from `useAuth()`.

### 6.3 Configuration
| Variable | Default | Purpose |
|----------|---------|---------|
| `DOWNLOAD_HOSTS` | `cdn.bsky.app` | Comma-separated hosts the download endpoint may fetch from. |

### 6.4 Dependencies requiring approval
None. Everything uses Rails, `Net::HTTP`, React, the browser Clipboard API and native `<dialog>`.

### 6.5 Changes to `intent/intent.md` (Documentation step)
- §2.3 / §4.2: comments move from future scope to in scope.
- §5.3:
  - FR-INT-05 and FR-INT-06 become toggles.
  - FR-INT-07 lists the six targets and Copy link.
  - New FR-INT-11 (comments) and FR-INT-12 (download).
- §6:
  - comment length 1–250;
  - one like and one save per user and post;
  - `download` weight 1.5;
  - the `DOWNLOAD_HOSTS` allowlist.
- §11:
  - the `comments` table and the partial unique index;
  - the API rows from §5;
  - the `GET /api/posts/:id` fields.
- §14 success criterion 3: add comment and download.

---

## 7. Acceptance criteria

### API
| # | Given | When | Then |
|---|-------|------|------|
| AC-01 | Anonymous | `GET /api/posts/:id` | `200` with `like_count`, `comment_count`, `liked: false` and `saved: false`. |
| AC-02 | Signed in, the post liked and saved by me | `GET /api/posts/:id` | `liked: true`, `saved: true`. `like_count` counts every user's like. |
| AC-03 | Signed in, not liked | `PUT /api/posts/:id/like` twice | Both return `200 { "liked": true, "like_count": n+1 }`. Exactly one `like` row exists, and the profile update is enqueued once. |
| AC-04 | Signed in, liked | `DELETE /api/posts/:id/like` twice | Both return `200 { "liked": false, "like_count": n-1 }`. The row is gone, and the profile update is enqueued once. |
| AC-05 | Signed in | `PUT`, then `DELETE`, on `/api/posts/:id/save` | `200 { "saved": true }`, then `200 { "saved": false }`. At most one `save` row at any time. Profile update enqueued on each change. |
| AC-06 | Anonymous | `PUT`/`DELETE` like or save, `POST` comments, `POST` interactions | `401 { "error": "Not authenticated" }`. Nothing is created or deleted. |
| AC-07 | Signed in (the session check runs first, so an anonymous call to a **required** endpoint gets `401`) | Any endpoint in §5 with an unknown post id | `404 { "error": "Post not found" }`. |
| AC-08 | A post with 3 comments | `GET /api/posts/:id/comments` | `200`, newest first. Each item has `id`, `body`, `created_at` and `user { id, username }`. |
| AC-09 | Signed in | `POST /api/posts/:id/comments` with `"  Nice!  "` | `201` with body `"Nice!"` and my user. `comment_count` goes up by 1. A `comment` interaction is recorded, and the profile update is enqueued. |
| AC-10 | Signed in | `POST` a comment that is blank, only spaces, or 251 characters | `422 { "errors": [...] }`. No comment and no interaction are created. |
| AC-11 | Signed in | `POST /api/posts/:id/interactions` with `click`, `share` or `download` | `201`. One row of that type for me and the post. The profile update is enqueued. |
| AC-12 | Signed in | `POST /api/posts/:id/interactions` with `like`, `save`, `comment`, `impression`, `view` or `bogus` | `422 { "errors": ["Event type is not allowed"] }`. Nothing is created. |
| AC-13 | An image post on an allowed host (stubbed fetch) | `GET /api/posts/:id/download` | `200`, the image bytes, its `Content-Type`, and `Content-Disposition: attachment; filename="trends-post-{id}.jpg"`. |
| AC-14 | A text-only post / an image on a host not in `DOWNLOAD_HOSTS` / an upstream error, a non-image or more than 10 MB | `GET /api/posts/:id/download` | `404 { "error": "Post has no image" }` / `422 { "error": "Download is not available for this image" }`, with **no outbound request** / `502 { "error": "Image unavailable" }`. |
| AC-15 | Migrations have run | Insert a second `like` (or `save`) for the same user and post | The database rejects it (unique index). A second `click` for the same user and post is accepted. |
| AC-16 | Signed in | `PUT /api/posts/:id/like` with `Origin: https://evil.example` | `403 { "error": "Forbidden origin" }`. No like is created. |

### UI (manual)
| # | Given | When | Then |
|---|-------|------|------|
| AC-17 | An image post is open | I look at the action row | Like (count) · Comment (count) · Download · Save · Share, in that order. On a text-only post, Download is not shown. |
| AC-18 | Signed in, not liked | I click **Like**, then click it again | First the heart turns filled pink and the count goes up by 1. Then it is an outline and the count goes back. After a reload, the last state is kept. |
| AC-19 | Signed in | I click **Save**, then reload | The bookmark is filled after the click and after the reload. Clicking again unfills it. |
| AC-20 | Signed out | I click **Like**, **Save** or **Comment** | I land on `/login`. Comments are visible, and the input is replaced by "Log in to comment". |
| AC-21 | A post with 5 comments | I open it | The 2 newest are shown, each with an initials avatar, `@username` and the text, plus **View all 5 comments**. Clicking it shows all 5 in a scrolling box no taller than about 18 rem. **Show less** collapses it. A post with none shows "No comments yet." |
| AC-22 | Signed in | I type a comment and press Enter | It appears at the top of the list, the count goes up by 1, and the input clears. **Post** is disabled while the input is blank, and typing stops at 250 characters. |
| AC-23 | Any post | I click **Share** | A modal opens with the six targets, the post link and **Copy link**. Facebook, X and WhatsApp open their share page in a new tab, with the link filled in. Instagram, Discord and Messenger copy the link, show "Link copied. Paste it in …", and open the service in a new tab. **Copy link** reads "Copied!" for 2 s. Escape, × and a backdrop click close the modal, and focus returns to **Share**. |
| AC-24 | An image post | I click **Download** | The browser saves `trends-post-{id}.jpg` (or the matching extension). With the API stopped, "Could not download the image." appears. |
| AC-25 | Signed in | I open a post, share it, and download it | The database has exactly one new `click`, plus one `share` per share action and one `download` (`bin/rails runner`). Signed out, nothing is recorded. |
| AC-26 | Signed in, the API stopped | I click **Like** or **Save** | The button returns to its previous state, and "Could not update. Please try again." appears. |
| AC-27 | Keyboard only | I use the action row, the comments section and the Share modal | Every control is reachable with Tab and has a visible focus outline. Like and Save expose `aria-pressed`. The modal keeps focus inside it until it closes. |

---

## 8. Testing and verification

**Automated (backend, test first)**
- `test/models/comment_test.rb`: validations, `strip`, and the `comment` interaction recorded on create.
- `test/models/interaction_test.rb`:
  - the `download` type, which enqueues a profile update (so it is in `UserProfileBuilder::WEIGHTS`, at 1.5);
  - a profile update enqueued on destroy of a like or save;
  - the unique index for like and save, but not for click (AC-15).
- `test/controllers/api/likes_controller_test.rb` and `saves_controller_test.rb`: AC-03 to AC-06 and AC-16.
- `test/controllers/api/comments_controller_test.rb`: AC-06 to AC-10.
- `test/controllers/api/interactions_controller_test.rb`: AC-06, AC-11 and AC-12.
- `test/controllers/api/posts_controller_test.rb`:
  - AC-01 and AC-02;
  - AC-13 and AC-14, with the download service stubbed, plus a service test that asserts no request is made to a host that isn't allowed.
- `cd backend && bin/rails test` and `bin/rubocop -a`.

**Static checks (frontend)**: `cd frontend && npx oxlint --fix && npm run lint` and `npm run build`.

**Manual**: run `bin/rails server -p 3000` and `npm run dev`, then go through AC-17 to AC-27 in Chrome, Edge or Firefox, signed in and signed out, at widths of 375 and 1400 px.

---

## 9. Known limitations and risks
- **Shared links point to `localhost` in development.** Other people can't open them, and the services show no preview (the SPA has no Open Graph tags).
- **Instagram, Discord and Messenger** have no web "share this URL" link, so the user pastes the copied link themselves.
- **Clipboard** needs a secure context. `localhost` qualifies; production needs HTTPS. When the link is copied and the service then opens in a new tab, the clipboard write must finish while the click's user activation is still valid. The copy therefore runs first.
- **Download** works only for hosts in `DOWNLOAD_HOSTS`. Images on other hosts return `422`, and the UI shows "Could not download the image."
- **Comments** have no edit, delete, moderation or rate limit, and the list stops at the 100 newest.
- **Repeated clicks, shares and downloads** each add a row. The per-post weight clamp (3.0) limits their effect on the profile.
- **Profile updates are asynchronous.** After a like or unlike, the feed changes on its next fetch, not at once.
- **The migration deletes duplicate likes and saves**, keeping the oldest. Seeded or `fake_likes.rb` data with duplicates loses only the extra copies.
- **Saved posts** are stored but not shown anywhere yet.
