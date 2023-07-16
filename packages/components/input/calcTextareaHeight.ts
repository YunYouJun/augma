import { isServer } from '@augma/utils'

let hiddenTextarea

const HIDDEN_STYLE = `
  height:0 !important;
  visibility:hidden !important;
  overflow:hidden !important;
  position:absolute !important;
  z-index:-1000 !important;
  top:0 !important;
  right:0 !important;
`

const CONTEXT_STYLE = [
  'letter-spacing',
  'line-height',
  'padding-top',
  'padding-bottom',
  'font-family',
  'font-weight',
  'font-size',
  'text-rendering',
  'text-transform',
  'width',
  'text-indent',
  'padding-left',
  'padding-right',
  'border-width',
  'box-sizing',
]

interface NodeStyle {
  contextStyle: string
  boxSizing: string
  paddingSize: number
  borderSize: number
}

interface TextAreaHeight {
  height: string
  minHeight?: string
}

function calculateNodeStyling(targetElement): NodeStyle {
  if (isServer)
    return
  const style = getComputedStyle(targetElement)

  const boxSizing = style.getPropertyValue('box-sizing')

  const paddingSize
    = Number.parseFloat(style.getPropertyValue('padding-bottom'))
    + Number.parseFloat(style.getPropertyValue('padding-top'))

  const borderSize
    = Number.parseFloat(style.getPropertyValue('border-bottom-width'))
    + Number.parseFloat(style.getPropertyValue('border-top-width'))

  const contextStyle = CONTEXT_STYLE.map(
    name => `${name}:${style.getPropertyValue(name)}`,
  ).join(';')

  return { contextStyle, paddingSize, borderSize, boxSizing }
}

export default function calcTextareaHeight(
  targetElement,
  minRows = 1,
  maxRows = null,
): TextAreaHeight {
  if (!hiddenTextarea) {
    hiddenTextarea = document.createElement('textarea')
    document.body.appendChild(hiddenTextarea)
  }

  const {
    paddingSize,
    borderSize,
    boxSizing,
    contextStyle,
  } = calculateNodeStyling(targetElement)

  hiddenTextarea.setAttribute('style', `${contextStyle};${HIDDEN_STYLE}`)
  hiddenTextarea.value = targetElement.value || targetElement.placeholder || ''

  let height = hiddenTextarea.scrollHeight
  const result = {} as TextAreaHeight

  if (boxSizing === 'border-box')
    height = height + borderSize
  else if (boxSizing === 'content-box')
    height = height - paddingSize

  hiddenTextarea.value = ''
  const singleRowHeight = hiddenTextarea.scrollHeight - paddingSize

  if (minRows !== null) {
    let minHeight = singleRowHeight * minRows
    if (boxSizing === 'border-box')
      minHeight = minHeight + paddingSize + borderSize

    height = Math.max(minHeight, height)
    result.minHeight = `${minHeight}px`
  }
  if (maxRows !== null) {
    let maxHeight = singleRowHeight * maxRows
    if (boxSizing === 'border-box')
      maxHeight = maxHeight + paddingSize + borderSize

    height = Math.min(maxHeight, height)
  }
  result.height = `${height}px`
  hiddenTextarea.parentNode?.removeChild(hiddenTextarea)
  hiddenTextarea = null

  return result
}
