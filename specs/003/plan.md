# Implementation Plan — SPEC-003 Post interactions

| Field | Value |
|-------|-------|
| Spec | [003-interactions.md](003-interactions.md) |
| Intent | [intent/intent.md](../../intent/intent.md): FR-INT-01, 03, 05…09, new FR-INT-11 and FR-INT-12, FR-AUTH-05, NFR-08 |
| Branch | `feature/add-interactions` |
| Status | Ready for implementation once P-3 is approved |

## 1. Context
SPEC-003 makes the View Post action row work:
- **Like** and **Save** toggles (stored as `interactions` rows, one per user and post);
- a **comments** section (new `comments` table);
- a **Share** modal with six targets and Copy link;
- **Download** of the image through the API, limited to an allowlist of hosts;
- recording `click`, `share` and `download`.

It also adds counts and the viewer's state to `GET /api/posts/:id`.

The plan follows the project rules:
- **AGENTS.md**: read the intent and the spec first, and write the **test first**. No new gem or npm package (spec §6.4). Finish with the unit tests and the linters, with autofix.
- **Intent NFR-06**: the download endpoint never fetches a URL outside `DOWNLOAD_HOSTS` (SSRF).
- **Intent NFR-08**: labelled controls, `aria-pressed` on the toggles, `role="alert"` errors, and a keyboard-usable modal.
- **Intent NFR-10**: English for code, identifiers and UI text.

**Testing approach**: as in SPEC-001 and SPEC-002, test-first applies to the **backend**. The frontend has no test runner, so it is checked with `npm run lint`, `npm run build` and the manual checks in §11.

**Reused, not rebuilt**:
- `require_authentication`, `current_user` and `sign_in_as` (SPEC-002);
- the foreign-origin check, which already covers `PUT` and `DELETE` (AC-16);
- `stub_singleton` for the download service;
- the `(post_id, event_type)` index for like counts;
- the "reset state during render" pattern from `usePost`.

## 2. Prerequisites and approvals
| # | Item | Action |
|---|------|--------|
| P-1 | Test-suite baseline | Run `cd backend && bin/rails test` and record it (expected: 65 runs, 200 assertions, 0 failures). |
| P-2 | Branch | Confirm we're on `feature/add-interactions` with a clean tree. |
| P-3 | Service logos | **Ask for approval** to copy the SVG paths of Facebook, X, Instagram, Discord, Messenger and WhatsApp from Simple Icons (CC0), read as text from the simple-icons repository. No package is installed. If a logo is missing there, its button shows the service's initial instead. |
| P-4 | Duplicate likes and saves (read-only) | In the dev database, count `like`/`save` rows that share user, post and type (`bin/rails runner`). Report the number before Phase 1 runs the migration that deletes them (spec §4.1). |

## 3. Phase 1 — Data model (test first)

### 3.1 Comments
| Step | Detail | AC |
|------|--------|----|
| Test (red) `test/models/comment_test.rb` | <ul><li>A blank or spaces-only body is invalid, and so is one of 251 characters.</li><li>`"  Nice!  "` is stored as `"Nice!"`.</li><li>Creating a comment creates one `comment` interaction for the same user and post (`assert_difference`).</li><li>`api_json` has `id`, `body`, `created_at` and `user { id, username }`.</li></ul> | AC-09, AC-10 |
| Fixture `comments.yml` | Three comments on `posts(:one)`: two by `one` and one by `two`, with `created_at` 3, 2 and 1 days ago, so newest-first order is testable. | AC-08 |
| Migration `CreateComments` | `references :user` and `references :post`, both `null: false` with foreign keys; the post reference uses `index: false`. `string :body, limit: 250, null: false`, timestamps, and `index [:post_id, :created_at]`. | — |
| Model `Comment` | <ul><li>`belongs_to :user`, `belongs_to :post`.</li><li>`normalizes :body, with: ->(body) { body.strip }`.</li><li>`validates :body, presence: true, length: { maximum: 250 }`.</li><li>`after_create { post.interactions.create!(user:, event_type: :comment) }`, which runs in the same transaction.</li><li>`def api_json = { id:, body:, created_at:, user: { id: user.id, username: user.username } }`.</li></ul> | — |
| `Post` and `User` | `has_many :comments, dependent: :destroy` on both. | — |

