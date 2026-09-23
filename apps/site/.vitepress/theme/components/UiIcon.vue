<script setup lang="ts">
withDefaults(
  defineProps<{
    name:
      | 'sun'
      | 'volume'
      | 'scan'
      | 'link'
      | 'settings'
      | 'arrow'
      | 'copy'
      | 'check'
  }>(),
  {},
)
const paths = {
  sun: 'M12 3v2m0 14v2M3 12h2m14 0h2M5.6 5.6 7 7m10 10 1.4 1.4M5.6 18.4 7 17m10-10 1.4-1.4M16 12a4 4 0 1 1-8 0 4 4 0 0 1 8 0',
  volume: 'M11 5 6 9H3v6h3l5 4V5m4 3a6 6 0 0 1 0 8m3-11a10 10 0 0 1 0 14',
  scan: 'M8 3H3v5m13-5h5v5M3 16v5h5m13-5v5h-5M8 12h8m-4-4v8',
  link: 'm10 13 4-4m-6 6-1 1a4 4 0 0 1-6-6l4-4a4 4 0 0 1 6 0m2 3 1-1a4 4 0 0 1 6 6l-4 4a4 4 0 0 1-6 0',
  settings: 'M4 7h16M4 17h16M8 4v6m8 4v6',
  arrow: 'M4 12h16m-6-6 6 6-6 6',
  copy: 'M8 8h12v13H8zM16 8V3H3v13h5',
  check: 'm5 12 4 4L19 6',
}
</script>

<template>
  <svg
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    stroke-width="1.5"
    stroke-linecap="round"
    stroke-linejoin="round"
    aria-hidden="true"
  >
    <path :d="paths[name]" />
  </svg>
</template>
