import fs from "fs";
import path from "path";

// const DOCS_URL = "https://docs.augma.elpsy.cn";

const DIR_SRC = path.resolve(__dirname, "../packages");

export function hasDemo(pkg: string, name: string) {
  return fs.existsSync(path.join(DIR_SRC, pkg, name, "demo.vue"));
}
