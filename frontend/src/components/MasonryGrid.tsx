import type { ReactNode } from 'react'

type MasonryGridProps<T> = {
  items: T[]
  columns: number
  getKey: (item: T) => string | number
  renderItem: (item: T) => ReactNode
  header?: ReactNode
  headerSpan?: number
}

export function MasonryGrid<T>({
  items,
  columns,
  getKey,
  renderItem,
  header,
  headerSpan,
}: MasonryGridProps<T>) {
  const buckets: T[][] = Array.from({ length: columns }, () => [])
  items.forEach((item, i) => buckets[i % columns].push(item))
  const span = header ? Math.min(headerSpan ?? 1, columns) : 0

  const renderColumn = (bucket: T[], col: number) => (
    <div key={col} className="flex min-w-0 flex-1 flex-col gap-4">
      {bucket.map((item) => (
        <div key={getKey(item)}>{renderItem(item)}</div>
      ))}
    </div>
  )

  return (
    <div className="flex items-start gap-4">
      {span > 0 && (
        <div className="flex min-w-0 flex-col gap-4" style={{ flex: span }}>
          {header}
          <div className="flex items-start gap-4">{buckets.slice(0, span).map(renderColumn)}</div>
        </div>
      )}
      {buckets.slice(span).map((bucket, i) => renderColumn(bucket, span + i))}
    </div>
  )
}
