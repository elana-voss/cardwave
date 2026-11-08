// The theme and Compact the user chose, set before the page is drawn (a file, as the pages' policy runs no
// inline script). src/theme.ts keeps them, under these names; the companion's window takes the theme alone.
try {
  const theme = localStorage.getItem("theme");
  const themes = ["light", "dark", "downtempo", "outrun", "retrowave", "neonwave-dark", "neonwave-light"]; // the themes of src/theme.ts but the system's, written by tools/looks.py
  if (themes.includes(theme)) document.documentElement.dataset.theme = theme;
  const companion = document.documentElement.classList.contains("companion-page");
  if (!companion && localStorage.getItem("density") === "compact") document.documentElement.dataset.density = "compact";
} catch {
  // The browser keeps nothing: the system's theme, then.
}
