import { createReadStream } from 'node:fs'
import { stat } from 'node:fs/promises'
import { createServer } from 'node:http'
import { extname, resolve, sep } from 'node:path'
import process from 'node:process'

const root = resolve('apps/site/.vitepress/dist')
const port = Number(process.env.AUGMA_PREVIEW_PORT || 4317)
const types = { '.html': 'text/html; charset=utf-8', '.css': 'text/css', '.js': 'text/javascript', '.json': 'application/json', '.txt': 'text/plain; charset=utf-8', '.md': 'text/plain; charset=utf-8', '.vue': 'text/plain; charset=utf-8', '.svg': 'image/svg+xml', '.png': 'image/png', '.woff2': 'font/woff2', '.xml': 'application/xml' }
const server = createServer(async (request, response) => {
  let pathname
  try {
    pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname)
  }
  catch {
    response.writeHead(400).end('Invalid URL')
    return
  }
  const path = resolve(root, `.${pathname}`)
  if (path !== root && !path.startsWith(root + sep)) {
    response.writeHead(403).end()
    return
  }
  const candidates = [path, `${path}.html`, resolve(path, 'index.html')]
  let file
  for (const candidate of candidates) {
    if (await stat(candidate).then(s => s.isFile()).catch(() => false)) {
      file = candidate
      break
    }
  }
  response.statusCode = file ? 200 : 404
  file ||= resolve(root, '404.html')
  response.setHeader('Content-Type', types[extname(file)] || 'application/octet-stream')
  response.setHeader('Cache-Control', 'no-cache')
  if (request.method === 'HEAD') {
    response.end()
    return
  }
  createReadStream(file).on('error', () => response.end('Run pnpm build first.')).pipe(response)
})
server.listen(port, '127.0.0.1', () => console.log(`Augma preview: http://127.0.0.1:${port}/`))
