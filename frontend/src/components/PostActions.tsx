import { useState } from 'react'
import { useNavigate } from 'react-router'
import { downloadImage, recordInteraction, setLiked, setSaved } from '../api/interactions'
import type { Post, PostStats } from '../api/posts'
import { useAuth } from '../hooks/useAuth'
import { BookmarkIcon, CommentIcon, DownloadIcon, HeartIcon, ShareIcon } from './icons'
import { ShareDialog } from './ShareDialog'

const actionClass =
  'inline-flex items-center gap-1.5 rounded-full p-2 text-neutral-700 transition hover:bg-neutral-100 hover:text-neutral-900 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-neutral-900'

const UPDATE_FAILED = 'Could not update. Please try again.'

// The saved file's extension, from the image type the API sends.
const EXTENSIONS: Record<string, string> = { 'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp', 'image/gif': 'gif' }

type Request = 'like' | 'save' | 'download'

type PostActionsProps = {
  post: Post
  update: (patch: Partial<PostStats>) => void
  canDownload: boolean
  onComment: () => void
}

// The open post's action row: Like · Comment · Download · Save · Share (SPEC-003 §3.1).
export function PostActions({ post, update, canDownload, onComment }: PostActionsProps) {
  const { user } = useAuth()
  const navigate = useNavigate()
  const [pending, setPending] = useState<Partial<Record<Request, boolean>>>({})
  const [error, setError] = useState<string | null>(null)
  const [sharing, setSharing] = useState(false)

  // The copy of the post from the feed has no stats; they arrive with GET /api/posts/:id.
  const loaded = post.like_count !== undefined

  // One request per button at a time. Returns whether it worked; a failure shows `failure` under the row.
  async function track(request: Request, send: () => Promise<void>, failure: string): Promise<boolean> {
    setError(null)
    setPending((current) => ({ ...current, [request]: true }))
    try {
      await send()
      return true
    } catch {
      setError(failure)
      return false
    } finally {
      setPending((current) => ({ ...current, [request]: false }))
    }
  }

  // Liking, saving and commenting belong to a user: signed out, they lead to Log in (SPEC-003 §3.2).
  async function toggleLike() {
    if (!user) return void navigate('/login')
    if (pending.like || post.liked === undefined || post.like_count === undefined) return

    const before = { liked: post.liked, like_count: post.like_count }
    const liked = !before.liked
    update({ liked, like_count: before.like_count + (liked ? 1 : -1) }) // optimistic; the API's count replaces it
    const ok = await track('like', async () => update(await setLiked(post.id, liked)), UPDATE_FAILED)
    if (!ok) update(before)
  }

  async function toggleSave() {
    if (!user) return void navigate('/login')
    if (pending.save || post.saved === undefined) return

    const before = { saved: post.saved }
    update({ saved: !before.saved })
    const ok = await track('save', async () => update(await setSaved(post.id, !before.saved)), UPDATE_FAILED)
    if (!ok) update(before)
  }

  function comment() {
    setError(null)
    if (!user) return void navigate('/login')
    onComment()
  }

  async function download() {
    if (pending.download) return

    const ok = await track(
      'download',
      async () => {
        const blob = await downloadImage(post.id)
        saveFile(blob, `trends-post-${post.id}.${EXTENSIONS[blob.type] ?? 'jpg'}`)
      },
      'Could not download the image.',
    )
    if (ok && user) recordInteraction(post.id, 'download')
  }

  return (
    <div className="space-y-2">
      <div className="flex flex-wrap items-center gap-2">
        <button
          type="button"
          aria-label="Like"
          aria-pressed={post.liked ?? false}
          disabled={!loaded}
          onClick={() => void toggleLike()}
          className={actionClass}
        >
          <HeartIcon className={`h-6 w-6 ${post.liked ? 'fill-current text-pink-500' : ''}`} />
          {loaded && <span>{post.like_count}</span>}
        </button>

        <button type="button" aria-label="Comment" onClick={comment} className={actionClass}>
          <CommentIcon />
          {loaded && <span>{post.comment_count}</span>}
        </button>

        {canDownload && (
          <button
            type="button"
            aria-label="Download image"
            aria-disabled={pending.download ?? false}
            onClick={() => void download()}
            className={actionClass}
          >
            <DownloadIcon />
          </button>
        )}

        <button
          type="button"
          aria-label="Save"
          aria-pressed={post.saved ?? false}
          disabled={!loaded}
          onClick={() => void toggleSave()}
          className={actionClass}
        >
          <BookmarkIcon className={`h-6 w-6 ${post.saved ? 'fill-current text-neutral-900' : ''}`} />
        </button>

        <button
          type="button"
          aria-label="Share"
          aria-haspopup="dialog"
          onClick={() => {
            setError(null)
            setSharing(true)
          }}
          className={actionClass}
        >
          <ShareIcon />
        </button>
      </div>

      {error && (
        <p role="alert" className="rounded-lg bg-rose-50 px-3 py-2 text-sm text-rose-800">
          {error}
        </p>
      )}

      {sharing && <ShareDialog postId={post.id} onClose={() => setSharing(false)} />}
    </div>
  )
}

// The API is on another origin, so <a download> can't point at it directly: save the fetched Blob instead.
function saveFile(blob: Blob, filename: string) {
  const url = URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  link.download = filename
  document.body.append(link)
  link.click()
  link.remove()
  setTimeout(() => URL.revokeObjectURL(url), 0)
}
