import { Route, Routes } from 'react-router'
import { useAuth } from './hooks/useAuth'
import { FeedView } from './views/FeedView'
import { LoginView } from './views/LoginView'

function App() {
  const { user, status } = useAuth()

  // Wait for GET /api/me so the feed is fetched once, for the right user. The key remounts the feed
  // (and reloads it from the top) whenever the signed-in user changes.
  // shortcut: renders nothing until /api/me answers (local and fast); show the feed skeleton if the wait becomes noticeable.
  const feed = status === 'loading' ? null : <FeedView key={user?.id ?? 'anonymous'} />

  return (
    <div className="min-h-svh bg-neutral-50">
      <Routes>
        {/* FeedView is a layout route so it stays mounted while a post is open. */}
        <Route path="/" element={feed}>
          <Route index element={null} />
          <Route path="posts/:postId" element={null} />
        </Route>
        <Route path="login" element={<LoginView />} />
      </Routes>
    </div>
  )
}

export default App
