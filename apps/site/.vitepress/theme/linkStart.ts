import { linkStart } from 'augma'
import { useRouter } from 'vitepress'

/**
 * Click handler for "Link Start" links: plays the light tunnel, then follows the link with the
 * VitePress router (or jumps to the anchor on this page). Modified and middle clicks keep the
 * browser's own behaviour, and `prefers-reduced-motion` navigates at once.
 *
 * The link needs `target="_self"`: VitePress's router handles same-origin link clicks in the capture
 * phase, before this handler, unless the link has a target.
 *
 * @param leaving - Selector for the page being left; the tunnel fades once it is gone
 *
 * @example
 * ```vue
 * <a :href="link('/guide/')" target="_self" @click="onLinkStart">Link Start</a>
 * ```
 */
export function useLinkStart(leaving?: string) {
  const router = useRouter()
  return (event: MouseEvent) => {
    const anchor = event.currentTarget
    if (!(anchor instanceof HTMLAnchorElement) || event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey)
      return
    event.preventDefault()
    const url = new URL(anchor.href)
    const samePage = url.pathname === location.pathname
    void linkStart(
      () => samePage ? (location.hash = url.hash) : router.go(url.pathname + url.search + url.hash),
      { waitFor: samePage ? undefined : leaving },
    )
  }
}
