import fs from "fs";
import { resolve, join } from "path";
import fg from "fast-glob";
import matter from "gray-matter";

import { PackageIndexes, Component } from "../meta/types";

// const DOCS_URL = "https://docs.augma.elpsy.cn";
const DIR_SRC = resolve(__dirname, "../packages");

/**
 * 首字母大写
 * @param str
 */
export function firstLetterUpper(str: string) {
  return str.charAt(0).toUpperCase() + str.slice(1);
}

export function hasDemo(pkg: string, name: string) {
  return fs.existsSync(join(DIR_SRC, pkg, name, "demo.vue"));
}

export async function listComponents(dir: string, ignore: string[] = []) {
  const files = await fg("*", {
    onlyDirectories: true,
    cwd: dir,
    ignore: ["_*", "dist", "node_modules", ...ignore],
  });
  files.sort();
  return files;
}

/**
 * 读取并生成索引
 */
export async function readIndexes() {
  const indexes: PackageIndexes = {
    categories: [],
    components: [],
  };

  const dir = join(DIR_SRC, "components");
  const components = await listComponents(dir);

  for (const componentName of components) {
    const mdPath = join(dir, componentName, "index.md");

    const component: Component = {
      name: componentName,
      title: "",
      category: "",
    };

    if (!fs.existsSync(mdPath)) {
      continue;
    }

    const mdRaw = fs.readFileSync(mdPath);
    const { content: md, data: frontmatter } = matter(mdRaw);
    const { category, title } = frontmatter;

    component.category = category;
    component.title = title;

    indexes.components.push(component);
  }

  indexes.categories = getCategories();

  return indexes;
}

export function getCategories() {
  return [
    {
      name: "animation",
      title: "动画",
    },
    {
      name: "common",
      title: "通用",
    },
    {
      name: "misc",
      title: "杂项",
    },
    {
      name: "sensors",
      title: "传感器",
    },
    {
      name: "utilities",
      title: "工具",
    },
  ];
}
