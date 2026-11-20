import { useState } from 'react'
import { Link } from 'react-router'
import type { FeedPost } from '../api/feed'
import { TextCard } from './TextCard'

export function PostCard({ post }: { post: FeedPost }) {
  const [imageFailed, setImageFailed] = useState(false)
  const showImage = post.media_type === 'image' && post.media_url && !imageFailed

  return (
    <Link
      to={`/posts/${post.id}`}
      className="block rounded-2xl focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-neutral-900"
    >
      <article className="group overflow-hidden rounded-2xl bg-white shadow-sm ring-1 ring-black/5 transition hover:shadow-lg">
        {showImage ? (
          <img
            src={post.media_url!}
            alt={post.text}
            loading="lazy"
            onError={() => setImageFailed(true)}
            className="block h-auto w-full bg-neutral-100 transition duration-300 group-hover:brightness-95"
          />
        ) : (
          <TextCard text={post.text} clamp />
        )}

        <div className="space-y-1 p-3">
          <p className="text-sm font-semibold text-neutral-900">@{post.user.username}</p>
          {showImage && <p className="line-clamp-3 text-sm text-neutral-600">{post.text}</p>}
        </div>
      </article>
    </Link>
  )
}
