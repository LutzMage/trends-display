export function TextCard({ text, clamp = false }: { text: string; clamp?: boolean }) {
  return (
    <div className="bg-gradient-to-br from-rose-100 to-amber-100 p-5 text-lg font-medium leading-snug whitespace-pre-line text-neutral-800">
      <p className={clamp ? 'line-clamp-6' : undefined}>{text}</p>
    </div>
  )
}
