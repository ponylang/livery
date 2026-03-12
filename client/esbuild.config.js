import * as esbuild from "esbuild";

await esbuild.build({
  entryPoints: ["src/index.js"],
  bundle: true,
  format: "esm",
  outfile: "dist/livery.esm.js",
});

await esbuild.build({
  entryPoints: ["src/index.js"],
  bundle: true,
  format: "iife",
  globalName: "Livery",
  outfile: "dist/livery.iife.js",
  footer: { js: "window.LiveView = Livery.LiveView;" },
});