### 3.2 Interactions
| Step | Detail | AC |
|------|--------|----|
| Test (red) `test/models/interaction_test.rb` | <ul><li>A `download` interaction is valid and enqueues `UpdateUserProfileJob` (which proves `download` is in `WEIGHTS`).</li><li>Destroying a `like` or a `save` enqueues `UpdateUserProfileJob`.</li><li>Inserting a second `like` (or `save`) for the same user and post raises `ActiveRecord::RecordNotUnique`.</li><li>A second `click` for the same pair is saved.</li></ul> | AC-15 |
| Migration `AddUniqueLikeAndSaveToInteractions` | `up`: <ol><li>Delete the duplicate `like`/`save` rows, keeping the oldest per `(user_id, post_id, event_type)`, with a single `DELETE … USING` that compares `(created_at, id)`.</li><li>`say` how many rows were removed.</li><li>`add_index :interactions, [:user_id, :post_id, :event_type], unique: true, where: "event_type IN ('like', 'save')"`.</li></ol> `down`: remove the index only (deleted duplicates are not restored). | AC-15 |
| `Interaction` | Add `download: "download"` to the enum. Add `after_destroy_commit :enqueue_profile_update, if: :affects_profile?`. | — |
| `UserProfileBuilder::WEIGHTS` | Add `"download" => 1.5`. | — |

## 4. Phase 2 — Post detail (test first)
| Step | Detail | AC |
|------|--------|----|
| Test (red) `posts_controller_test.rb` | <ul><li>Update "show returns the post in feed shape": the key list gains `comment_count`, `like_count`, `liked` and `saved`.</li><li>Anonymous `GET posts(:one)`: `like_count` 1 (fixture `interactions(:one)`), `comment_count` 3, and `liked`/`saved` false.</li><li>Signed in as `one`, after creating a `save`: `liked: true` and `saved: true`.</li></ul> | AC-01, AC-02 |
| `PostScoped` concern (`app/controllers/concerns/post_scoped.rb`) | <ul><li>Moves `rescue_from ActiveRecord::RecordNotFound` and `post_not_found` out of `PostsController`, unchanged.</li><li>Adds `current_post`: `@current_post ||= Post.find(params[:post_id] \|\| params[:id])`.</li><li>The lookup is lazy, so `require_authentication` (a `before_action`) always runs first. That gives `401` before `404`, matching AC-06 and AC-07.</li></ul> | AC-07 |
| `Post#detail_json(viewer)` | `feed_json` merged with: <ul><li>`like_count: interactions.like_event.count`</li><li>`comment_count: comments.count`</li><li>`liked`: `viewer` present and `interactions.like_event.exists?(user: viewer)`</li><li>`saved`: the same check for `save_event`</li></ul> | — |
| `PostsController#show` | `include PostScoped`, and `render json: current_post.detail_json(current_user)`. `feed_json` is unchanged, so the feed stays light. | — |

## 5. Phase 3 — Like and save (test first)
| Step | Detail | AC |
|------|--------|----|
| Test (red) `test/controllers/api/likes_controller_test.rb` | <ul><li>`PUT` twice: both `200 { liked: true, like_count }`, `assert_difference` +1 overall, and `assert_enqueued_jobs 1`.</li><li>`DELETE` twice: both `200 { liked: false, … }`, the row is gone, and one job is enqueued.</li><li>Anonymous `PUT`/`DELETE`: `401`, with no change.</li><li>An unknown post: `404`.</li><li>`Origin: https://evil.example`: `403`, with no like.</li></ul> | AC-03, AC-04, AC-06, AC-07, AC-16 |
| Test (red) `test/controllers/api/saves_controller_test.rb` | `PUT` then `DELETE`: `{ saved: true }` then `{ saved: false }`, at most one row, and a job on each change. Plus anonymous `401` and unknown post `404`. | AC-05, AC-06, AC-07 |
| Routes | Inside `resources :posts`: `resource :like, only: [ :update, :destroy ]` and `resource :save, only: [ :update, :destroy ]`. | — |
| `InteractionToggle` concern | <ul><li>Includes `PostScoped` and adds `before_action :require_authentication`.</li><li>`update`: `current_user.interactions.find_or_create_by!(post: current_post, event_type: toggle_event)`, rescuing `ActiveRecord::RecordNotUnique` (a concurrent `PUT` won the race, so the state is already right). Then renders `toggle_json(true)`.</li><li>`destroy`: `current_user.interactions.destroy_by(post: current_post, event_type: toggle_event)`, then renders `toggle_json(false)`. `destroy_by` runs callbacks, so the profile job is enqueued.</li></ul> | — |
| `Api::LikesController`, `Api::SavesController` | Each includes the concern and defines two small methods: <ul><li>`toggle_event` returns `"like"` or `"save"`;</li><li>`toggle_json(on)` returns `{ liked: on, like_count: current_post.interactions.like_event.count }` or `{ saved: on }`.</li></ul> | — |

