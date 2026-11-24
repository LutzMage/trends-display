import { useEffect, useRef, useState } from 'react'
import { useLocation, useNavigate } from 'react-router'
import { recordInteraction } from '../api/interactions'
import type { Post, PostStats } from '../api/posts'
import { useAuth } from '../hooks/useAuth'
import { CommentsSection } from './CommentsSection'
import { ArrowLeftIcon } from './icons'
import { PostActions } from './PostActions'
import { TextCard } from './TextCard'

type ViewPostProps = { post: Post; update: (patch: Partial<PostStats>) => void }

export function ViewPost({ post, update }: ViewPostProps) {
  const [imageFailed, setImageFailed] = useState(false)
  const showImage = post.media_type === 'image' && Boolean(post.media_url) && !imageFailed
  const navigate = useNavigate()
  const location = useLocation()
  // 'default' is the entry the app was loaded on, so going back would leave the site.
  const goBack = () => (location.key === 'default' ? navigate('/') : navigate(-1))

  const { user } = useAuth()
  const commentInput = useRef<HTMLInputElement>(null)
  const recordedClick = useRef<number | null>(null)

  // One `click` per opening (SPEC-003 §3.8). PinnedPost keys ViewPost by post id, so each opening mounts afresh,
  // and the ref survives StrictMode's second effect run in development.
  useEffect(() => {
    if (!user || recordedClick.current === post.id) return
    recordedClick.current = post.id
    recordInteraction(post.id, 'click')
  }, [post.id, user])

  return (
    <article className="relative overflow-hidden rounded-2xl bg-white shadow-sm ring-1 ring-black/5 motion-safe:animate-pin-in">
      <button
        type="button"
        aria-label="Back"
        onClick={() => void goBack()}
        className="absolute top-3 left-3 rounded-full bg-white/90 p-2 text-neutral-800 shadow-md ring-1 ring-black/5 transition hover:bg-white focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-neutral-900"
      >
        <ArrowLeftIcon className="h-5 w-5" />
      </button>

      {showImage ? (
        <img
          src={post.media_url!}
          alt={post.text}
          onError={() => setImageFailed(true)}
          className="block max-h-[80vh] w-full bg-neutral-100 object-contain"
        />
      ) : (
        <TextCard text={post.text} />
      )}

      <div className="space-y-3 p-4">
        {showImage && <p className="whitespace-pre-line text-neutral-800">{post.text}</p>}

        <PostActions
          post={post}
          update={update}
          canDownload={showImage}
          onComment={() => commentInput.current?.focus()}
        />

        <CommentsSection
          postId={post.id}
          inputRef={commentInput}
          onAdded={() => update({ comment_count: (post.comment_count ?? 0) + 1 })}
        />
      </div>
    </article>
  )
}
