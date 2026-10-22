import { fileURLToPath } from 'node:url'
import vue from '@vitejs/plugin-vue'
import { defineConfig } from 'vitest/config'

export default defineConfig({
  plugins: [vue()],
  // Test the workspace source rather than core's built output.
  resolve: { alias: { '@augma/core/link-start': fileURLToPath(new URL('packages/core/src/link-start.ts', import.meta.url)) } },
  test: { environment: 'happy-dom', include: ['tests/components/**/*.test.ts'], restoreMocks: true },
})