## 6. Phase 4 — Comments and interactions endpoints (test first)
| Step | Detail | AC |
|------|--------|----|
| Test (red) `test/controllers/api/comments_controller_test.rb` | <ul><li>`GET`: `200`, the three fixtures newest first, with the item shape.</li><li>`POST` signed in with `"  Nice!  "`: `201`, body `"Nice!"`, my user, and +1 `Comment` and +1 `comment` interaction.</li><li>Blank, spaces-only and 251-character bodies: `422 { errors }`, with no change to either count.</li><li>Anonymous `POST`: `401`.</li><li>An unknown post: `404`, for `GET` and for a signed-in `POST`.</li></ul> | AC-06…AC-10 |
| `Api::CommentsController` + `resources :comments, only: [ :index, :create ]` | <ul><li>`include PostScoped` and `before_action :require_authentication, only: :create`.</li><li>`index`: `current_post.comments.includes(:user).order(created_at: :desc, id: :desc).limit(100)` rendered as `{ comments: […api_json] }`. The limit is marked as a `shortcut:` until pagination is needed.</li><li>`create`: `current_post.comments.new(params.expect(comment: [ :body ]).merge(user: current_user))`, then `201` with `api_json`, or `422 { errors: full_messages }`.</li></ul> | — |
| Test (red) `test/controllers/api/interactions_controller_test.rb` | <ul><li>`click`, `share` and `download`: `201`, one row each, and the job enqueued.</li><li>`like`, `save`, `comment`, `impression`, `view` and `bogus`: `422 { errors: ["Event type is not allowed"] }`, with no row.</li><li>Anonymous: `401`. An unknown post: `404`.</li></ul> | AC-06, AC-07, AC-11, AC-12 |
| `Api::InteractionsController` + `resources :interactions, only: :create` | `include PostScoped` and `before_action :require_authentication`. `RECORDABLE = %w[click share download]`. Respond `422` unless `params[:event_type]` is in the list; otherwise `current_user.interactions.create!(post: current_post, event_type:)` and `head :created`. | — |

## 7. Phase 5 — Download (test first)
| Step | Detail | AC |
|------|--------|----|
| Test (red) `test/services/image_download_test.rb` | `ImageDownload.get` is stubbed with `stub_singleton`, so no test reaches the network. <ul><li>A host not in `DOWNLOAD_HOSTS`, an `http://` URL, or an unparsable URL raise `NotAllowed`, and **`get` is never called** (the stub calls `flunk`).</li><li>For an allowed host: a non-200 status, a non-image type such as `text/html`, or a network error from `get` raise `Unavailable`.</li><li>`200 image/jpeg` returns an image with `body`, `content_type` and `extension == "jpg"`.</li><li>`read_capped` with a fake response whose `read_body` yields chunks: under 10 MB returns the bytes, and over 10 MB raises `Unavailable`.</li></ul> | AC-14 |
| `app/services/image_download.rb` | <ul><li>`NotAllowed` and `Unavailable` errors.</li><li>`TYPES = { "image/jpeg" => "jpg", "image/png" => "png", "image/webp" => "webp", "image/gif" => "gif" }` and `MAX_BYTES = 10.megabytes`.</li><li>`fetch(url)`: parse the URL, require `URI::HTTPS` and a host in `allowed_hosts`, which is read from `ENV.fetch("DOWNLOAD_HOSTS", "cdn.bsky.app")` split on commas. Call `get(uri)`, then check status `200` and that the content type (parameters dropped) is in `TYPES`.</li><li>`get(uri)`: `Net::HTTP.start(…, use_ssl: true, open_timeout: 5, read_timeout: 10)`, streaming the response through `read_capped`. It does not follow redirects. It returns `[code, content_type, body]` and maps network errors to `Unavailable`, as `Auth0Client` does.</li></ul> | — |
| Test (red) `posts_controller_test.rb` | <ul><li>`posts(:one)` with `ImageDownload.fetch` stubbed to return a JPEG: `200`, the bytes, `image/jpeg`, and `Content-Disposition` containing `attachment` and `filename="trends-post-{id}.jpg"`.</li><li>`posts(:two)` (text-only): `404 { error: "Post has no image" }`.</li><li>`posts(:one)` unstubbed: its host `example.com` isn't allowed, so `422 { error: "Download is not available for this image" }`.</li><li>Stub raising `Unavailable`: `502 { error: "Image unavailable" }`.</li><li>An unknown post: `404 { error: "Post not found" }`.</li></ul> | AC-07, AC-13, AC-14 |
| Route + `PostsController#download` | `get :download, on: :member`. The action returns `404` unless `current_post.image?`, then calls `ImageDownload.fetch(current_post.media_url)` and `send_data image.body, type: image.content_type, disposition: "attachment", filename: "trends-post-#{id}.#{image.extension}"`. It rescues `NotAllowed` to `422` and `Unavailable` to `502`, both logged. | — |

