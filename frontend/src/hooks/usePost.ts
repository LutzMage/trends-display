import { useCallback, useEffect, useState } from 'react'
import type { FeedPost } from '../api/feed'
import { fetchPost, PostNotFoundError } from '../api/posts'

type Status = 'loading' | 'ready' | 'not-found' | 'error'

// Loads a single post. When `initial` (e.g. the post already in the feed) is given,
// it renders immediately and the request only confirms it.
export function usePost(id: number | null, initial?: FeedPost) {
  const [post, setPost] = useState<FeedPost | null>(initial ?? null)
  const [status, setStatus] = useState<Status>(initial ? 'ready' : 'loading')
  const [error, setError] = useState<string | null>(null)
  const [attempt, setAttempt] = useState(0)
  const [prevId, setPrevId] = useState(id)

  // Reset during render when the id changes, so the previous post never flashes.
  if (id !== prevId) {
    setPrevId(id)
    setPost(initial ?? null)
    setStatus(initial ? 'ready' : 'loading')
    setError(null)
  }

  useEffect(() => {
    if (id === null) return

    const controller = new AbortController()
    fetchPost(id, controller.signal)
      .then((fresh) => {
        if (controller.signal.aborted) return
        setPost(fresh)
        setStatus('ready')
      })
      .catch((err: unknown) => {
        if (controller.signal.aborted) return
        if (err instanceof PostNotFoundError) {
          setPost(null)
          setStatus('not-found')
          return
        }
        setError(err instanceof Error ? err.message : 'Could not load the post')
        // Keep showing feed data if we have it; only surface the error otherwise.
        setStatus((current) => (current === 'ready' ? current : 'error'))
      })

    return () => controller.abort()
  }, [id, attempt])

  const retry = useCallback(() => {
    setError(null)
    setStatus('loading')
    setAttempt((n) => n + 1)
  }, [])

  return { post, status, error, retry }
}
