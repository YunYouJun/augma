import path from 'node:path'

export const alias = {
  '~/': `${path.resolve(__dirname, '../../client/src')}/`,
  'augma': `${path.resolve(__dirname, '../../augma/src/index.ts')}`,
  '@augma/components/': `${path.resolve(__dirname, '../../components')}/`,
  '@augma/components': `${path.resolve(__dirname, '../../components/index.ts')}`,
  '@augma/utils': `${path.resolve(__dirname, '../../utils/src/index.ts')}`,
  '@augma/hooks': `${path.resolve(__dirname, '../../hooks/src')}/`,
}
