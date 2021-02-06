const mdContainer = require("markdown-it-container");
const componentName = "demo-block";

const mdExtractCode = require("./plugins/extractCode");

module.exports = (md) => {
  md.use(mdExtractCode);
  md.use(mdContainer, "demo", {
    render: (tokens, idx) => {
      const m = tokens[idx].info.trim().match(/^demo\s*(.*)$/);

      if (tokens[idx].nesting === 1) {
        // opening tag
        const description = m && m.length > 1 ? m[1] : "";
        const content =
          tokens[idx + 1].type === "fence" ? tokens[idx + 1].content : "";

        return `<${componentName}>
            <template v-slot:demo><demo /></template>
            ${
              description
                ? `<template v-slot:description>${
                    md.render(description).html
                  }</template>`
                : ""
            }
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
