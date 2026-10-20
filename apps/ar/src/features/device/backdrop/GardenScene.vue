<script setup lang="ts">
import type { Circle } from './scenery'
import ArField from './ArField.vue'
import DataShards from './DataShards.vue'
import Glints from './Glints.vue'
import LensFlare from './LensFlare.vue'
import { circles, crown, cumulus, drifts, driftStyle, leaves, lit, round, sequence } from './scenery'

/** Toward the sun, high on the right. */
const light: [number, number] = [0.55, -0.83]
const shaded = (items: Circle[]) => ({ base: circles(items), lit: circles(lit(items, light)), top: circles(lit(items, light, 0.46)) })

const ridges = [
  'M0 600C150 540 280 520 400 552S640 492 790 528S1060 462 1200 514S1460 490 1600 532',
  'M0 646C180 606 320 626 470 600S770 562 910 600S1210 588 1350 566S1520 596 1600 590',
]
const bank = shaded([...cumulus(7, -60, 610, 520, 5), ...cumulus(19, 1020, 604, 660, 5), ...cumulus(31, 560, 596, 380, 3)])

function cloud(seed: number, rows: number) {
  const items = cumulus(seed, 0, 200, 300, rows)
  const top = Math.floor(Math.min(...items.map(([, y, r]) => y - r)))
  // The view box ends at the cloud base, flattening its underside.
  return { viewBox: `-60 ${top} 420 ${200 - top}`, ...shaded(items) }
}
const clouds = [
  { ...cloud(43, 3), style: { left: '6%', top: '30%', width: '22vw', animationDuration: '110s' } },
  { ...cloud(61, 2), style: { left: '40%', top: '40%', width: '14vw', animationDuration: '90s' } },
]

const islandTrees = shaded([[40, 36, 13], [62, 30, 17], [150, 38, 15], [172, 45, 10]])
const islands = [
  { spire: true, style: { left: '58%', top: '9%', width: 'clamp(170px, 17vw, 300px)', animationDuration: '13s' } },
  { spire: false, style: { left: '14%', top: '17%', width: 'clamp(90px, 8vw, 150px)', animationDuration: '17s', animationDelay: '-6s' } },
  { spire: false, style: { left: '84%', top: '33%', width: 'clamp(56px, 4.5vw, 86px)', animationDuration: '11s', animationDelay: '-3s' } },
]

const arches = Array.from({ length: 5 }, (_, i) => 240 + i * 96)
const archPath = arches.map(x => `M${x} 704V632A48 48 0 0 1 ${x + 96} 632V704`).join('')
const glassGlints = arches.map(x => `M${x + 20} 698L${x + 62} 640`).join('')
const tree = shaded(crown(3, 880, 520, 112, 76, 34))
const potted = shaded([...crown(9, 1200, 562, 24, 20, 8), ...crown(13, 1404, 556, 28, 24, 9)])
const shrubs = shaded([[50, 694, 42], [118, 682, 54], [182, 698, 34], [752, 692, 30], [796, 700, 22], [1046, 696, 26], [1520, 684, 48], [1584, 692, 38]])
const railing = `M1104 572H1496${Array.from({ length: 17 }, (_, i) => `M${1108 + i * 23.5} 572V604`).join('')}`
const flowers = (() => {
  const random = sequence(71)
  return circles(Array.from({ length: 70 }, () => [round(random() * 1600), round(708 + random() ** 1.5 * 150), round(2 + random() * 2.4)] as Circle))
})()
const stars = (() => {
  const random = sequence(83)
  return circles(Array.from({ length: 170 }, () => [round(random() * 1600), round(random() ** 1.4 * 560), round(0.6 + random() ** 3 * 1.6)] as Circle))
})()

const foliageLeft = leaves([[0, 500, -78, 330, 48], [0, 500, -58, 380, 56], [0, 500, -36, 420, 60], [0, 500, -16, 360, 50], [20, 500, -96, 260, 40], [0, 440, -48, 300, 44], [0, 470, -8, 300, 40]])
const foliageRight = leaves([[400, 500, -102, 320, 46], [400, 500, -124, 380, 54], [400, 500, -146, 400, 58], [400, 500, -168, 330, 48], [400, 430, -136, 290, 42], [380, 500, -84, 240, 36]])
const petals = drifts(5, 16, [-8, 70], [9, 15], random => [-Math.round(220 + random() * 320), Math.round(320 + random() * 340)])
const fireflies = drifts(9, 18, [30, 88], [6, 26], random => [Math.round((random() - 0.5) * 90), -Math.round(40 + random() * 70)])
const glints = [[17, 73, 22, 0], [29, 71, 16, -2.5], [63.5, 11, 26, -4.6], [70, 30, 18, -1.2], [44, 66, 14, -5.8]]
</script>

