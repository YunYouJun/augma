import mdContainer from 'markdown-it-container'
import { extractCodeFromVueSFC } from './markdown-it/extractCode'

const componentName = 'demo-block'

export function markdownTransform(md: any) {
  md.use(extractCodeFromVueSFC)
  md.use(mdContainer, 'demo', {
    render: (tokens, idx) => {
      const m = tokens[idx].info.trim().match(/^demo\s*(.*)$/)
      if (tokens[idx].nesting === 1) {
        // opening tag
        const description = m && m.length > 1 ? m[1] : ''
        // const content =
        //   tokens[idx + 1].type === "fence" ? tokens[idx + 1].content : "";
        const descriptionSlot = description
          ? `<template v-slot:description>${description}</template>`
          : ''
        return `<${componentName}>
            <template v-slot:demo><Demo/></template>
            ${descriptionSlot}
            <template v-slot:code>
          `
      }
      else {
        // closing tag
        return `</template>
        </${componentName}>`
      }
    },
  })
}
