// @vitest-environment node
import { describe, expect, it } from 'vitest'
import worker from '../../deploy/redirect/worker.mjs'

describe('canonical domain redirect', () => {
  it('preserves encoded paths and repeated query parameters over HTTPS', () => {
    const response = worker.fetch(
      new Request(
        'http://augma.yyj.moe/components/button?theme=dark&x=1&x=2&q=%E7%95%8C%E9%9D%A2',
      ),
    )
    expect(response.status).toBe(308)
    expect(response.headers.get('Location')).toBe(
      'https://augma.yunyoujun.cn/components/button?theme=dark&x=1&x=2&q=%E7%95%8C%E9%9D%A2',
    )
  })
  it('does not create a loop or accept arbitrary hosts', () => {
    expect(
      worker.fetch(new Request('https://augma.yunyoujun.cn/')).status,
    ).toBe(404)
    expect(worker.fetch(new Request('https://example.com/')).status).toBe(404)
  })
})
