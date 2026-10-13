const API_URL = import.meta.env.VITE_API_URL ?? 'http://localhost:3000'

export type FeedPost = {
  id: number
  text: string
  media_type: 'image' | null
  media_url: string | null
  created_at: string
  user: { id: number; username: string }
}

export type FeedPage = {
  posts: FeedPost[]
  next_cursor: string | null
}

type FetchFeedParams = {
  cursor?: string | null
  limit?: number
  userId?: number
  signal?: AbortSignal
}

export async function fetchFeed({ cursor, limit, userId, signal }: FetchFeedParams = {}): Promise<FeedPage> {
  const params = new URLSearchParams()
  if (cursor) params.set('cursor', cursor)
  if (limit) params.set('limit', String(limit))
  if (userId) params.set('user_id', String(userId))

  const res = await fetch(`${API_URL}/api/feed?${params}`, { signal })
  if (!res.ok) throw new Error(`Feed request failed (${res.status})`)
  return res.json()
}
