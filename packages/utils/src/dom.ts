import { isServer } from '@augma/utils'
import { camelize } from '@vue/shared'

function trim(s: string) {
  return (s || '').replace(/^\s+|\s+$/g, '')
}

export function on(element: HTMLElement | Document | Window, event: string, handler: EventListenerOrEventListenerObject, useCapture = false): void {
  if (element && event && handler)
    element.addEventListener(event, handler, useCapture)
}

export function off(element: HTMLElement | Document | Window, event: string, handler: EventListenerOrEventListenerObject): void {
  if (element && event && handler)
    element.removeEventListener(event, handler, false)
}

export function hasClass(el: HTMLElement, cls: string): boolean {
  if (!el || !cls)
    return false
  if (cls.includes(' '))
    throw new Error('className should not contain space.')
  if (el.classList)
    return el.classList.contains(cls)
  else
    return (` ${el.className} `).includes(` ${cls} `)
}

export function addClass(el: HTMLElement, cls: string): void {
  if (!el)
    return
  let curClass = el.className
  const classes = (cls || '').split(' ')

  for (let i = 0, j = classes.length; i < j; i++) {
    const clsName = classes[i]
    if (!clsName)
      continue

    if (el.classList)
      el.classList.add(clsName)
    else if (!hasClass(el, clsName))
      curClass += ` ${clsName}`
  }
  if (!el.classList)
    el.className = curClass
}

export function removeClass(el: HTMLElement, cls: string): void {
  if (!el || !cls)
    return
  const classes = cls.split(' ')
  let curClass = ` ${el.className} `

  for (let i = 0, j = classes.length; i < j; i++) {
    const clsName = classes[i]
    if (!clsName)
      continue

    if (el.classList)
      el.classList.remove(clsName)
    else if (hasClass(el, clsName))
      curClass = curClass.replace(` ${clsName} `, ' ')
  }
  if (!el.classList)
    el.className = trim(curClass)
}

export function getStyle(element: HTMLElement, styleName: string) {
  if (isServer)
    return
  if (!element || !styleName)
    return null
  styleName = camelize(styleName)
  if (styleName === 'float')
    styleName = 'cssFloat'

  try {
    const style = element.style[styleName as any]
    if (style)
      return style
    const computed = document.defaultView?.getComputedStyle(element, '')
    return computed ? computed[styleName as any] : ''
  }
  // eslint-disable-next-line unused-imports/no-unused-vars
  catch (_e) {
    return element.style[styleName as any]
  }
}