<template>
  <div class="backdrop-scene is-garden">
    <svg class="stars" viewBox="0 0 1600 900" preserveAspectRatio="xMidYMid slice"><path :d="stars" /></svg>
    <i class="milky-way" />
    <i class="shooting-star" />
    <div class="layer layer-far">
      <div class="orbit">
        <svg class="art art-far scene-art" viewBox="0 0 1600 900" preserveAspectRatio="xMidYMax slice">
          <path class="fill-cloud-shade" :d="bank.base" /><path class="fill-cloud" :d="bank.lit" />
          <path class="fill-mtn-far" :d="`${ridges[0]}V900H0Z`" /><path class="stroke-mtn-far" :d="ridges[0]" />
          <path class="fill-mtn" :d="`${ridges[1]}V900H0Z`" /><path class="stroke-mtn" :d="ridges[1]" />
        </svg>
        <div v-for="(island, index) in islands" :key="index" class="island" :style="island.style">
          <svg class="art" viewBox="0 -60 200 230">
            <path class="fill-rock-shade" d="M6 52Q100 44 194 52Q186 66 170 72Q152 100 124 120Q108 136 100 160Q90 132 72 116Q40 92 30 72Q12 64 6 52Z" />
            <path class="fill-rock" d="M100 50Q150 49 194 52Q186 66 170 72Q152 100 124 120Q110 134 100 160Q104 122 112 96Q116 70 100 50Z" />
            <template v-if="island.spire">
              <path class="fill-wall" d="M86 50V18H100V50ZM104 50V-6H128V50Z" /><path class="fill-wall-shade" d="M95 50V18H100V50ZM119 50V-6H128V50Z" />
              <path class="fill-roof" d="M83 18L93-4L103 18ZM100-6L116-52L132-6Z" /><path class="fill-roof-shade" d="M93-4L103 18H95ZM116-52L132-6H119Z" />
              <path class="fill-window" d="M110 6h6v10h-6zM110 26h6v10h-6zM89 28h4v8h-4z" />
            </template>
            <path class="fill-grass" d="M2 52Q100 34 198 52Q190 62 174 62Q100 56 24 62Q8 60 2 52Z" /><path class="fill-grass-light" d="M14 47Q100 34 186 47Q100 41 14 47Z" />
            <path class="fill-leaf-shade" :d="islandTrees.base" /><path class="fill-leaf" :d="islandTrees.lit" />
          </svg>
          <i class="waterfall" />
        </div>
      </div>
    </div>
    <div class="layer layer-clouds">
      <svg v-for="(item, index) in clouds" :key="index" class="cloud" :viewBox="item.viewBox" :style="item.style"><path class="fill-cloud-shade" :d="item.base" /><path class="fill-cloud" :d="item.lit" /><path class="fill-cloud-top" :d="item.top" /></svg>
    </div>
    <div class="layer layer-mid">
      <svg class="art art-mid scene-art" viewBox="0 0 1600 900" preserveAspectRatio="xMidYMax slice">
        <path class="fill-lawn" d="M0 706C300 694 520 688 800 694S1300 704 1600 694V900H0Z" />
        <path class="fill-lawn-light" d="M0 706C300 694 520 688 800 694S1300 704 1600 694V706C1300 716 1000 708 800 706S300 708 0 720Z" />
        <path class="fill-lawn-shade" d="M730 712a150 12 0 1 0 300 0a150 12 0 1 0-300 0ZM236 706h490v10h-490zM1104 704h394v8h-394z" />
        <path class="fill-flower" :d="flowers" />
        <path class="fill-glass" :d="archPath" />
        <path class="stroke-stone-shade" :d="archPath" transform="translate(4 3)" />
        <path class="stroke-stone" :d="`${archPath}M232 632H720`" />
        <path class="stroke-glint" :d="glassGlints" />
        <path class="fill-stone" d="M1104 604H1496V612H1104ZM1160 628h18v76h-18zM1420 628h18v76h-18z" />
        <path class="fill-stone-shade" d="M1104 612H1496V628H1104ZM1171 628h7v76h-7zM1431 628h7v76h-7z" />
        <path class="stroke-rail" :d="railing" />
        <path class="fill-bark" d="M868 704C872 640 864 600 876 560H896C904 600 896 650 900 704ZM1197 588h6v16h-6zM1401 584h6v20h-6z" />
        <path class="fill-leaf-shade" :d="`${tree.base}${potted.base}${shrubs.base}`" />
        <path class="fill-leaf" :d="`${tree.lit}${potted.lit}${shrubs.lit}`" />
        <path class="fill-leaf-light" :d="`${tree.top}${potted.top}`" />
      </svg>
      <ArField />
    </div>
    <div class="layer layer-glow">
      <div class="orbit">
        <i v-for="(drift, index) in petals" :key="`p${index}`" class="petal" :style="driftStyle(drift)" />
        <i v-for="(drift, index) in fireflies" :key="`f${index}`" class="firefly" :style="driftStyle(drift)" />
        <DataShards :seed="13" :count="14" :top="30" :bottom="86" />
        <Glints :points="glints" />
      </div>
    </div>
    <div class="layer layer-near">
      <div class="orbit">
        <svg class="art art-near near-left" viewBox="0 0 400 500" preserveAspectRatio="xMinYMax meet"><path class="fill-near" :d="foliageLeft" /></svg>
        <svg class="art art-near near-right" viewBox="0 0 400 500" preserveAspectRatio="xMaxYMax meet"><path class="fill-near" :d="foliageRight" /></svg>
      </div>
    </div>
    <LensFlare :x="74" :y="17" />
  </div>
