import { useEffect, useState, type ReactNode } from 'react'
import { useNavigate } from 'react-router'
import { fetchMe, signIn as requestSignIn, signOut as requestSignOut, type User } from '../api/auth'
import { AuthContext, type AuthStatus } from './AuthContext'

// Who is signed in. The session cookie is HttpOnly, so the SPA asks GET /api/me instead of reading it.
export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null)
  const [status, setStatus] = useState<AuthStatus>('loading')
  const navigate = useNavigate()

  useEffect(() => {
    const controller = new AbortController()
    fetchMe(controller.signal)
      .then((me) => {
        if (controller.signal.aborted) return
        setUser(me)
        setStatus(me ? 'signed-in' : 'signed-out')
      })
      .catch(() => {
        // The API is unreachable: treat the visitor as anonymous, since the feed still works without a session.
        if (!controller.signal.aborted) setStatus('signed-out')
      })
    return () => controller.abort()
  }, [])

  async function signIn(email: string, password: string) {
    setUser(await requestSignIn(email, password))
    setStatus('signed-in')
  }

  async function signOut() {
    // Close any open post first: it was pinned on the personalised feed (CL-001). Replace, so Back doesn't reopen it.
    void navigate('/', { replace: true })
    // Sign out locally even if the request fails; the next GET /api/me shows the real state.
    await requestSignOut().catch(() => {})
    setUser(null)
    setStatus('signed-out')
  }

  return <AuthContext value={{ user, status, signIn, signOut }}>{children}</AuthContext>
}
