import { copyFile, mkdir } from 'node:fs/promises'

await mkdir('dist', { recursive: true })
for (const file of ['tokens.css', 'style.css'])
  await copyFile(`src/${file}`, `dist/${file}`)
