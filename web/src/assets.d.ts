// A picture that is imported is its address in the built app.
declare module "*.png" {
  const address: string;
  export default address;
}

// A 3D model that is imported is its address in the built app (vite.config.ts: `assetsInclude`).
declare module "*.glb" {
  const address: string;
  export default address;
}

// A language's file of words, imported as its text (language/language.ts).
declare module "*.ftl?raw" {
  const text: string;
  export default text;
}

// Vite's import of several files by a pattern, read at once (`eager`) or each when asked for (language/language.ts).
interface ImportMeta {
  glob<T>(pattern: string, options: { query: string; import: string; eager: true }): Record<string, T>;
  glob<T>(pattern: string, options: { query: string; import: string }): Record<string, () => Promise<T>>;
}

// A file imported by its address (`?url`), which the build copies (figures/decoders.ts).
declare module "*?url" {
  const address: string;
  export default address;
}

// A worker of the app's own, bundled on its own, by its address (`?worker&url`; figures/decoders.ts).
declare module "*?worker&url" {
  const address: string;
  export default address;
}

// Three.js's Basis transcoder (Emscripten), a CommonJS module the build converts (figures/ktx2-worker.ts).
declare module "three/addons/libs/basis/basis_transcoder.js" {
  const BASIS: (module: object) => Promise<unknown>;
  export default BASIS;
}
