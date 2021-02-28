const indexes = require("../../meta/indexes.json");

const mdConfig = require("./plugins/markdown");

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
      { text: "指南", link: "/guide/link-start.html" },
      { text: "组件", link: "/components/" },
      { text: "钩子函数", link: "/hooks/" },
    ],

    sidebar: {
      "/guide/": getGuideSidebar(),
      "/components/": getComponentsSidebar(),
      "/hooks": getHooksSidebar(),
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

  for (const category of indexes.components.categories) {
    const components = indexes.components.children.filter(
      (i) => i.category === category.name
    );

    links.push({
      text: getText(category),
      children: components.map((i) => ({
        text: getText(i),
        link: `/components/${i.name}/`,
      })),
    });
  }

  return links;
}

function getHooksSidebar() {
  const links = [];

  for (const category of indexes.hooks.categories) {
    const hooks = indexes.hooks.children.filter(
      (i) => i.category === category.name
    );

    if (!hooks.length) continue;

    links.push({
      text: getText(category),
      children: hooks.map((hook) => ({
        text: `${hook.name} ${hook.title}`,
        link: `/hooks/${hook.name}/`,
      })),
    });
  }

  return links;
}

/**
 * 首字母大写
 */
function firstLetterUpper(str) {
  return str.charAt(0).toUpperCase() + str.slice(1);
}

/**
 * 拼接标题
 * @param {*} object
 */
function getText(object) {
  return firstLetterUpper(object.name) + " " + object.title;
}

module.exports = config;
