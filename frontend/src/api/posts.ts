import { API_URL, type FeedPost } from './feed'

// The open post's counts and the viewer's own state (SPEC-003 §5). liked/saved are false when signed out.
export type PostStats = { like_count: number; comment_count: number; liked: boolean; saved: boolean }

// The stats are missing while the post shown is still the copy from the feed.
export type Post = FeedPost & Partial<PostStats>

export class PostNotFoundError extends Error {
  constructor() {
    super('Post not found')
    this.name = 'PostNotFoundError'
  }
}

export async function fetchPost(id: number, signal?: AbortSignal): Promise<FeedPost & PostStats> {
  const res = await fetch(`${API_URL}/api/posts/${id}`, { credentials: 'include', signal })
  if (res.status === 404) throw new PostNotFoundError()
  if (!res.ok) throw new Error(`Post request failed (${res.status})`)
  return res.json()
}
