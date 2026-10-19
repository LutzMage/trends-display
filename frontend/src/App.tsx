import { Route, Routes } from 'react-router'
import { FeedView } from './views/FeedView'

function App() {
  return (
    <div className="min-h-svh bg-neutral-50">
      <Routes>
        {/* FeedView is a layout route so it stays mounted while a post is open. */}
        <Route path="/" element={<FeedView />}>
          <Route index element={null} />
          <Route path="posts/:postId" element={null} />
        </Route>
      </Routes>
    </div>
  )
}

export default App