</template>

<style scoped>
.is-garden {
  --sky: #1c58a6, #3784cf 26%, #7cbdea 50%, #c9e7f6 66%, #f4ead6 80%;
  --sun-core: #fffef4; --sun-glow: rgb(255 248 220 / 85%); --sun-halo: rgb(255 238 196 / 32%);
  --mtn-far: #92b8da; --mtn-far-rim: #cfe5f6; --mtn: #6f9bc6; --mtn-rim: #b4d2ec;
  --cloud: #fff; --cloud-top: #fff; --cloud-shade: #c3d2ee;
  --rock: #9098c0; --rock-shade: #666e98; --grass: #63b37c; --grass-light: #a3e3a2;
  --wall: #f4f7fc; --wall-shade: #c3cde2; --roof: #3a6fc0; --roof-shade: #2a5296; --window: #5c7fae; --water: 236 248 255;
  --lawn: #5fa36f; --lawn-light: #91d38c; --lawn-shade: #4a8a5c; --flower: #ffe1ec;
  --stone: #f2f5fa; --stone-shade: #aab7d0; --glass: rgb(190 230 255 / 36%); --glint-line: rgb(255 255 255 / 70%);
  --leaf: #4f9c66; --leaf-light: #84cf80; --leaf-shade: #2f6f4e; --bark: #6a5446; --near: #24563f;
  --ar: 110 225 255; --ar-grid: 22%; --ar-horizon: 76%;
  --petal: 255 210 226; --firefly: 214 255 170;
  --flare: 255 244 214; --ray: 255 250 235; --rays: .6; --streak: .45; --ghosts: .8; --ghost-a: 130 214 255; --ghost-b: 255 204 150; --ghost-c: 196 170 255;
}
.is-dark .is-garden {
  --sky: #050a20, #0c1540 28%, #1d2564 52%, #3b3880 68%, #5e4a8c 80%;
  --sun-core: #f8f6ff; --sun-glow: rgb(222 226 255 / 55%); --sun-halo: rgb(140 150 255 / 16%);
  --mtn-far: #222b62; --mtn-far-rim: #4f5eae; --mtn: #19214f; --mtn-rim: #3f4d9c;
  --cloud: #3a4689; --cloud-top: #56639f; --cloud-shade: #222a5c;
  --rock: #2e3568; --rock-shade: #1b2046; --grass: #1d4846; --grass-light: #3f8f86;
  --wall: #c7d0f0; --wall-shade: #7d88b8; --roof: #26397a; --roof-shade: #1a2858; --window: #ffd27a; --water: 150 190 255;
  --lawn: #12263a; --lawn-light: #1e4454; --lawn-shade: #0b1828; --flower: #6d7fc4;
  --stone: #74d8f0; --stone-shade: #24506e; --glass: rgb(110 225 255 / 20%); --glint-line: rgb(170 240 255 / 60%);
  --leaf: #183b3e; --leaf-light: #2c6662; --leaf-shade: #0c2228; --bark: #2a2532; --near: #060d16;
  --ar: 90 235 255; --ar-grid: 34%;
  --flare: 200 210 255; --ray: 210 220 255; --rays: 0; --streak: .35; --ghosts: .35;
}
.backdrop-scene.is-garden { background: radial-gradient(circle at 74% 17%, var(--sun-core) 0 2.4%, var(--sun-glow) 3.2%, var(--sun-halo) 9%, transparent 26%), linear-gradient(var(--sky)); }

