import fs from "fs";
import path from "path";

import { Logger } from "@yunyoujun/logger";
export const logger = new Logger();

// const DOCS_URL = "https://docs.augma.elpsy.cn";
export const DIR_SRC = path.resolve(__dirname, "../packages");

/**
 * 首字母大写
 * @param str
 */
export function firstLetterUpper(str: string) {
  return str.charAt(0).toUpperCase() + str.slice(1);
}

export function hasDemo(pkg: string, name: string) {
  return fs.existsSync(path.join(DIR_SRC, pkg, name, "demo.vue"));
}

export const targets = fs.readdirSync("packages").filter((f) => {
  if (
    f.endsWith(".ts") ||
    f.endsWith(".md") ||
    f.startsWith(".") ||
    !fs.statSync(`packages/${f}`).isDirectory() ||
    !fs.existsSync(path.resolve(`packages/${f}`, "package.json"))
  ) {
    return false;
  }
  const pkg = require(`../packages/${f}/package.json`);
  if (pkg.private) {
    return false;
  }
  return true;
});
