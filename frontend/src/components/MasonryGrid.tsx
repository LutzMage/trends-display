import type { ReactNode } from 'react'

type MasonryGridProps<T> = {
  items: T[]
  columns: number
  getKey: (item: T) => string | number
  renderItem: (item: T) => ReactNode
}

export function MasonryGrid<T>({ items, columns, getKey, renderItem }: MasonryGridProps<T>) {
  const buckets: T[][] = Array.from({ length: columns }, () => [])
  items.forEach((item, i) => buckets[i % columns].push(item))

  return (
    <div className="flex items-start gap-4">
      {buckets.map((bucket, col) => (
        <div key={col} className="flex min-w-0 flex-1 flex-col gap-4">
          {bucket.map((item) => (
            <div key={getKey(item)}>{renderItem(item)}</div>
          ))}
        </div>
      ))}
    </div>
  )
}
