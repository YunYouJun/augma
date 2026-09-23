import vue from '@vitejs/plugin-vue'
import { defineConfig } from 'vitest/config'

export default defineConfig({ plugins: [vue()], test: { environment: 'happy-dom', include: ['tests/components/**/*.test.ts'], restoreMocks: true } })
