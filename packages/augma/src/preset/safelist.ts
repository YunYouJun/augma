import { agmColors } from './common'

const safelist = ['shadow-lg']

agmColors.forEach((color) => {
  safelist.push(`bg-${color}-500`)
  safelist.push(`text-${color}-500`)
  safelist.push(`text-${color}-100`)
  safelist.push(`shadow-${color}-500`)
})

export { safelist }
