import path from 'path'

export const alias = {
  '~/': `${path.resolve(__dirname, '../../client/src')}/`,
  '@augma/components/': `${path.resolve(__dirname, '../../components')}/`,
  '@augma/utils/': `${path.resolve(__dirname, '../../utils/src')}/`,
  '@augma/hooks': `${path.resolve(__dirname, '../../hooks/src')}/`,
  '@augma/shared': `${path.resolve(__dirname, '../../shared/src')}/`,
  'augma': `${path.resolve(__dirname, '../../augma/src')}/`,
}
