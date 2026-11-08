// A long list drawn only where it is seen (`windowed`): of its items only the rows in and near the scroller's view are
// in the page; padding above and below the list stands for the rest, so the scrollbar, and the scroll position kept on
// coming back, are those of the whole list. Any list whose items are laid out in rows of equal columns (a column of
// rows, a grid of tiles) can use it as it is; search and filter stay on the data, which is drawn anew.
// Each item drawn says its place in the whole (`aria-posinset`, `aria-setsize`), for a screen reader; an item stays the
// same element while it stays near the view, so the one with the keyboard's focus keeps it while the list scrolls, and
// Tab at either end of what is drawn draws the next row first. A list drawn anew, or in a resized window, keeps its scroll.
// Trap: rows are measured once drawn; until then a row counts as tall as the average of those measured. The first item
// drawn always has an even place, so a list styled by `:nth-child(even)` alternates as the whole would.

/** Rows drawn above and below those in view. */
const AROUND = 6;
/** Items drawn first to measure the rows by. */
const SAMPLE = 24;

/** The first and last rows to draw (the last not included), of rows `heights` tall, for a view from `top` to `bottom`. */
export function rowsSeen(heights: ArrayLike<number>, top: number, bottom: number, around = AROUND): [number, number] {
  let first = 0;
  let at = 0;
  while (first < heights.length && at + heights[first] <= top) at += heights[first++];
  let last = first;
  while (last < heights.length && at < bottom) at += heights[last++];
  first = Math.max(0, first - around);
  return [first - (first % 2), Math.min(heights.length, last + around)];
}

export interface Windowed<T> {
  /** Draws `items` anew, each with `make`, from where the list is scrolled. */
  draw(items: T[], make: (item: T) => HTMLElement): void;
}

/** A list `list` in `scroller` that draws only the items seen; see the file's head. */
export function windowed<T>(list: HTMLElement, scroller: HTMLElement): Windowed<T> {
  let items: T[] = [];
  let make: (item: T) => HTMLElement = () => document.createElement("li");
  /** Items per row, and each row's height: measured, or the average of those measured. */
  let columns = 1;
  let heights = new Float64Array(0);
  let measured: boolean[] = [];
  /** The list's own padding, under that standing for the rows not drawn. */
  let pad = [0, 0];
  /** The items drawn now, from `from` on. */
  let from = 0;
  let drawn: HTMLElement[] = [];
  let width = -1;
  let pending = 0;

  const placed = (at: number): HTMLElement => {
    const node = make(items[at]);
    node.setAttribute("aria-posinset", String(at + 1));
    node.setAttribute("aria-setsize", String(items.length));
    return node;
  };

  /** Draws the items from `start` to `end`, keeping those already drawn among them. */
  function show(start: number, end: number): void {
    const keptFrom = Math.max(start, from);
    const keptTo = Math.min(end, from + drawn.length);
    if (keptFrom >= keptTo) {
      drawn = range(start, end).map(placed);
      list.replaceChildren(...drawn);
    } else {
      for (const node of drawn.slice(0, keptFrom - from)) node.remove();
      for (const node of drawn.slice(keptTo - from)) node.remove();
      const before = range(start, keptFrom).map(placed);
      const after = range(keptTo, end).map(placed);
      list.prepend(...before);
      list.append(...after);
      drawn = [...before, ...drawn.slice(keptFrom - from, keptTo - from), ...after];
    }
    from = start;
  }

  /** Whether the list is laid out (not hidden, and in the page). */
  const laidOut = () => drawn.length > 0 && drawn[0].offsetHeight > 0;

  /** Reads the heights of the rows drawn, and counts the others as their average. */
  function measure(): void {
    const firstRow = Math.floor(from / columns);
    const gap = parseFloat(getComputedStyle(list).rowGap) || 0;
    for (let at = 0; at < drawn.length; at += columns) {
      const row = drawn.slice(at, at + columns);
      const next = drawn[at + columns];
      const height = next ? next.offsetTop - row[0].offsetTop : Math.max(...row.map((node) => node.offsetHeight)) + gap;
      const index = firstRow + at / columns;
      if (index < heights.length && height > 0) {
        heights[index] = height;
        measured[index] = true;
      }
    }
    const known = measured.flatMap((yes, index) => (yes ? [heights[index]] : []));
    const average = known.reduce((sum, height) => sum + height, 0) / known.length;
    heights.forEach((_, index) => {
      if (!measured[index]) heights[index] = average;
    });
  }

  /** Draws the rows in and near the view, and pads the list for the others. */
  function update(): void {
    pending = 0;
    if (!laidOut()) return;
    measure();
    // Where the first row stands, from the top of the scroller's view.
    const top = list.getBoundingClientRect().top - scroller.getBoundingClientRect().top - scroller.clientTop + pad[0];
    place(...rowsSeen(heights, -top, -top + scroller.clientHeight));
    measure();
  }

  /** Draws the rows from `first` to `last` (not included), and pads the list for the others. */
  function place(first: number, last: number): void {
    show(first * columns, Math.min(items.length, last * columns));
    const sum = (a: number, b: number) => heights.slice(a, b).reduce((all, height) => all + height, 0);
    list.style.paddingTop = `${pad[0] + sum(0, first)}px`;
    list.style.paddingBottom = `${pad[1] + sum(last, heights.length)}px`;
  }

  const soon = () => {
    pending ||= requestAnimationFrame(update);
  };
  scroller.addEventListener("scroll", soon, { passive: true });
  // A wider or narrower window can hold another number of columns; a taller one shows more rows. An empty list keeps
  // what its screen put in it (the empty line).
  new ResizeObserver(() => {
    if (!items.length) return;
    if (scroller.clientWidth === width) return soon();
    width = scroller.clientWidth;
    restart();
  }).observe(scroller);
  // Tab from the last row drawn, or Shift+Tab from the first, goes on to the row beyond, drawn first; the view
  // follows the focus, and the list is drawn around it.
  list.addEventListener("keydown", (event) => {
    if (event.key !== "Tab" || !laidOut()) return;
    const at = drawn.findIndex((node) => node.contains(event.target as Node));
    if (at < 0) return;
    const [first, last] = [from / columns, Math.ceil((from + drawn.length) / columns)];
    if (!event.shiftKey && at >= drawn.length - columns && last < heights.length) place(first, last + 1);
    if (event.shiftKey && at < columns && first > 0) place(first - 2, last);
  });

  /** Measures the rows anew from the first items, and draws from where the list is scrolled. */
  function restart(): void {
    const kept = scroller.scrollTop;
    list.style.paddingTop = list.style.paddingBottom = "";
    const style = getComputedStyle(list);
    pad = [parseFloat(style.paddingTop) || 0, parseFloat(style.paddingBottom) || 0];
    from = 0;
    drawn = [];
    show(0, Math.min(items.length, SAMPLE));
    if (!laidOut()) return;
    const top = drawn[0].offsetTop;
    const second = drawn.findIndex((node) => node.offsetTop !== top);
    columns = second > 0 ? second : drawn.length;
    heights = new Float64Array(Math.ceil(items.length / columns));
    measured = [];
    // Reading the rows' places cut the scroll position down to the first rows; with the others stood in for it
    // is set again, so a list drawn anew stays where it was.
    measure();
    place(0, Math.ceil(drawn.length / columns));
    scroller.scrollTop = kept;
    update();
  }

  return {
    draw(next, maker) {
      [items, make] = [next, maker];
      restart();
    },
  };
}

function range(start: number, end: number): number[] {
  return Array.from({ length: Math.max(0, end - start) }, (_, at) => start + at);
}
