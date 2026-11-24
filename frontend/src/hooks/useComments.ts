import { useCallback, useEffect, useState } from 'react'
import { createComment, fetchComments, type Comment } from '../api/interactions'

type Status = 'loading' | 'ready' | 'error'

// A post's comments, newest first (SPEC-003 §3.5). The open post is keyed by id,
// so another post mounts a fresh hook rather than changing `postId` here.
export function useComments(postId: number) {
  const [comments, setComments] = useState<Comment[]>([])
  const [status, setStatus] = useState<Status>('loading')
  const [attempt, setAttempt] = useState(0)

  useEffect(() => {
    const controller = new AbortController()
    fetchComments(postId, controller.signal)
      .then((list) => {
        if (controller.signal.aborted) return
        setComments(list)
        setStatus('ready')
      })
      .catch(() => {
        if (!controller.signal.aborted) setStatus('error')
      })

    return () => controller.abort()
  }, [postId, attempt])

  const retry = useCallback(() => {
    setStatus('loading')
    setAttempt((n) => n + 1)
  }, [])

  // Posts a comment and puts it at the top. Rethrows on failure, so the form can keep the text and show why.
  const add = useCallback(
    async (body: string) => {
      const comment = await createComment(postId, body)
      setComments((current) => [comment, ...current])
    },
    [postId],
  )

  return { comments, status, retry, add }
}
