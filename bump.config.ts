import { defineConfig } from 'bumpp'

// Every file that states the release version. check-release and generate fail
// when they disagree, so bump them together. The Skill references are generated,
// but they are committed and CI checks them, so the release commit updates them too.
export default defineConfig({
  files: [
    'package.json',
    'packages/core/package.json',
    'packages/augma/package.json',
    'scripts/catalog.mjs',
    'packages/augma/src/index.ts',
    'skills/augma/references/components.md',
    'skills/augma/references/recipes.md',
  ],
  commit: 'chore: release v%s',
  tag: 'v%s',
  push: true,
})
