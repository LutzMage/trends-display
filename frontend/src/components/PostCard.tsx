import { useState } from 'react'
import type { FeedPost } from '../api/feed'

export function PostCard({ post }: { post: FeedPost }) {
  const [imageFailed, setImageFailed] = useState(false)
  const showImage = post.media_type === 'image' && post.media_url && !imageFailed

  return (
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
        <div className="bg-gradient-to-br from-rose-100 to-amber-100 p-5 text-lg font-medium leading-snug whitespace-pre-line text-neutral-800">
          <p className="line-clamp-6">
            {post.text}
          </p>
        </div>
      )}

      <div className="space-y-1 p-3">
        <p className="text-sm font-semibold text-neutral-900">@{post.user.username}</p>
        {showImage && <p className="line-clamp-3 text-sm text-neutral-600">{post.text}</p>}
      </div>
    </article>
  )
}
