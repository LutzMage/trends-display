import { useEffect, useState } from 'react'
import './App.css'

const API_URL = import.meta.env.VITE_API_URL ?? 'http://localhost:3000'

function App() {
  const [message, setMessage] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    fetch(`${API_URL}/api/hello`)
      .then((res) => res.json())
      .then((data) => setMessage(data.message))
      .catch(() => setError('Could not reach the Rails API'))
  }, [])

  return (
    <main>
      <h1>Trends Display</h1>
      {error && <p role="alert">{error}</p>}
      {!error && <p>{message ?? 'Loading...'}</p>}
    </main>
  )
}

export default App
