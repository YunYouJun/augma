import { defineConfig } from 'tsup'

export default defineConfig({
  entry: [
    'src/index.ts',
  ],
  format: [
    'esm',
    'cjs',
  ],
  splitting: true,
  dts: true,
  clean: true,
  shims: false,
  external: [
    /@augma/,
  ],
})
