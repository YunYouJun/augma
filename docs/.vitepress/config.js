module.exports = {
  title: "Augma UI",
  description: "AR UI Framework",

  themeConfig: {
    repo: "SAO-UI/augma",
    docsDir: "docs",

    editLinks: true,
    editLinkText: "帮助咱们改善文档！",
    lastUpdated: "上次更新",

    nav: [
      { text: "指南", link: "/" },
      { text: "组件", link: "/components/" },
    ],

    sidebar: {
      "/": getGuideSidebar(),
      "/components/": getComponentsSidebar(),
    },
  },
};

/**
 * 获取导航侧边栏
 */
function getGuideSidebar() {
  return [
    {
      text: "Introduction",
      children: [{ text: "What is Augma?", link: "/" }],
    },
  ];
}

/**
 * 获取组件侧边栏
 */
function getComponentsSidebar() {
  return [
    {
      text: "组件",
      children: [
        {
          text: "Buttons 按钮",
          link: "/components/buttons",
        },
      ],
    },
  ];
}
