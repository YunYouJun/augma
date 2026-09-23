import process from 'node:process'
import { defineConfig, devices } from '@playwright/test'

export default defineConfig({
  testDir: 'tests/browser',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  reporter: 'list',
  outputDir: process.env.PLAYWRIGHT_OUTPUT_DIR || '/tmp/augma-playwright-results',
  use: { baseURL: 'http://127.0.0.1:4317', trace: 'retain-on-failure' },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }, { name: 'firefox', use: { ...devices['Desktop Firefox'] } }, { name: 'webkit', use: { ...devices['Desktop Safari'] } }],
  webServer: { command: 'pnpm preview', url: 'http://127.0.0.1:4317', reuseExistingServer: false },
})
