import { API_URL, type FeedPost } from './feed'

export class PostNotFoundError extends Error {
  constructor() {
    super('Post not found')
    this.name = 'PostNotFoundError'
  }
}

export async function fetchPost(id: number, signal?: AbortSignal): Promise<FeedPost> {
  const res = await fetch(`${API_URL}/api/posts/${id}`, { signal })
  if (res.status === 404) throw new PostNotFoundError()
  if (!res.ok) throw new Error(`Post request failed (${res.status})`)
  return res.json()
}
