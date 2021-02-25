const mdContainer = require("markdown-it-container");
const componentName = "demo-block";

const mdExtractCode = require("./extractCode");

module.exports = (md) => {
  md.use(mdExtractCode);
  md.use(mdContainer, "demo", {
    render: (tokens, idx) => {
      const m = tokens[idx].info.trim().match(/^demo\s*(.*)$/);
      if (tokens[idx].nesting === 1) {
        // opening tag
        const description = m && m.length > 1 ? m[1] : "";
        // const content =
        //   tokens[idx + 1].type === "fence" ? tokens[idx + 1].content : "";
        const descriptionSlot = description
          ? `<template v-slot:description>${description}</template>`
          : "";
        return `<${componentName}>
            <template v-slot:demo><Demo/></template>
            ${descriptionSlot}
            <template v-slot:code>
          `;
      } else {
        // closing tag
        return `</template>
        </${componentName}>`;
      }
    },
  });
};
