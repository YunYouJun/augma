const indexes = require("../../meta/indexes.json");

const mdConfig = require("./markdown");

/**
 * @type {import('vitepress').UserConfig}
 */
const config = {
  title: "Augma UI",
  description: "AR UI Framework",

  markdown: {
    config: mdConfig,
  },

  themeConfig: {
    repo: "SAO-UI/augma",
    docsBranch: "main",
    docsDir: "docs",

    editLinks: true,
    editLinkText: "帮助咱们改善文档！",
    lastUpdated: "上次更新",

    nav: [
      { text: "指南", link: "/guide/" },
      { text: "组件", link: "/components/" },
    ],

    sidebar: {
      "/guide/": getGuideSidebar(),
      "/components/": getComponentsSidebar(),
    },
  },

  head: [
    ["link", { rel: "icon", href: "/logo.png", type: "image/png" }],
    ["meta", { name: "author", content: "YunYouJun" }],
  ],
};

/**
 * 获取导航侧边栏
 */
function getGuideSidebar() {
  return [
    {
      text: "介绍",
      children: [
        { text: "什么是 Augma?", link: "/guide/" },
        { text: "Link Start", link: "/guide/link-start" },
        { text: "更多细节", link: "/guide/details" },
      ],
    },
  ];
}

/**
 * 获取组件侧边栏
 */
function getComponentsSidebar() {
  const links = [];
  const { categories } = indexes;

  /**
   * 首字母大写
   */
  function firstLetterUpper(str) {
    return str.charAt(0).toUpperCase() + str.slice(1);
  }

  for (const category of categories) {
    const components = indexes.components.filter(
      (i) => i.category === category.name
    );

    links.push({
      text: firstLetterUpper(category.name) + " " + category.title,
      children: components.map((i) => ({
        text: firstLetterUpper(i.name) + " " + i.title,
        link: `/components/${i.name}/`,
      })),
    });
  }

  return links;
}

module.exports = config;
