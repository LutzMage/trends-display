import { useEffect, useRef } from 'react'
import { Link, useParams } from 'react-router'
import { MasonryGrid } from '../components/MasonryGrid'
import { PostCard } from '../components/PostCard'
import { ViewPost } from '../components/ViewPost'
import { useColumnCount } from '../hooks/useColumnCount'
import { useFeed } from '../hooks/useFeed'
import { usePost } from '../hooks/usePost'

export function FeedView() {
  const { posts, status, error, loadMore } = useFeed()
  const columns = useColumnCount()
  const sentinelRef = useRef<HTMLDivElement>(null)

  const postId = Number(useParams().postId) || null
  const openPost = usePost(postId, posts.find((p) => p.id === postId))
  const items = postId ? posts.filter((p) => p.id !== postId) : posts

  // The pinned post sits at the top of the grid, so bring it into view.
  useEffect(() => {
    if (postId) window.scrollTo({ top: 0 })
  }, [postId])

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
      <h1 className="mb-6 text-2xl font-bold text-neutral-900">
        <Link to="/">Trends</Link>
      </h1>

      {status === 'loading' && posts.length === 0 && !postId && <FeedSkeleton columns={columns} />}

      {(items.length > 0 || postId) && (
        <MasonryGrid
          items={items}
          columns={columns}
          getKey={(post) => post.id}
          renderItem={(post) => <PostCard post={post} />}
          header={postId && <PinnedPost {...openPost} />}
          headerSpan={Math.min(columns, 2)}
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

function PinnedPost({ post, status, error, retry }: ReturnType<typeof usePost>) {
  if (status === 'ready' && post) return <ViewPost key={post.id} post={post} />

  if (status === 'not-found') {
    return (
      <div className="rounded-2xl bg-white p-6 text-neutral-700 shadow-sm ring-1 ring-black/5">
        <p>Post not found.</p>
        <Link to="/" className="mt-2 inline-block font-medium text-neutral-900 underline">
          Back to feed
        </Link>
      </div>
    )
  }

  if (status === 'error') {
    return (
      <div
        role="alert"
        className="flex items-center gap-3 rounded-2xl bg-white p-6 text-sm text-neutral-700 shadow-sm ring-1 ring-black/5"
      >
        <span>{error}</span>
        <button
          type="button"
          onClick={retry}
          className="rounded-full bg-neutral-900 px-4 py-1.5 font-medium text-white hover:bg-neutral-700"
        >
          Retry
        </button>
      </div>
    )
  }

  return <div className="h-96 animate-pulse rounded-2xl bg-neutral-200" aria-hidden />
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
