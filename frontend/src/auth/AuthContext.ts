import { createContext } from 'react'
import type { User } from '../api/auth'

export type AuthStatus = 'loading' | 'signed-in' | 'signed-out'

export type Auth = {
  user: User | null
  status: AuthStatus
  /** Throws InvalidCredentialsError or Error, so the caller can show the message. */
  signIn: (email: string, password: string) => Promise<void>
  signOut: () => Promise<void>
}

// Provided by AuthProvider; read it with useAuth().
export const AuthContext = createContext<Auth | null>(null)
