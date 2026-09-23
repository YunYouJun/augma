// Bind only the alias domain. The canonical host is never redirected to itself.
export default {
  fetch(request) {
    const url = new URL(request.url)
    if (url.hostname !== 'augma.yyj.moe')
      return new Response('Unknown host', { status: 404 })
    url.protocol = 'https:'
    url.hostname = 'augma.yunyoujun.cn'
    url.port = ''
    return Response.redirect(url.href, 308)
  },
}
