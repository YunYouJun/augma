import fs from "fs";
import { readIndexesAndHints } from "./indexes";

/**
 * 格式化 JSON
 * @param json
 */
function formatJSON(json: object) {
  return JSON.stringify(json, null, 2);
}

async function run() {
  const { indexes, tags } = await readIndexesAndHints();
  fs.writeFileSync("meta/indexes.json", formatJSON(indexes));
  fs.writeFileSync("vetur/tags.json", formatJSON(tags));
}

run();
