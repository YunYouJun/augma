import fs from "fs";
import path from "path";
import fg from "fast-glob";
import matter from "gray-matter";

import { PackageIndexes, Component, Hook } from "../meta/types";

import { generateTag } from "./vetur";
import { DIR_SRC, hasDemo } from "./utils";

export async function listComponents(dir: string, ignore: string[] = []) {
  const files = await fg("*", {
    onlyDirectories: true,
    cwd: dir,
    ignore: ["_*", "dist", "node_modules", ...ignore],
  });
  files.sort();
  return files;
}

export async function listHooks(dir: string, ignore: string[] = []) {
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
export async function readIndexesAndHints() {
  const indexes: PackageIndexes = {
    components: {
      categories: [],
      children: [],
    },
    hooks: {
      categories: [],
      children: [],
    },
  };

  const dir = path.join(DIR_SRC, "components");
  const components = await listComponents(dir);

  const hooksDir = path.join(DIR_SRC, "hooks");
  const hooks = await listHooks(hooksDir);

  // for vetur tags
  const tags = {};

  for (const componentName of components) {
    const mdPath = path.join(dir, componentName, "index.md");

    if (!fs.existsSync(mdPath)) {
      continue;
    }

    const component: Component = {
      name: componentName,
      title: "",
      category: "",
    };

    const mdRaw = fs.readFileSync(mdPath);
    const { data: frontmatter } = matter(mdRaw);
    const { category, title } = frontmatter;

    component.category = category;
    component.title = title;

    indexes.components.children.push(component);

    const tagName = `agm-${componentName}`;
    tags[tagName] = generateTag(frontmatter);
  }

  for (const hookName of hooks) {
    const mdPath = path.join(hooksDir, hookName, "index.md");

    if (!fs.existsSync(mdPath) || !hasDemo("hooks", hookName)) {
      continue;
    }

    const hook: Hook = {
      name: hookName,
      title: "",
      category: "",
    };

    const mdRaw = fs.readFileSync(mdPath);
    const { data: frontmatter } = matter(mdRaw);
    Object.assign(hook, frontmatter);
    indexes.hooks.children.push(hook);
  }

  indexes.components.categories = getCategories("components");
  indexes.hooks.categories = getCategories("hooks");

  return {
    indexes,
    tags,
  };
}

export function getCategories(type: "components" | "hooks") {
  if (type === "components") {
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
        name: "form",
        title: "表单",
      },
      {
        name: "misc",
        title: "杂项",
      },
      {
        name: "utilities",
        title: "工具",
      },
    ];
  } else if (type === "hooks") {
    return [
      {
        name: "sensors",
        title: "传感器",
      },
      {
        name: "helper",
        title: "辅助",
      },
    ];
  }
}
