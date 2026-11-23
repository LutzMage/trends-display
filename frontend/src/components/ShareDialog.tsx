import { useEffect, useId, useRef, useState, type ComponentType } from 'react'
import { recordInteraction } from '../api/interactions'
import { useAuth } from '../hooks/useAuth'
import { CloseIcon, DiscordIcon, FacebookIcon, InstagramIcon, MessengerIcon, WhatsAppIcon, XIcon } from './icons'

type ShareTarget = { name: string; Icon: ComponentType<{ className?: string }>; color: string } & (
  | { shareUrl: (link: string) => string }
  // No web link shares a URL on these: copy the link, then open the service (SPEC-003 §3.6).
  | { site: string }
)

const SHARE_TARGETS: ShareTarget[] = [
  {
    name: 'Facebook',
    Icon: FacebookIcon,
    color: 'text-[#0866FF]',
    shareUrl: (link) => `https://www.facebook.com/sharer/sharer.php?u=${encodeURIComponent(link)}`,
  },
  { name: 'X', Icon: XIcon, color: 'text-black', shareUrl: (link) => `https://x.com/intent/tweet?url=${encodeURIComponent(link)}` },
  { name: 'Instagram', Icon: InstagramIcon, color: 'text-[#FF0069]', site: 'https://www.instagram.com/' },
  { name: 'Discord', Icon: DiscordIcon, color: 'text-[#5865F2]', site: 'https://discord.com/app' },
  { name: 'Messenger', Icon: MessengerIcon, color: 'text-[#00B2FF]', site: 'https://www.messenger.com/' },
  { name: 'WhatsApp', Icon: WhatsAppIcon, color: 'text-[#25D366]', shareUrl: (link) => `https://wa.me/?text=${encodeURIComponent(link)}` },
]

const focusRing = 'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-neutral-900'

// Rendered only while open, so every opening starts with no message. Closing (Escape, ×, backdrop) calls onClose.
export function ShareDialog({ postId, onClose }: { postId: number; onClose: () => void }) {
  const { user } = useAuth()
  const dialogRef = useRef<HTMLDialogElement>(null)
  const linkRef = useRef<HTMLInputElement>(null)
  const [message, setMessage] = useState('')
  const [copied, setCopied] = useState(false)
  const titleId = useId()
  const linkId = useId()
  const link = `${window.location.origin}/posts/${postId}`

  // showModal makes the page behind inert and traps focus; closing returns focus to the Share button.
  useEffect(() => {
    const dialog = dialogRef.current
    if (dialog && !dialog.open) dialog.showModal()
  }, [])

  const close = () => dialogRef.current?.close()

  function recordShare() {
    if (user) recordInteraction(postId, 'share')
  }

  async function copyLink(): Promise<boolean> {
    try {
      await navigator.clipboard.writeText(link)
      return true
    } catch {
      linkRef.current?.select()
      setMessage('Press Ctrl+C to copy the link.')
      return false
    }
  }

  async function handleCopy() {
    recordShare()
    if (!(await copyLink())) return
    setCopied(true)
    setMessage('Link copied.')
    setTimeout(() => setCopied(false), 2000)
  }

  async function handleTarget(target: ShareTarget) {
    recordShare()
    if ('shareUrl' in target) {
      window.open(target.shareUrl(link), '_blank', 'noopener,noreferrer')
      return
    }
    // Copy first, while the click still counts as a user action, then open the service.
    if (await copyLink()) setMessage(`Link copied. Paste it in ${target.name}.`)
    window.open(target.site, '_blank', 'noopener,noreferrer')
  }

  return (
    <dialog
      ref={dialogRef}
      aria-labelledby={titleId}
      onClose={onClose}
      // A click on the dialog element itself is a click on the backdrop: the content fills it.
      onClick={(e) => e.target === e.currentTarget && close()}
      className="m-auto w-[calc(100%-2rem)] max-w-md rounded-2xl bg-white p-0 shadow-xl backdrop:bg-black/50"
    >
      <div className="space-y-5 p-5">
        <div className="flex items-center justify-between">
          <h2 id={titleId} className="text-lg font-semibold text-neutral-900">
            Share
          </h2>
          <button
            type="button"
            aria-label="Close"
            onClick={close}
            className={`rounded-full p-1.5 text-neutral-700 hover:bg-neutral-100 ${focusRing}`}
          >
            <CloseIcon className="h-5 w-5" />
          </button>
        </div>

        <ul className="grid grid-cols-3 gap-2">
          {SHARE_TARGETS.map((target) => (
            <li key={target.name}>
              <button
                type="button"
                onClick={() => void handleTarget(target)}
                className={`flex w-full flex-col items-center gap-1.5 rounded-xl p-2 text-sm text-neutral-700 hover:bg-neutral-100 ${focusRing}`}
              >
                <target.Icon className={`h-8 w-8 ${target.color}`} />
                {target.name}
              </button>
            </li>
          ))}
        </ul>

        <div className="flex gap-2">
          <label htmlFor={linkId} className="sr-only">
            Post link
          </label>
          <input
            ref={linkRef}
            id={linkId}
            readOnly
            value={link}
            onFocus={(e) => e.currentTarget.select()}
            className={`min-w-0 flex-1 rounded-full border border-neutral-300 px-4 py-1.5 text-sm text-neutral-700 ${focusRing}`}
          />
          <button
            type="button"
            onClick={() => void handleCopy()}
            className={`shrink-0 rounded-full bg-neutral-900 px-4 py-1.5 text-sm font-medium text-white hover:bg-neutral-700 ${focusRing}`}
          >
            {copied ? 'Copied!' : 'Copy link'}
          </button>
        </div>

        <p aria-live="polite" className="min-h-5 text-sm text-neutral-600">
          {message}
        </p>
      </div>
    </dialog>
  )
}