## 8. Phase 6 — Frontend data layer
| File | Change |
|------|--------|
| `src/api/posts.ts` | <ul><li>`type PostStats = { like_count: number; comment_count: number; liked: boolean; saved: boolean }`.</li><li>`type Post = FeedPost & Partial<PostStats>`. Stats are missing while the post shown comes from the feed.</li><li>`fetchPost` returns `FeedPost & PostStats`.</li></ul> |
| `src/api/interactions.ts` (new) | All calls use `credentials: 'include'` and `API_URL`. <ul><li>`setLiked(id, liked)`: `PUT` or `DELETE` `/like`, returning `{ liked, like_count }`.</li><li>`setSaved(id, saved)`: the same on `/save`, returning `{ saved }`.</li><li>`type Comment`, `fetchComments(id, signal)` and `createComment(id, body)`. A `422` throws an `Error` with the `errors` joined.</li><li>`recordInteraction(id, type)`: fire-and-forget, so `.catch(() => {})`.</li><li>`downloadImage(id)`: returns the `Blob` and throws on any non-OK status.</li></ul> |
| `src/hooks/usePost.ts` | The post state becomes `Post`. Add `update(patch: Partial<PostStats>)`, which merges into the current post, so optimistic changes live where the post already does. Return `update` alongside `post`, `status`, `error` and `retry`. |
| `src/hooks/useComments.ts` (new) | <ul><li>`useComments(postId)` returns `{ comments, status: 'loading' \| 'ready' \| 'error', retry, add }`.</li><li>It fetches once per post with an `AbortController`, as `usePost` does.</li><li>`add(body)` awaits `createComment` and puts the result first. It rethrows on failure, so the form can show the message.</li></ul> |

