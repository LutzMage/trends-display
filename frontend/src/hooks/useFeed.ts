import { useCallback, useEffect, useRef, useState } from 'react'
import { fetchFeed, type FeedPost } from '../api/feed'

type Status = 'idle' | 'loading' | 'error' | 'done'

export function useFeed({ limit = 20, userId }: { limit?: number; userId?: number } = {}) {
  const [posts, setPosts] = useState<FeedPost[]>([])
  const [status, setStatus] = useState<Status>('idle')
  const [error, setError] = useState<string | null>(null)

  const cursorRef = useRef<string | null>(null)
  const seenRef = useRef(new Set<number>())
  const inFlightRef = useRef<AbortController | null>(null)
  const doneRef = useRef(false)

  const loadMore = useCallback(async () => {
    if (inFlightRef.current || doneRef.current) return

    const controller = new AbortController()
    inFlightRef.current = controller
    setStatus('loading')
    setError(null)

    try {
      const page = await fetchFeed({ cursor: cursorRef.current, limit, userId, signal: controller.signal })
      const fresh = page.posts.filter((p) => !seenRef.current.has(p.id))
      fresh.forEach((p) => seenRef.current.add(p.id))

      cursorRef.current = page.next_cursor
      doneRef.current = fresh.length === 0 || !page.next_cursor
      setPosts((prev) => [...prev, ...fresh])
      setStatus(doneRef.current ? 'done' : 'idle')
    } catch (err) {
      if (controller.signal.aborted) return
      setError(err instanceof Error ? err.message : 'Could not load the feed')
      setStatus('error')
    } finally {
      if (inFlightRef.current === controller) inFlightRef.current = null
    }
  }, [limit, userId])

  useEffect(() => {
    void loadMore()
    return () => {
      inFlightRef.current?.abort()
      inFlightRef.current = null
    }
  }, [loadMore])

  return { posts, status, error, loadMore }
}
