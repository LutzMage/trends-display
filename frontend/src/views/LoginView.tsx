import { useState, type FormEvent } from 'react'
import { Link, Navigate, useSearchParams } from 'react-router'
import { API_URL } from '../api/feed'
import { useAuth } from '../hooks/useAuth'

// Error codes the Google callback adds to /login?error=… (SPEC-002 §3.2).
const GOOGLE_ERRORS: Record<string, string> = {
  google_cancelled: 'Google sign-in was cancelled.',
  no_account: 'There is no account for this Google email.',
  email_unverified: 'Your Google email address is not verified.',
}
const GOOGLE_FAILED = 'Google sign-in failed. Please try again.'

const focusRing = 'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-neutral-900'
const inputClass = `mt-1 block w-full rounded-lg border border-neutral-300 px-3 py-2 text-neutral-900 ${focusRing}`

export function LoginView() {
  const { status, signIn } = useAuth()
  const [searchParams, setSearchParams] = useSearchParams()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [submitting, setSubmitting] = useState(false)
  const [formError, setFormError] = useState<string | null>(null)

  // Signing in flips the status, so this also handles the redirect after a successful submit.
  if (status === 'signed-in') return <Navigate to="/" replace />

  const googleError = searchParams.get('error')
  const message = formError ?? (googleError && (GOOGLE_ERRORS[googleError] ?? GOOGLE_FAILED))

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setSubmitting(true)
    setFormError(null)
    setSearchParams({}, { replace: true }) // a new attempt replaces any Google error

    try {
      await signIn(email, password)
    } catch (err) {
      setPassword('')
      // fetch rejects with a TypeError when the API can't be reached; the API's own errors carry a readable message.
      const offline = err instanceof TypeError
      setFormError(offline ? 'Could not reach the server. Please try again.' : (err as Error).message)
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <main className="flex min-h-svh items-center justify-center px-4 py-6">
      <div className="w-full max-w-sm rounded-2xl bg-white p-6 shadow-sm ring-1 ring-black/5">
        <h1 className="mb-6 text-center text-2xl font-bold text-neutral-900">
          <Link to="/" className={`rounded ${focusRing}`}>
            Trends
          </Link>
        </h1>

        {message && (
          <p role="alert" className="mb-4 rounded-lg bg-rose-50 px-3 py-2 text-sm text-rose-800">
            {message}
          </p>
        )}

        <form onSubmit={handleSubmit} className="space-y-4">
          <label className="block text-sm font-medium text-neutral-700">
            Email
            <input
              type="email"
              autoComplete="email"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className={inputClass}
            />
          </label>

          <label className="block text-sm font-medium text-neutral-700">
            Password
            <input
              type="password"
              autoComplete="current-password"
              required
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className={inputClass}
            />
          </label>

          <button
            type="submit"
            disabled={submitting}
            className={`w-full rounded-full bg-neutral-900 px-4 py-2 font-medium text-white hover:bg-neutral-700 disabled:opacity-60 ${focusRing}`}
          >
            {submitting ? 'Logging in…' : 'Log in'}
          </button>
        </form>

        <div className="my-4 flex items-center gap-3 text-sm text-neutral-500" aria-hidden>
          <span className="h-px flex-1 bg-neutral-200" />
          or
          <span className="h-px flex-1 bg-neutral-200" />
        </div>

        {/* A full-page navigation, not a fetch: the backend redirects to Auth0 and back. */}
        <a
          href={`${API_URL}/api/auth/google`}
          className={`block w-full rounded-full border border-neutral-300 px-4 py-2 text-center font-medium text-neutral-900 hover:bg-neutral-100 ${focusRing}`}
        >
          Continue with Google
        </a>
      </div>
    </main>
  )
}
