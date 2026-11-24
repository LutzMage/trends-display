import { API_URL } from './feed'
import type { PostStats } from './posts'

// Like, save, comment on, share and download a post (SPEC-003 §5). Every call sends the session cookie.

export type Comment = { id: number; body: string; created_at: string; user: { id: number; username: string } }

// The one-off events POST /api/posts/:id/interactions accepts. Like, save and comment have their own endpoints.
export type RecordedEvent = 'click' | 'share' | 'download'

const postUrl = (id: number) => `${API_URL}/api/posts/${id}`

export function setLiked(id: number, liked: boolean): Promise<Pick<PostStats, 'liked' | 'like_count'>> {
  return toggle(`${postUrl(id)}/like`, liked)
}

export function setSaved(id: number, saved: boolean): Promise<Pick<PostStats, 'saved'>> {
  return toggle(`${postUrl(id)}/save`, saved)
}

// PUT turns it on and DELETE turns it off. Both are idempotent, and both answer with the new state.
async function toggle<T>(url: string, on: boolean): Promise<T> {
  const res = await fetch(url, { method: on ? 'PUT' : 'DELETE', credentials: 'include' })
  if (!res.ok) throw new Error(`Request failed (${res.status})`)
  return res.json()
}

// Newest first, at most 100.
export async function fetchComments(id: number, signal?: AbortSignal): Promise<Comment[]> {
  const res = await fetch(`${postUrl(id)}/comments`, { credentials: 'include', signal })
  if (!res.ok) throw new Error(`Comments request failed (${res.status})`)
  const data: { comments: Comment[] } = await res.json()
  return data.comments
}

export async function createComment(id: number, body: string): Promise<Comment> {
  const res = await fetch(`${postUrl(id)}/comments`, {
    method: 'POST',
    credentials: 'include',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ comment: { body } }),
  })
  if (!res.ok) {
    // A 422 carries the validation messages in { errors: [...] }.
    const data: { errors?: string[] } | null = await res.json().catch(() => null)
    throw new Error(data?.errors?.join(' ') ?? 'Could not post the comment. Please try again.')
  }
  return res.json()
}

// Fire-and-forget: recording must never block or break the UI (FR-INT-08).
export function recordInteraction(id: number, eventType: RecordedEvent): void {
  void fetch(`${postUrl(id)}/interactions`, {
    method: 'POST',
    credentials: 'include',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ event_type: eventType }),
  }).catch(() => {})
}

// The image bytes. The API sends them as an attachment; the caller saves the Blob as a file.
export async function downloadImage(id: number): Promise<Blob> {
  const res = await fetch(`${postUrl(id)}/download`, { credentials: 'include' })
  if (!res.ok) throw new Error(`Download failed (${res.status})`)
  return res.blob()
}
