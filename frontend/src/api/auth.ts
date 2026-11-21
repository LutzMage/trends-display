import { API_URL } from './feed'

// The session JWT lives in an HttpOnly cookie that JavaScript cannot read (SPEC-002 §4.2).
// `credentials: 'include'` makes the browser send it to the API, which is on another origin.

export type User = { id: number; username: string; email: string }

export class InvalidCredentialsError extends Error {
  constructor() {
    super('Invalid email or password')
    this.name = 'InvalidCredentialsError'
  }
}

export async function signIn(email: string, password: string): Promise<User> {
  const res = await fetch(`${API_URL}/api/auth/sign_in`, {
    method: 'POST',
    credentials: 'include',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password }),
  })
  if (res.status === 401) throw new InvalidCredentialsError()
  if (!res.ok) throw new Error(await errorMessage(res, 'Sign-in failed'))
  return res.json()
}

export async function signOut(): Promise<void> {
  const res = await fetch(`${API_URL}/api/auth/sign_out`, { method: 'DELETE', credentials: 'include' })
  if (!res.ok) throw new Error(await errorMessage(res, 'Sign-out failed'))
}

// The signed-in user, or null when there is no valid session.
export async function fetchMe(signal?: AbortSignal): Promise<User | null> {
  const res = await fetch(`${API_URL}/api/me`, { credentials: 'include', signal })
  if (res.status === 401) return null
  if (!res.ok) throw new Error(`Session check failed (${res.status})`)
  return res.json()
}

// Uses the API's `{ error }` message when there is one, e.g. the 429 "Too many attempts" text.
async function errorMessage(res: Response, fallback: string): Promise<string> {
  const body: { error?: string } | null = await res.json().catch(() => null)
  return body?.error ?? `${fallback} (${res.status})`
}
