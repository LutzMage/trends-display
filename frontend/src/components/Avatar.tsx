// Users have no profile picture yet, so comments show an initials avatar (SPEC-003 §3.5).
// Dark enough shades for white text; the same user always gets the same colour.
const COLORS = ['bg-rose-600', 'bg-orange-600', 'bg-emerald-700', 'bg-sky-700', 'bg-violet-600', 'bg-fuchsia-700']

type AvatarUser = { id: number; username: string }

export function Avatar({ user }: { user: AvatarUser }) {
  const initial = user.username.match(/[a-z0-9]/i)?.[0].toUpperCase() ?? '?'

  return (
    // Decorative: the username is always shown next to it.
    <span
      aria-hidden="true"
      className={`flex h-8 w-8 shrink-0 items-center justify-center rounded-full text-sm font-semibold text-white ${COLORS[user.id % COLORS.length]}`}
    >
      {initial}
    </span>
  )
}
