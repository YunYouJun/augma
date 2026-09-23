import { cp, mkdir } from 'node:fs/promises'

const dest = 'apps/site/.vitepress/dist'
await mkdir(`${dest}/ar`, { recursive: true })
await cp('apps/ar/dist', `${dest}/ar`, { recursive: true })
console.log('Assembled site + AR at apps/site/.vitepress/dist')
