import fs from "fs";
import { readIndexes } from "./utils";

async function run() {
  const indexes = await readIndexes();
  fs.writeFileSync("meta/indexes.json", JSON.stringify(indexes, null, 2));
}

run();
