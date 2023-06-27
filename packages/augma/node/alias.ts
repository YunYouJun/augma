import path from 'node:path'

export const alias = [
  { find: '~/', replacement: `${path.resolve(__dirname, '../../client/src')}/` },
  { find: 'augma', replacement: `${path.resolve(__dirname, '../../augma/src/index.ts')}` },
  { find: '@augma/components/', replacement: `${path.resolve(__dirname, '../../components')}/` },
  { find: '@augma/components', replacement: `${path.resolve(__dirname, '../../components/index.ts')}` },
  { find: '@augma/utils', replacement: `${path.resolve(__dirname, '../../utils/src/index.ts')}` },
  { find: '@augma/hooks', replacement: `${path.resolve(__dirname, '../../hooks/src')}/` },
  { find: /^@augma\/(.*)/, replacement: `${path.resolve(__dirname, '../../$1/src/index.ts')}` },
]
