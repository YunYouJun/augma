import { defineConfig } from 'bumpp'

// Every file that states the release version. check-release and generate fail
// when they disagree, so bump them together.
export default defineConfig({
  files: [
    'package.json',
    'packages/core/package.json',
    'packages/augma/package.json',
    'scripts/catalog.mjs',
    'packages/augma/src/index.ts',
  ],
  commit: 'chore: release v%s',
  tag: 'v%s',
  push: true,
})
