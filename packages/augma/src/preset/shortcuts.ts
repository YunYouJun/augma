import type { UserShortcuts } from 'unocss'

const shortcuts: UserShortcuts = [
  {
    'agm-body': 'bg-white text-gray-700',
  },
  {
    'agm-button':
      'bg-white text-gray-700 px-4 py-2 inline-flex justify-center items-center shadow cursor-pointer border-none transition hover:shadow-md',
  },
  [/^agm-color-(.*)$/, ([, c]) => `bg-${c}-500 text-${c}-100 shadow-${c}-500`],
]

export { shortcuts }
