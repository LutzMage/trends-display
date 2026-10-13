import { useEffect, useRef } from 'react'
import { MasonryGrid } from '../components/MasonryGrid'
import { PostCard } from '../components/PostCard'
import { useColumnCount } from '../hooks/useColumnCount'
import { useFeed } from '../hooks/useFeed'

export function FeedView() {
  const { posts, status, error, loadMore } = useFeed()
  const columns = useColumnCount()
  const sentinelRef = useRef<HTMLDivElement>(null)

  // Fetch the next page when the sentinel scrolls near the viewport.
  useEffect(() => {
    const sentinel = sentinelRef.current
    if (!sentinel || status !== 'idle') return

    const observer = new IntersectionObserver(
      ([entry]) => entry.isIntersecting && void loadMore(),
      { rootMargin: '800px 0px' },
    )
    observer.observe(sentinel)
    return () => observer.disconnect()
  }, [status, loadMore])

  return (
    <main className="mx-auto max-w-7xl px-4 py-6">
      <h1 className="mb-6 text-2xl font-bold text-neutral-900">Trends</h1>

      {status === 'loading' && posts.length === 0 && <FeedSkeleton columns={columns} />}

      {posts.length > 0 && (
        <MasonryGrid
          items={posts}
          columns={columns}
          getKey={(post) => post.id}
          renderItem={(post) => <PostCard post={post} />}
        />
      )}

      <div ref={sentinelRef} className="flex justify-center py-8 text-sm text-neutral-500">
        {status === 'loading' && posts.length > 0 && 'Loading more…'}
        {status === 'done' && posts.length > 0 && "You're all caught up."}
        {status === 'done' && posts.length === 0 && 'No posts yet.'}
        {status === 'error' && (
          <div role="alert" className="flex items-center gap-3">
            <span>{error}</span>
            <button
              type="button"
              onClick={() => void loadMore()}
              className="rounded-full bg-neutral-900 px-4 py-1.5 font-medium text-white hover:bg-neutral-700"
            >
              Retry
            </button>
          </div>
        )}
      </div>
    </main>
  )
}

const SKELETON_HEIGHTS = ['h-48', 'h-72', 'h-56', 'h-80', 'h-64']

function FeedSkeleton({ columns }: { columns: number }) {
  return (
    <div className="flex items-start gap-4" aria-hidden>
      {Array.from({ length: columns }, (_, col) => (
        <div key={col} className="flex flex-1 flex-col gap-4">
          {[0, 1, 2].map((row) => (
            <div
              key={row}
              className={`${SKELETON_HEIGHTS[(col + row * 2) % SKELETON_HEIGHTS.length]} animate-pulse rounded-2xl bg-neutral-200`}
            />
          ))}
        </div>
      ))}
    </div>
  )
}
