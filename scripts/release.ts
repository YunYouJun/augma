import fs from 'node:fs'
import path from 'node:path'

import process from 'node:process'
import minimist from 'minimist'
import { prompt } from 'enquirer'
import { execa } from 'execa'
import semver from 'semver'

import consola from 'consola'
import pkg from '../package.json'

const currentVersion = pkg.version

const args = minimist(process.argv.slice(2))
const preId
  = args.preid
  || (semver.prerelease(currentVersion) && semver.prerelease(currentVersion)[0])

const versionIncrements = [
  'patch',
  'minor',
  'major',
  ...(preId ? ['prepatch', 'preminor', 'premajor', 'prerelease'] : []),
]

const inc = (i: semver.ReleaseType) => semver.inc(currentVersion, i, preId)
function run(bin: string, args: string[], opts = {}) {
  return execa(bin, args, { stdio: 'inherit', ...opts })
}

async function main() {
  let targetVersion = args._[0]

  if (!targetVersion) {
    const { release } = (await prompt({
      type: 'select',
      name: 'release',
      message: 'Select release type',
      choices: versionIncrements
        .map((i: semver.ReleaseType) => `${i} (${inc(i)})`)
        .concat(['custom']),
    })) as any

    if (release === 'custom') {
      targetVersion = ((await prompt({
        type: 'input',
        name: 'version',
        message: 'Input custom version',
        initial: currentVersion,
      })) as any).version
    }
    else {
      targetVersion = release.match(/\((.*)\)/)[1]
    }
  }

  if (!semver.valid(targetVersion))
    throw new Error(`invalid target version: ${targetVersion}`)

  const { yes } = (await prompt({
    type: 'confirm',
    name: 'yes',
    message: `Releasing v${targetVersion}. Confirm?`,
  })) as any

  if (!yes)
    return

  // update all package versions and inter-dependencies
  consola.debug('Updating cross dependencies...')
  updateVersions(targetVersion)

  // build packages
  consola.debug('Building all packages...')
  await run('pnpm', ['build'])

  // publish package
  console.log()
  consola.debug('Publishing packages...')
  await publishPackage('augma', targetVersion)
}

/**
 * get monorepo packages
 */
const packages = fs
  .readdirSync(path.resolve(__dirname, '../packages'))
  .filter(
    p =>
      !p.endsWith('.ts')
      && !p.endsWith('.md')
      && !p.startsWith('.')
      && fs.existsSync(path.resolve(p, 'packages.json')),
  )

function getPkgRoot(pkg: string) {
  return path.resolve(__dirname, `../packages/${pkg}`)
}

function updateVersions(version: string) {
  // 1. update root package.json
  updatePackage(path.resolve(__dirname, '..'), version)
  // 2. update all packages
  packages.forEach(p => updatePackage(getPkgRoot(p), version))
}

function updatePackage(pkgRoot: string, version: string) {
  const pkgPath = path.resolve(pkgRoot, 'package.json')
  const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf-8'))
  pkg.version = version
  updateDeps(pkg, 'dependencies', version)
  updateDeps(pkg, 'peerDependencies', version)
  fs.writeFileSync(pkgPath, `${JSON.stringify(pkg, null, 2)}\n`)
}

function updateDeps(pkg: any, depType: string, version: string) {
  const deps = pkg[depType]
  if (!deps)
    return
  const pkgName = 'augma'
  Object.keys(deps).forEach((dep) => {
    if (
      dep === pkgName
      || (dep.startsWith(`@${pkgName}`)
        && packages.includes(dep.replace(`@${pkgName}`, '')))
    ) {
      consola.warn(`${pkg.name} -> ${depType} -> ${dep}@${version}`)
      deps[dep] = version
    }
  })
}

async function publishPackage(pkgName: string, version: string) {
  const pkgRoot = getPkgRoot(pkgName)
  const pkgPath = path.resolve(pkgRoot, 'package.json')
  const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf-8'))
  if (pkg.private)
    return

  consola.debug(`Publishing [${pkgName}]...`)
  try {
    await run(
      'pnpm',
      ['publish', '--new-version', version, '--access', 'public'],
      {
        cwd: pkgRoot,
        stdio: 'pipe',
      },
    )
    consola.success(`Successfully published ${pkgName}@${version}`)
  }
  catch (e) {
    if (e.stderr.match(/previously published/))
      consola.error(`Skipping already published: ${pkgName}`)
    else
      throw e
  }
}

main().catch((err) => {
  console.error(err)
})