## 9. Phase 7 — Frontend components
| File | Change |
|------|--------|
| `src/components/icons.tsx` | <ul><li>Add `DownloadIcon`, `BookmarkIcon` and `CloseIcon` in the existing stroke style.</li><li>Add six filled 24×24 logo components from P-3: `FacebookIcon`, `XIcon`, `InstagramIcon`, `DiscordIcon`, `MessengerIcon` and `WhatsAppIcon`.</li><li>Filled states need no new prop: `fill-current` in `className` overrides the SVG `fill="none"` attribute.</li></ul> |
| `src/components/Avatar.tsx` (new) | <ul><li>A 32 px circle with the first letter or digit of the username, in upper case.</li><li>The background comes from a fixed palette of six Tailwind colours, indexed by `user.id % 6`.</li><li>`aria-hidden`.</li></ul> |
| `src/components/CommentsSection.tsx` (new) | <ul><li>Props: `{ postId, inputRef, onAdded }`. Uses `useComments`, and `useAuth` for the form.</li><li>Collapsed: the first 2 comments. **View all N comments** expands the list into `max-h-72 overflow-y-auto`, and **Show less** collapses it.</li><li>States: "No comments yet.", and an error `role="alert"` with **Retry**.</li><li>Signed in: a form with a labelled input ("Add a comment", `maxLength={250}`, receiving `inputRef`) and a **Post** button, disabled while the input is blank or a request is in flight. Success clears the input and calls `onAdded()`. Failure keeps the text and shows an alert.</li><li>Signed out: "**Log in** to comment" (`<Link to="/login">`).</li></ul> |
| `src/components/ShareDialog.tsx` (new) | <ul><li>Props: `{ postId, open, onClose }`.</li><li>A native `<dialog>`: an effect calls `showModal()` and `close()` when `open` changes. The `close` event calls `onClose`, and a click on the backdrop (target is the `<dialog>` itself) closes it.</li><li>`SHARE_TARGETS`: a plain array of `{ name, Icon, shareUrl? }` or `{ name, Icon, site }` entries (spec §3.6).</li><li>The link is `${window.location.origin}/posts/${postId}`.</li><li>A `shareUrl` target opens with `window.open(url, '_blank', 'noopener,noreferrer')`. A `site` target first awaits `navigator.clipboard.writeText`, then sets "Link copied. Paste it in {name}." and opens the site.</li><li>**Copy link** shows "Copied!" for 2 s. If the clipboard fails, it selects the field and says "Press Ctrl+C to copy the link."</li><li>Every action calls `recordInteraction(postId, 'share')` when signed in.</li><li>Messages go in an `aria-live="polite"` region.</li></ul> |
| `src/components/PostActions.tsx` (new) | <ul><li>Props: `{ post: Post, update, canDownload, onComment }`.</li><li>The row: Like (count) · Comment (count) · Download (only when `canDownload`) · Save · Share.</li><li>Like and Save are disabled until stats are present (`post.like_count !== undefined`), and use `aria-pressed`. Liked: `fill-current text-pink-500`. Saved: `fill-current`.</li><li>Toggles update optimistically through `update`, then apply the server's answer. A failure restores the previous values and sets "Could not update. Please try again.". A `pending` record (`{ like?, save?, download? }`) ignores clicks while a request is in flight.</li><li>Signed out, Like, Save and Comment call `navigate('/login')`. Signed in, Comment calls `onComment`.</li><li>Download: `downloadImage` → object URL → a temporary `<a download="trends-post-{id}.{ext}">` click → revoke the URL. The extension comes from `blob.type`. Then `recordInteraction(id, 'download')` when signed in. Failure shows "Could not download the image."</li><li>Share opens `ShareDialog`.</li><li>One `role="alert"` message under the row, cleared on the next action.</li></ul> |
| `src/components/ViewPost.tsx` | <ul><li>Props become `{ post: Post; update }`; the static `likeCount` and `commentCount` go.</li><li>Render `PostActions` (with `canDownload={showImage}` and `onComment` focusing the input), then `CommentsSection`. Its `onAdded` sets `update({ comment_count: (post.comment_count ?? 0) + 1 })`.</li><li>Record `click`: `useEffect` on `[post.id, user]`, guarded by a `useRef` holding the last recorded id. StrictMode's dev re-run keeps the ref, so it records once. `PinnedPost` keys `ViewPost` by post id, so a new opening mounts afresh and records again.</li></ul> |
| `src/views/FeedView.tsx` | `PinnedPost` also passes `update` from `usePost` to `ViewPost`. |

## 10. Phase 8 — Documentation
- `intent/intent.md`: apply the spec's §6.5 list, and bump it to v0.3 with the "Last updated" line.
- `README.md`:
  - Features: like, save, comments, share and download.
  - API table: the new endpoints from spec §5.
  - Configuration: `DOWNLOAD_HOSTS`, with its default.
- Spec header: Status → Implemented, once Phase 10 passes.

## 11. Phase 9 — Quality gates (AGENTS.md "Finally")
1. `cd backend && bin/rails test`: all green.
2. `cd backend && bin/rubocop -a`, `bin/brakeman` and `bin/bundler-audit`: clean.
3. `cd frontend && npx oxlint --fix`, then `npm run lint`: clean.
4. `cd frontend && npm run build`: succeeds.
5. Push, and confirm CI is green. Only when the owner asks.

