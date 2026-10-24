import { fileURLToPath } from 'node:url'
import vue from '@vitejs/plugin-vue'
import { defineConfig } from 'vitest/config'

export default defineConfig({
  plugins: [vue()],
  // Unit tests run before package builds, including AR components that import the public Vue entry.
  resolve: {
    alias: [
      { find: /^augma$/, replacement: fileURLToPath(new URL('packages/augma/src/index.ts', import.meta.url)) },
      { find: '@augma/core/link-start', replacement: fileURLToPath(new URL('packages/core/src/link-start.ts', import.meta.url)) },
    ],
  },
  test: { environment: 'happy-dom', include: ['tests/components/**/*.test.ts'], restoreMocks: true },
})
