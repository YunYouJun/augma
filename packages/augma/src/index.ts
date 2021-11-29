import pkg from '../package.json'

// export * from '@augma/components'
export * from '../../components'
// export * from './styles'

export const version = pkg.version

export * from './preset'
export * from './resolver'

export default version
