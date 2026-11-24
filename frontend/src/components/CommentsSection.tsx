import { useId, useState, type FormEvent, type Ref } from 'react'
import { Link } from 'react-router'
import { useAuth } from '../hooks/useAuth'
import { useComments } from '../hooks/useComments'
import { Avatar } from './Avatar'

// Keeps the open post short: two comments until the user asks for all (SPEC-003 §3.5).
const PREVIEW_COUNT = 2

const focusRing = 'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-neutral-900'

type CommentsSectionProps = {
  postId: number
  // The action row's Comment button focuses this input.
  inputRef: Ref<HTMLInputElement>
  onAdded: () => void
}

export function CommentsSection({ postId, inputRef, onAdded }: CommentsSectionProps) {
  const { user } = useAuth()
  const { comments, status, retry, add } = useComments(postId)
  const [expanded, setExpanded] = useState(false)
  const [body, setBody] = useState('')
  const [posting, setPosting] = useState(false)
  const [formError, setFormError] = useState<string | null>(null)
  const headingId = useId()
  const inputId = useId()

  const shown = expanded ? comments : comments.slice(0, PREVIEW_COUNT)

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (!body.trim() || posting) return

    setPosting(true)
    setFormError(null)
    try {
      await add(body)
      setBody('')
      onAdded()
    } catch (err) {
      // fetch rejects with a TypeError when the API can't be reached; the API's own errors carry a readable message.
      setFormError(err instanceof TypeError ? 'Could not reach the server. Please try again.' : (err as Error).message)
    } finally {
      setPosting(false)
    }
  }

  return (
    <section aria-labelledby={headingId} className="space-y-3 border-t border-neutral-100 pt-3">
      <h2 id={headingId} className="text-sm font-semibold text-neutral-900">
        Comments
      </h2>

      {status === 'loading' && <p className="text-sm text-neutral-500">Loading comments…</p>}

      {status === 'error' && (
        <div role="alert" className="flex items-center gap-3 text-sm text-neutral-700">
          <span>Could not load comments.</span>
          <button
            type="button"
            onClick={retry}
            className={`rounded-full bg-neutral-900 px-3 py-1 font-medium text-white hover:bg-neutral-700 ${focusRing}`}
          >
            Retry
          </button>
        </div>
      )}

      {status === 'ready' && comments.length === 0 && <p className="text-sm text-neutral-500">No comments yet.</p>}

      {shown.length > 0 && (
        <ul className={`space-y-3 ${expanded ? 'max-h-72 overflow-y-auto pr-1' : ''}`}>
          {shown.map((comment) => (
            <li key={comment.id} className="flex gap-3">
              <Avatar user={comment.user} />
              <div className="min-w-0 text-sm">
                <p className="font-semibold text-neutral-900">@{comment.user.username}</p>
                <p className="whitespace-pre-line break-words text-neutral-700">{comment.body}</p>
              </div>
            </li>
          ))}
        </ul>
      )}

      {comments.length > PREVIEW_COUNT && (
        <button
          type="button"
          aria-expanded={expanded}
          onClick={() => setExpanded((current) => !current)}
          className={`rounded text-sm font-medium text-neutral-600 hover:text-neutral-900 ${focusRing}`}
        >
          {expanded ? 'Show less' : `View all ${comments.length} comments`}
        </button>
      )}

      {user ? (
        <form onSubmit={handleSubmit} className="space-y-2">
          <div className="flex gap-2">
            <label htmlFor={inputId} className="sr-only">
              Add a comment
            </label>
            <input
              ref={inputRef}
              id={inputId}
              value={body}
              maxLength={250}
              placeholder="Add a comment"
              autoComplete="off"
              onChange={(e) => setBody(e.target.value)}
              className={`min-w-0 flex-1 rounded-full border border-neutral-300 px-4 py-1.5 text-sm text-neutral-900 ${focusRing}`}
            />
            <button
              type="submit"
              disabled={!body.trim() || posting}
              className={`rounded-full bg-neutral-900 px-4 py-1.5 text-sm font-medium text-white hover:bg-neutral-700 disabled:opacity-60 ${focusRing}`}
            >
              Post
            </button>
          </div>
          {formError && (
            <p role="alert" className="rounded-lg bg-rose-50 px-3 py-2 text-sm text-rose-800">
              {formError}
            </p>
          )}
        </form>
      ) : (
        <p className="text-sm text-neutral-600">
          <Link to="/login" className={`rounded font-medium text-neutral-900 underline ${focusRing}`}>
            Log in
          </Link>{' '}
          to comment
        </p>
      )}
    </section>
  )
}
