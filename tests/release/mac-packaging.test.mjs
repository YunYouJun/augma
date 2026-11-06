/* eslint test/no-import-node-test: off -- Maintainer tooling uses Node's standalone test runner. */
import assert from 'node:assert/strict'
import { spawnSync } from 'node:child_process'
import { createHash } from 'node:crypto'
import { copyFile, cp, mkdir, mkdtemp, readdir, readFile, rm, symlink, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { test } from 'node:test'

// Exercise the real packaging entrypoint without a Swift toolchain, signing
// keys or macOS. Stub compilers record their architecture in each binary.
const tool = `#!/usr/bin/env bash
set -euo pipefail
command_name="$(basename "$0")"
printf '%s %s\\n' "$command_name" "$*" >> "$TEST_TOOL_LOG"
case "$command_name" in
  node)
    if [[ "$1" == "-p" ]]; then echo 1.2.3
    elif [[ "$*" == *"client-id"* ]]; then echo 11111111-1111-1111-1111-111111111111; fi
    ;;
  swift)
    if [[ "$1" != "build" ]]; then mkdir -p "$3"; exit 0; fi
    arch=""; configuration=""; show=0
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --arch) arch="$2"; shift 2 ;;
        -c) configuration="$2"; shift 2 ;;
        --show-bin-path) show=1; shift ;;
        *) shift ;;
      esac
    done
    [[ "$arch" != "\${TEST_FAIL_ARCH:-}" ]] || exit 9
    output="$TEST_BUILD_DIR/$arch"
    mkdir -p "$output"
    printf '%s\\n%s\\n' "$arch" "$configuration" > "$output/AugmaDesktopDemo"
    if [[ "$show" == 1 ]]; then echo "$output"; fi
    ;;
  xcrun)
    case "$*" in
      *--show-sdk-path*) echo /fixture/SDK ;;
      "actool --version") echo 'actool 0' ;;
      clang*)
        arch=""; output=""
        while [[ $# -gt 0 ]]; do
          case "$1" in
            -arch) arch="$2"; shift 2 ;;
            -o) output="$2"; shift 2 ;;
            *) shift ;;
          esac
        done
        printf '%s\\n' "\${TEST_HELPER_ARCH:-$arch}" > "$output"
        ;;
      *) exit 3 ;;
    esac
    ;;
  iconutil)
    while [[ "$1" != "-o" ]]; do shift; done
    touch "$2"
    ;;
  codesign) ;;
  lipo) head -n 1 "$2" ;;
  ditto)
    previous=""; last=""
    for argument in "$@"; do previous="$last"; last="$argument"; done
    cp "$previous/Contents/MacOS/AugmaDesktopDemo" "$last"
    ;;
  *) exit 3 ;;
esac
`

async function fixture(t) {
  const directory = await mkdtemp(join(tmpdir(), 'augma-packaging-test-'))
  t.after(() => rm(directory, { recursive: true, force: true }))
  for (const path of ['script', 'bin', 'tmp', 'apps/mac/Localization', 'apps/mac/Support/NowPlaying', 'apps/mac/dist/Augma.app'])
    await mkdir(join(directory, path), { recursive: true })
  const script = join(directory, 'script/build_and_run.sh')
  await copyFile(new URL('../../script/build_and_run.sh', import.meta.url), script)
  await cp(new URL('../../plugins/breathing-orbit/BreathingOrbit.augmaplugin', import.meta.url), join(directory, 'plugins/breathing-orbit/BreathingOrbit.augmaplugin'), { recursive: true })
  await writeFile(join(directory, 'script/sign_mac_dev.sh'), '#!/bin/bash\nprintf "local-sign %s\\n" "$1" >> "$TEST_TOOL_LOG"\n')
  await writeFile(join(directory, 'apps/mac/Support/NowPlaying/read-now-playing.pl'), '# fixture media reader\n')
  await writeFile(join(directory, 'bin/tool'), tool, { mode: 0o700 })
  for (const name of ['node', 'swift', 'xcrun', 'iconutil', 'codesign', 'lipo', 'ditto'])
    await symlink('tool', join(directory, 'bin', name))
  const dist = join(directory, 'apps/mac/dist')
  const local = join(dist, 'Augma.app/keep-local-app')
  await writeFile(local, 'existing development app')
  const log = join(directory, 'tools.log')
  const run = (args, extra = {}) => spawnSync('bash', [script, ...args], {
    encoding: 'utf8',
    timeout: 15000,
    env: {
      ...process.env,
      PATH: `${join(directory, 'bin')}:${process.env.PATH}`,
      TMPDIR: join(directory, 'tmp'),
      DEVELOPER_DIR: '/fixture/Developer',
      AUGMA_BUILD_ARCH: '',
      AUGMA_BUILD_CONFIGURATION: '',
      AUGMA_APP_BUNDLE: '',
      TEST_TOOL_LOG: log,
      TEST_BUILD_DIR: join(directory, 'build'),
      ...extra,
    },
  })
  return { directory, dist, local, log, run }
}

test('release packaging produces two checksummed Release archives and preserves the local app', async (t) => {
  const f = await fixture(t)
  await writeFile(join(f.dist, 'Augma-macOS.zip'), 'old universal archive')
  await writeFile(join(f.dist, 'Augma-macOS.zip.sha256'), 'old checksum')
  const result = f.run(['--package'])
  assert.equal(result.status, 0, result.stderr)
  assert.deepEqual((await readdir(f.dist)).sort(), [
    'Augma-macOS-arm64.zip',
    'Augma-macOS-arm64.zip.sha256',
    'Augma-macOS-x86_64.zip',
    'Augma-macOS-x86_64.zip.sha256',
    'Augma.app',
  ])
  for (const arch of ['arm64', 'x86_64']) {
    const name = `Augma-macOS-${arch}.zip`
    const data = await readFile(join(f.dist, name))
    assert.equal(data.toString(), `${arch}\nrelease\n`)
    assert.equal((await readFile(join(f.dist, `${name}.sha256`), 'utf8')).trim(), `${createHash('sha256').update(data).digest('hex')}  ${name}`)
  }
  assert.equal(await readFile(f.local, 'utf8'), 'existing development app')
  assert.deepEqual(await readdir(join(f.directory, 'tmp')), [])
  assert.doesNotMatch(await readFile(f.log, 'utf8'), /local-sign/)
})

test('one architecture can be packaged explicitly, overriding the local architecture and debug mode', async (t) => {
  const f = await fixture(t)
  const result = f.run(['--package', 'x86_64'], { AUGMA_BUILD_ARCH: 'arm64', AUGMA_BUILD_CONFIGURATION: 'debug' })
  assert.equal(result.status, 0, result.stderr)
  assert.equal(await readFile(join(f.dist, 'Augma-macOS-x86_64.zip'), 'utf8'), 'x86_64\nrelease\n')
  assert.equal((await readdir(f.dist)).includes('Augma-macOS-arm64.zip'), false)
  assert.equal(await readFile(f.local, 'utf8'), 'existing development app')
})

test('local builds default to arm64 for both the executable and the media bridge', async (t) => {
  const f = await fixture(t)
  const result = f.run(['--build'])
  assert.equal(result.status, 0, result.stderr)
  assert.equal(await readFile(join(f.dist, 'Augma.app/Contents/MacOS/AugmaDesktopDemo'), 'utf8'), 'arm64\ndebug\n')
  assert.equal(await readFile(join(f.dist, 'Augma.app/Contents/Resources/NowPlaying/ReadNowPlaying.dylib'), 'utf8'), 'arm64\n')
  const pluginRoot = join(f.dist, 'Augma.app/Contents/Resources/LinkCatalog/BreathingOrbit.augmaplugin')
  assert.equal(JSON.parse(await readFile(join(pluginRoot, 'augma-plugin.json'), 'utf8')).id, 'org.augma.examples.breathing-orbit')
  assert.match(await readFile(join(pluginRoot, 'main.js'), 'utf8'), /requestAnimationFrame/)
  assert.match(await readFile(f.log, 'utf8'), /local-sign/)
})

test('invalid architectures, compiler failures and mismatched helpers never produce a successful release', async (t) => {
  const f = await fixture(t)
  const invalid = f.run(['--package', 'universal'])
  assert.equal(invalid.status, 2)
  assert.match(invalid.stderr, /Invalid build architecture/)
  const failed = f.run(['--package'], { TEST_FAIL_ARCH: 'x86_64' })
  assert.equal(failed.status, 9)
  assert.equal((await readdir(f.dist)).includes('Augma-macOS-x86_64.zip'), false)
  const mismatch = f.run(['--package', 'x86_64'], { TEST_HELPER_ARCH: 'arm64' })
  assert.equal(mismatch.status, 1)
  assert.match(mismatch.stderr, /Unexpected architecture/)
  assert.equal((await readdir(f.dist)).includes('Augma-macOS-x86_64.zip'), false)
  assert.equal(await readFile(f.local, 'utf8'), 'existing development app')
})
