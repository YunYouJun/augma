// Captures README / Open Graph media from the built site (run `pnpm build` first).
// Requires ffmpeg (AR clip) and the libwebp tools cwebp / gif2webp (`brew install webp`).
// README media are WebP; the Open Graph image stays JPEG for link-preview crawlers.
import { execFileSync, spawn } from 'node:child_process'
import { mkdir, mkdtemp, readdir, rm } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import process from 'node:process'
import { chromium } from '@playwright/test'

const port = 4391
const base = `http://127.0.0.1:${port}`
const docs = 'docs/media'
const site = 'apps/site/public'
await mkdir(docs, { recursive: true })
await mkdir(`${site}/media`, { recursive: true })

const server = spawn(process.execPath, ['scripts/preview.mjs'], { env: { ...process.env, AUGMA_PREVIEW_PORT: String(port) }, stdio: 'ignore' })
for (let i = 0; i < 50; i++) {
  if (await fetch(base).then(r => r.ok, () => false))
    break
  await new Promise(r => setTimeout(r, 100))
}

const browser = await chromium.launch()
try {
  const stills = await mkdtemp(join(tmpdir(), 'augma-stills-'))
  for (const [name, options] of [
    ['home-light', { viewport: { width: 1440, height: 900 }, colorScheme: 'light' }],
    ['og', { viewport: { width: 1200, height: 630 }, colorScheme: 'light' }],
  ]) {
    const context = await browser.newContext(options)
    const page = await context.newPage()
    await page.goto(`${base}/`, { waitUntil: 'networkidle' })
    // The clip re-renders with autoplay after hydration; seek only that element.
    await page.locator('.ar-demo-media video[autoplay]').waitFor({ state: 'attached' })
    // Hold the AR clip on the weather frame so captures are stable. The local preview
    // server has no Range support, so let the looping clip play into the window instead of seeking.
    await page.evaluate(async () => {
      await document.fonts.ready
      for (const video of document.querySelectorAll('video')) {
        await video.play().catch(() => {})
        await new Promise((resolve) => {
          const tick = () => video.currentTime >= 1.2 && video.currentTime < 1.6 ? resolve() : requestAnimationFrame(tick)
          tick()
        })
        video.pause()
      }
      // Freeze every time-based animation at one moment: entrances have settled,
      // the rings sit at a fixed angle and the hex-field scan band crosses the hero.
      // Scroll-driven reveals are dropped so sections show in their final state.
      for (const animation of document.getAnimations()) {
        if (animation.timeline !== document.timeline) {
          animation.cancel()
          continue
        }
        animation.pause()
        animation.currentTime = 3000
      }
      await new Promise(r => requestAnimationFrame(() => requestAnimationFrame(r)))
    })
    if (name === 'og') {
      await page.screenshot({ path: `${site}/og.jpg`, type: 'jpeg', quality: 82 })
    }
    else {
      const png = join(stills, `${name}.png`)
      await page.screenshot({ path: png })
      execFileSync('cwebp', ['-quiet', '-q', '82', png, '-o', `${docs}/${name}.webp`])
    }
    await context.close()
  }
  await rm(stills, { recursive: true })

  const videoDir = await mkdtemp(join(tmpdir(), 'augma-ar-'))
  const size = { width: 1280, height: 800 }
  const context = await browser.newContext({ viewport: size, recordVideo: { dir: videoDir, size } })
  const page = await context.newPage()
  const started = Date.now()
  await page.goto(`${base}/ar/`, { waitUntil: 'networkidle' })
  await page.waitForTimeout(400)
  const offset = (Date.now() - started) / 1000
  const pause = ms => page.waitForTimeout(ms)
  const button = name => page.getByRole('button', { name, exact: true })
  await button('天气').click()
  await pause(1600)
  await page.keyboard.press('Escape')
  await button('空间').click()
  await pause(400)
  await button('扫描空间').click()
  await page.getByText('已识别 3 个空间锚点').waitFor()
  await pause(500)
  await button('选择中央绿洲').click()
  await pause(500)
  await page.getByRole('button', { name: '导航到这里' }).click()
  await pause(900)
  for (let i = 0; i < 3; i++) {
    await page.getByRole('button', { name: '前进一步' }).click()
    await pause(650)
  }
  const duration = (Date.now() - started) / 1000 - offset
  await context.close()
  const [webm] = (await readdir(videoDir)).filter(f => f.endsWith('.webm'))
  const raw = join(videoDir, webm)
  const trim = ['-y', '-loglevel', 'error', '-ss', offset.toFixed(2), '-t', duration.toFixed(2), '-i', raw]
  execFileSync('ffmpeg', [...trim, '-an', '-vf', 'scale=960:-2', '-c:v', 'libvpx-vp9', '-b:v', '0', '-crf', '40', `${site}/media/ar-demo.webm`])
  execFileSync('ffmpeg', [...trim, '-an', '-vf', 'scale=960:-2', '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '30', '-movflags', '+faststart', `${site}/media/ar-demo.mp4`])
  execFileSync('ffmpeg', ['-y', '-loglevel', 'error', '-ss', (offset + duration - 0.3).toFixed(2), '-i', raw, '-frames:v', '1', '-vf', 'scale=960:-2', '-q:v', '4', `${site}/media/ar-demo-poster.jpg`])
  // ffmpeg builds often lack a WebP encoder: render a palette GIF, then convert it.
  const gif = join(videoDir, 'ar-demo.gif')
  execFileSync('ffmpeg', [...trim, '-vf', 'fps=10,scale=640:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=96[p];[b][p]paletteuse=dither=bayer', gif])
  execFileSync('gif2webp', ['-quiet', '-lossy', '-q', '70', '-m', '6', gif, '-o', `${docs}/ar-demo.webp`])
  await rm(videoDir, { recursive: true })
  console.log(`AR clip: ${duration.toFixed(1)}s`)
}
finally {
  await browser.close()
  server.kill()
}