## 12. Phase 10 — Manual acceptance
Run `bin/rails db:migrate`, `bin/rails server -p 3000` and `npm run dev`. Use Chrome, Edge or Firefox, signed in (for example as user 41) and signed out, at 375 and 1400 px.

Test data: add 5 comments to one post through the UI, or with `bin/rails runner`.

| AC | Check |
|----|-------|
| AC-17 | Action-row order on an image post. No Download on a text-only post. |
| AC-18, AC-19, AC-26 | Like turns filled pink, and the count changes by ±1. Save fills and unfills. Both survive a reload. With Rails stopped, they revert and show the alert. |
| AC-20 | Signed out: Like, Save and Comment go to `/login`. Comments are visible, with "Log in to comment". |
| AC-21, AC-22 | 2 comments, then View all / Show less, the scroll box height, "No comments yet.", posting with Enter, and the 250-character limit. |
| AC-23 | The Share modal: each target, Copy link, Escape, × and backdrop close, and focus back on Share. |
| AC-24 | Download saves `trends-post-{id}.jpg`. With Rails stopped, the alert shows. |
| AC-25 | `bin/rails runner 'p Interaction.where(user_id: 41).order(:id).last(5).pluck(:event_type)'` after open, share and download shows one `click`, then `share` and `download`. Signed out, no new rows. |
| AC-27 | Keyboard only through the row, comments and modal. `aria-pressed` in DevTools. |
| AC-01…16 | Covered by the backend tests. |

## 13. Task order and files
1. P-1 → P-4.
2. Phase 1: comments → interactions.
3. Phase 2: post detail.
4. Phase 3: like and save.
5. Phase 4: comments and interactions endpoints.
6. Phase 5: download.
7. Phase 6: frontend data layer.
8. Phase 7: components.
9. Phase 8: docs.
10. Phase 9: gates.
11. Phase 10: manual checks.

**Backend** (about 25 files):
- `config/routes.rb`
- `app/models/{comment,interaction,post,user}.rb`
- `app/services/{image_download,user_profile_builder}.rb`
- `app/controllers/concerns/{post_scoped,interaction_toggle}.rb`
- `app/controllers/api/{posts,likes,saves,comments,interactions}_controller.rb`
- 2 migrations and `db/schema.rb`
- `test/fixtures/comments.yml`
- test files: `models/{comment,interaction}`, `services/image_download`, `controllers/api/{posts,likes,saves,comments,interactions}`

**Frontend** (about 12 files):
- `api/{posts,interactions}.ts`
- `hooks/{usePost,useComments}.ts`
- `components/{icons,Avatar,CommentsSection,ShareDialog,PostActions,ViewPost}.tsx`
- `views/FeedView.tsx`

**Docs**: `README.md`, `intent/intent.md`, the spec header and `checklist.md`.

## 14. Risks and notes
- **Destructive migration**: removing duplicate likes and saves can't be undone by `down`. P-4 counts them first. `fake_likes.rb` already skips liked posts, so the count is expected to be 0.
- **`401` before `404`**: `current_post` is lazy, so authentication runs first. Don't turn it into a `before_action` placed ahead of `require_authentication`.
- **Existing exact-keys test**: "show returns the post in feed shape" lists every key, so it changes in Phase 2.
- **Race on like/save**: two concurrent `PUT`s can both miss the row. The unique index stops the second insert, and the rescue makes it a success.
- **Profile jobs on cascade deletes**: `after_destroy_commit` also fires when a post or user is destroyed. For a destroyed user the job fails to deserialize. Neither deletion is a feature yet, so leave it.
- **Clipboard then `window.open`**: the copy is awaited first, while the click's user activation is still valid. If a browser blocks the new tab, the link is still copied and the message still shows.
- **StrictMode** runs effects twice in development. The ref guard (§9) keeps `click` to one row per opening. Check it in AC-25.
- **Brakeman**: `send_data` with bytes fetched from a URL in user data may be flagged. The allowlist is the mitigation. If Brakeman still warns, document it in `config/brakeman.ignore` rather than weakening the check.
- **Simple Icons**: if a logo isn't available, fall back to the service's initial (P-3). Logos are used only to label share buttons.
- **`x.com/intent/tweet`** is X's long-standing share intent. Recheck it in AC-23 in case X changes it.
