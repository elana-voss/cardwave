// The icons: line drawings on a 24 × 24 grid. styles.css gives them their stroke.
//
// A new icon is a line here.
const SHAPES = {
  archive: '<path d="M4 5h16v4H4zM6 9v10h12V9M10 13h4"/>',
  branch: '<circle cx="6" cy="5" r="2"/><circle cx="6" cy="19" r="2"/><circle cx="18" cy="7" r="2"/><path d="M6 7v10M18 9a6 6 0 0 1-6 6H8"/>',
  chat: '<path d="M4 5h16v11H9l-5 4z"/>',
  "chat-plus": '<path d="M4 5h16v11H9l-5 4z"/><path d="M12 8v5M9.5 10.5h5"/>',
  check: '<path d="M5 12l5 5 9-10"/>',
  clip: '<path d="M8 12l6.5-6.5a3 3 0 0 1 4.2 4.2L10 18.4a5 5 0 0 1-7-7L10 4.5"/>',
  clock: '<circle cx="12" cy="12" r="8"/><path d="M12 8v4l3 2"/>',
  close: '<path d="M6 6l12 12M18 6L6 18"/>',
  code: '<path d="M8 8l-4 4 4 4M16 8l4 4-4 4M13 6l-2 12"/>',
  continue: '<path d="M5 12h10M11 6l6 6-6 6M19 6v12"/>',
  copy: '<path d="M9 9h11v11H9zM5 15H4V4h11v1"/>',
  document: '<path d="M6 3h8l4 4v14H6zM14 3v4h4M9 12h6M9 16h6"/>',
  default: '<circle cx="12" cy="12" r="8"/><path d="M8.5 12l2.5 2.5 4.5-5"/>',
  discovery: '<path d="M4 5h6v14H4zM13 7h7M13 11h7M13 15h5"/>',
  down: '<path d="M6 9l6 6 6-6"/>',
  edit: '<path d="M4 20h4L19 9l-4-4L4 16z"/>',
  expressions: '<circle cx="12" cy="12" r="8"/><path d="M9 14.5c.8 1 1.8 1.5 3 1.5s2.2-.5 3-1.5M9.5 10h.01M14.5 10h.01"/>',
  figure: '<circle cx="12" cy="4.5" r="2.5"/><path d="M12 7.5v7.5M6 10.5h12M12 15l-3.5 6M12 15l3.5 6"/>',
  export: '<path d="M12 4v11M7 10l5 5 5-5M5 20h14"/>',
  eye: '<path d="M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12z"/><circle cx="12" cy="12" r="3"/>',
  generator: '<circle cx="10" cy="8" r="4"/><path d="M3 20c1.4-3.8 4-6 7-6 1.5 0 2.9.5 4 1.4M18 14v6M15 17h6"/>',
  interview: '<circle cx="9" cy="9" r="3.5"/><path d="M3 20c1.3-3.4 3.4-5.2 6-5.2s4.7 1.8 6 5.2M14 3h7v5h-3.5L15 10V8h-1z"/>',
  gallery: '<path d="M4 4h7v7H4zM13 4h7v7h-7zM4 13h7v7H4zM13 13h7v7h-7z"/>',
  go: '<path d="M7 17L17 7M9 7h8v8"/>',
  globe: '<circle cx="12" cy="12" r="8"/><path d="M4 12h16M12 4c2.6 2.4 2.6 13.6 0 16M12 4c-2.6 2.4-2.6 13.6 0 16"/>',
  gear: '<circle cx="12" cy="12" r="3"/><path d="M19 10.3L21.5 10.5 21.5 13.5 19 13.7 18.2 15.7 19.8 17.6 17.6 19.8 15.7 18.2 13.7 19 13.5 21.5 10.5 21.5 10.3 19 8.3 18.2 6.4 19.8 4.2 17.6 5.8 15.7 5 13.7 2.5 13.5 2.5 10.5 5 10.3 5.8 8.3 4.2 6.4 6.4 4.2 8.3 5.8 10.3 5 10.5 2.5 13.5 2.5 13.7 5 15.7 5.8 17.6 4.2 19.8 6.4 18.2 8.3z"/>',
  info: '<circle cx="12" cy="12" r="8.5"/><path d="M12 11v5M12 8h.01"/>',
  import: '<path d="M12 15V4M7 9l5-5 5 5M5 20h14"/>',
  knowledge: '<circle cx="12" cy="9" r="5"/><path d="M9.5 14v3h5v-3M10 20h4"/>',
  lock: '<rect x="5" y="11" width="14" height="9" rx="1"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/>',
  left: '<path d="M15 6l-6 6 6 6"/>',
  library: '<path d="M5 4h4v16H5zM10 4h4v16h-4zM15.5 5.5l3.8 1-3.6 13.5-3.8-1z"/>',
  list: '<path d="M9 6h11M9 12h11M9 18h11M4.5 6h.01M4.5 12h.01M4.5 18h.01"/>',
  lorebook: '<path d="M5 4h11a3 3 0 0 1 3 3v13H8a3 3 0 0 1-3-3zM5 17a3 3 0 0 1 3-3h11"/>',
  longer: '<path d="M5 6h14M5 11h14M5 16h14M5 21h8"/>',
  maximize: '<path d="M6.5 6.5h11v11h-11z"/>',
  menu: '<path d="M4 7h16M4 12h16M4 17h16"/>',
  minimize: '<path d="M6 12h12"/>',
  modes: '<rect x="4" y="5" width="7" height="6" rx="1.5"/><rect x="13" y="5" width="7" height="6" rx="1.5"/><rect x="4" y="13" width="7" height="6" rx="1.5"/><rect x="13" y="13" width="7" height="6" rx="1.5"/>',
  more: '<g fill="currentColor"><circle cx="6" cy="12" r="1.3"/><circle cx="12" cy="12" r="1.3"/><circle cx="18" cy="12" r="1.3"/></g>',
  mic: '<rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5 11a7 7 0 0 0 14 0M12 18v3"/>',
  panel: '<path d="M4 5h16v14H4zM15 5v14"/>',
  person: '<circle cx="12" cy="8" r="4"/><path d="M4 20c1.5-4 4.5-6 8-6s6.5 2 8 6"/>',
  persona: '<rect x="3.5" y="3.5" width="17" height="17" rx="4"/><circle cx="12" cy="10" r="3"/><path d="M7 17c1-2.4 2.8-3.6 5-3.6s4 1.2 5 3.6"/>',
  picture: '<path d="M4 5h16v14H4zM4 16l5-5 4 4 3-3 4 4"/><circle cx="15.5" cy="9" r="1.5"/>',
  play: '<path d="M8 5l11 7-11 7z"/>',
  plus: '<path d="M12 5v14M5 12h14"/>',
  reply: '<path d="M10 7l-5 5 5 5M5 12h9a5 5 0 0 1 5 5v1"/>',
  regenerate: '<path d="M20 12a8 8 0 1 1-2.3-5.7M20 4v5h-5"/>',
  right: '<path d="M9 6l6 6-6 6"/>',
  robot: '<rect x="5" y="8" width="14" height="11" rx="2"/><circle cx="12" cy="4.5" r="1.2"/><path d="M12 5.7V8M9.5 13h.01M14.5 13h.01M10 16h4M3 12v3M21 12v3"/>',
  newtab: '<path d="M14 4h6v6M20 4l-8 8"/><path d="M18 14v5a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1h5"/>',
  search: '<circle cx="11" cy="11" r="6"/><path d="M20 20l-4.5-4.5"/>',
  send: '<path d="M5 12h14M13 6l6 6-6 6"/>',
  server: '<path d="M4 5h16v6H4zM4 13h16v6H4zM8 8h.01M8 16h.01"/>',
  shorter: '<path d="M5 9h14M5 15h8"/>',
  sliders: '<path d="M4 6h9M17 6h3M4 12h3M11 12h9M4 18h11M19 18h1"/>',
  speaker: '<path d="M4 9h4l5-4v14l-5-4H4zM16.5 8.5a5 5 0 0 1 0 7M19 6a8.5 8.5 0 0 1 0 12"/>',
  "speaker-off": '<path d="M4 9h4l5-4v14l-5-4H4zM16 9.5l5 5M21 9.5l-5 5"/>',
  split: '<rect x="3" y="5" width="8" height="14" rx="1.5"/><path d="M14 6h7v9h-4l-3 3z"/>',
  sparkle: '<path d="M12 4v4M12 16v4M4 12h4M16 12h4M6.5 6.5l2.5 2.5M15 15l2.5 2.5M6.5 17.5L9 15M15 9l2.5-2.5"/>',
  star: '<path d="M12 4l2.4 5 5.4.6-4 3.7 1.1 5.3L12 16l-4.9 2.6 1.1-5.3-4-3.7 5.4-.6z"/>',
  stop: '<path d="M7 7h10v10H7z"/>',
  switch: '<path d="M15 4h4v16h-4M10 8l-4 4 4 4M6 12h10"/>',
  trash: '<path d="M5 7h14M10 7V4h4v3M7 7l1 13h8l1-13"/>',
  undo: '<path d="M9 7L4 12l5 5M4 12h11a5 5 0 0 1 0 10h-2"/>',
  up: '<path d="M6 15l6-6 6 6"/>',
} as const;

export type IconName = keyof typeof SHAPES;

/** An icon as a picture without a name: what it is for is said by the control it is in. */
export function icon(name: IconName, size = 18): SVGSVGElement {
  const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
  svg.setAttribute("width", String(size));
  svg.setAttribute("height", String(size));
  svg.setAttribute("viewBox", "0 0 24 24");
  svg.setAttribute("aria-hidden", "true");
  svg.innerHTML = SHAPES[name];
  return svg;
}
