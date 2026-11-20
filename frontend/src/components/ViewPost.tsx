import { useState } from 'react'
import { useLocation, useNavigate } from 'react-router'
import type { FeedPost } from '../api/feed'
import { ArrowLeftIcon, CommentIcon, HeartIcon, ShareIcon } from './icons'
import { TextCard } from './TextCard'

const actionClass =
  'inline-flex items-center gap-1.5 rounded-full p-2 text-neutral-700 transition hover:bg-neutral-100 hover:text-neutral-900 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-neutral-900'

type ViewPostProps = { post: FeedPost; likeCount?: number; commentCount?: number }

export function ViewPost({ post, likeCount = 0, commentCount = 0 }: ViewPostProps) {
  const [imageFailed, setImageFailed] = useState(false)
  const showImage = post.media_type === 'image' && post.media_url && !imageFailed
  const navigate = useNavigate()
  const location = useLocation()
  // 'default' is the entry the app was loaded on, so going back would leave the site.
  const goBack = () => (location.key === 'default' ? navigate('/') : navigate(-1))

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

        {/* Visual only in SPEC-001: buttons have no handlers yet. */}
        <div className="flex items-center gap-4">
          <button type="button" aria-label="Like" className={actionClass}>
            <HeartIcon />
            <span>{likeCount}</span>
          </button>
          <button type="button" aria-label="Comment" className={actionClass}>
            <CommentIcon />
            <span>{commentCount}</span>
          </button>
          <button type="button" aria-label="Share" className={actionClass}>
            <ShareIcon />
          </button>
        </div>
      </div>
    </article>
  )
}
