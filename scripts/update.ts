import fs from 'node:fs'
import path from 'node:path'
import { readIndexesAndHints } from './indexes'

const metadataFolder = path.resolve(__dirname, '../packages/metadata')

/**
 * 格式化 JSON
 * @param json
 */
function formatJSON(json: object) {
  return JSON.stringify(json, null, 2)
}

async function run() {
  const { indexes } = await readIndexesAndHints()
  fs.writeFileSync(path.resolve(metadataFolder, 'indexes.json'), formatJSON(indexes))
}

run()