.stars, .milky-way, .shooting-star, .firefly { display: none; }
.is-dark .stars, .is-dark .milky-way, .is-dark .shooting-star, .is-dark .firefly { display: block; }
.is-dark .petal { display: none; }
.stars { position: absolute; inset: 0; width: 100%; height: 100%; fill: rgb(240 240 255 / 85%); }
.milky-way { position: absolute; left: -10%; top: 4%; width: 120%; height: 26%; rotate: -14deg; filter: blur(24px); background: linear-gradient(90deg, transparent, rgb(170 160 255 / 22%) 30%, rgb(255 210 240 / 18%) 55%, rgb(150 190 255 / 20%) 75%, transparent); }
.shooting-star { position: absolute; left: 18%; top: 6%; width: 180px; height: 2px; opacity: 0; rotate: 18deg; background: linear-gradient(90deg, transparent, rgb(255 255 255 / 95%)); animation: shooting-star 13s ease-in infinite 2s; }

.fill-cloud { fill: var(--cloud); }
.fill-cloud-top { fill: var(--cloud-top); }
.fill-cloud-shade { fill: var(--cloud-shade); }
.fill-mtn-far { fill: var(--mtn-far); }
.fill-mtn { fill: var(--mtn); }
.stroke-mtn-far { fill: none; stroke: var(--mtn-far-rim); stroke-width: 3; }
.stroke-mtn { fill: none; stroke: var(--mtn-rim); stroke-width: 3; }
.fill-rock { fill: var(--rock); }
.fill-rock-shade { fill: var(--rock-shade); }
.fill-grass { fill: var(--grass); }
.fill-grass-light { fill: var(--grass-light); }
.fill-wall { fill: var(--wall); }
.fill-wall-shade { fill: var(--wall-shade); }
.fill-roof { fill: var(--roof); }
.fill-roof-shade { fill: var(--roof-shade); }
.fill-window { fill: var(--window); }
.is-dark .fill-window { filter: drop-shadow(0 0 3px var(--window)); }
.fill-lawn { fill: var(--lawn); }
.fill-lawn-light { fill: var(--lawn-light); }
.fill-lawn-shade { fill: var(--lawn-shade); }
.fill-flower { fill: var(--flower); }
.fill-glass { fill: var(--glass); }
.stroke-stone { fill: none; stroke: var(--stone); stroke-width: 7; }
.stroke-stone-shade { fill: none; stroke: var(--stone-shade); stroke-width: 7; }
.stroke-glint { fill: none; stroke: var(--glint-line); stroke-width: 5; stroke-linecap: round; }
.stroke-rail { fill: none; stroke: var(--stone); stroke-width: 4; }
.fill-stone { fill: var(--stone); }
.fill-stone-shade { fill: var(--stone-shade); }
.fill-bark { fill: var(--bark); }
.fill-leaf { fill: var(--leaf); }
.fill-leaf-light { fill: var(--leaf-light); }
.fill-leaf-shade { fill: var(--leaf-shade); }
.fill-near { fill: var(--near); }

.island { position: absolute; aspect-ratio: 200 / 230; animation: backdrop-bob ease-in-out infinite alternate; }
.island > .art { position: absolute; inset: 0; width: 100%; height: 100%; overflow: visible; }
.waterfall { position: absolute; left: 82%; top: 55%; width: 4%; height: 72%; border-radius: 0 0 50% 50%; background: linear-gradient(rgb(var(--water) / 85%), rgb(var(--water) / 30%) 55%, transparent); filter: blur(.6px); }
.cloud { position: absolute; height: auto; overflow: hidden; animation: backdrop-drift linear infinite alternate; }
.petal { position: absolute; border-radius: 80% 0; opacity: .8; background: linear-gradient(135deg, rgb(255 255 255 / 95%), rgb(var(--petal))); animation: petal linear infinite; will-change: transform, opacity; }
.firefly { position: absolute; border-radius: 50%; translate: -50% -50%; opacity: .7; background: radial-gradient(circle, rgb(var(--firefly) / 90%) 0 14%, rgb(var(--firefly) / 26%) 42%, transparent 70%); animation: backdrop-rise ease-in-out infinite; will-change: transform, opacity; }
.backdrop-scene .near-left, .backdrop-scene .near-right { inset: auto; bottom: 0; width: clamp(220px, 30vw, 520px); height: auto; aspect-ratio: 4 / 5; }
.backdrop-scene .near-left { left: 0; }
.backdrop-scene .near-right { right: 0; width: clamp(180px, 24vw, 420px); }

@keyframes petal {
  0% { opacity: 0; transform: translate(0, 0) rotate3d(1, .4, .2, 0deg); }
  10% { opacity: .9; }
  85% { opacity: .8; }
  100% { opacity: 0; transform: translate(var(--dx), var(--dy)) rotate3d(1, .4, .2, 900deg); }
}
@keyframes shooting-star { 0% { opacity: 0; transform: translateX(0); } 2% { opacity: 1; } 7%, 100% { opacity: 0; transform: translateX(40vw); } }
</style>
