import { useEffect, useState } from 'react'

const BREAKPOINTS: [minWidth: number, columns: number][] = [
  [1280, 5],
  [1024, 4],
  [768, 3],
  [0, 2],
]

function columnsFor(width: number) {
  return BREAKPOINTS.find(([min]) => width >= min)![1]
}

export function useColumnCount() {
  const [columns, setColumns] = useState(() => columnsFor(window.innerWidth))

  useEffect(() => {
    const onResize = () => setColumns(columnsFor(window.innerWidth))
    window.addEventListener('resize', onResize)
    return () => window.removeEventListener('resize', onResize)
  }, [])

  return columns
}
