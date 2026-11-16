// A phone's keyboard over the page. index.html's viewport meta asks `interactive-widget=resizes-content`, so an open
// keyboard shrinks the page and the message field stands on it; Safari on iOS ignores that and only shrinks the
// visual viewport, the layout viewport (`innerHeight`) staying whole. `followKeyboard` covers that case: while the
// visual viewport is shorter than the layout one by a keyboard's height at the page's own scale, the root's
// `--page-height` is the visual viewport's height (app/shell.css gives it to the body) and the page is kept at its
// top, so the field stands on the keyboard there too. Where the browser resized the page itself, both heights
// are equal and nothing is set; a zoom by pinching (scale over 1) is left alone.

/** Less than this between the two heights is a browser's toolbar, not a keyboard. */
const KEYBOARD_LEAST = 120;

/** Follows `win`'s visual viewport, while it has one, for as long as the page lives. */
export function followKeyboard(win: Window = window): void {
  const seen = win.visualViewport;
  if (!seen) return;
  const root = win.document.documentElement;
  const fit = () => {
    const open = seen.scale <= 1.01 && win.innerHeight - seen.height >= KEYBOARD_LEAST;
    if (!open) {
      root.style.removeProperty("--page-height");
      return;
    }
    root.style.setProperty("--page-height", `${Math.round(seen.height)}px`);
    // Safari may also pan the visual viewport inside the page (`offsetTop`), the page itself unscrolled.
    if (win.scrollY !== 0 || seen.offsetTop !== 0) win.scrollTo(0, 0);
  };
  seen.addEventListener("resize", fit);
  seen.addEventListener("scroll", fit);
  fit();
}
