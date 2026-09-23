import { writeFile } from 'node:fs/promises'

await writeFile('dist/style.css', '@import \"@augma/core/style.css\";\n')
