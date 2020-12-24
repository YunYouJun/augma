module.exports = {
  title: "Augma UI",
  description: "AR UI Framework",

  themeConfig: {
    repo: "SAO-UI/augma",
    docsBranch: "main",
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
          text: "Color 色彩",
          link: "/components/color",
        },
        {
          text: "Button 按钮",
          link: "/components/button",
        },
        {
          text: "Card 卡片",
          link: "/components/card",
        },
        {
          text: "Clock 时钟",
          link: "/components/clock",
        },
        {
          text: "Dialog 会话",
          link: "/components/dialog",
        },
        {
          text: "Html 基础元素",
          link: "/components/html",
        },
        {
          text: "Icon 图标",
          link: "/components/icon",
        },
        {
          text: "Indicator 指示器",
          link: "/components/indicator",
        },
        {
          text: "Loading 加载",
          link: "/components/loading",
        },
        {
          text: "Menu 菜单",
          link: "/components/menu",
        },
        {
          text: "Notification 通知",
          link: "/components/notification",
        },
        {
          text: "Utils 工具",
          link: "/components/utils",
        },
      ],
    },
  ];
}
