import assert from 'node:assert/strict'
import { execFileSync, fork, spawn } from 'node:child_process'
import { once } from 'node:events'
import { mkdir, mkdtemp, writeFile } from 'node:fs/promises'
import { createRequire } from 'node:module'
import { tmpdir } from 'node:os'
import { dirname, join, resolve } from 'node:path'
import process from 'node:process'
import { fileURLToPath, pathToFileURL } from 'node:url'

const script = fileURLToPath(import.meta.url)
const augma = resolve(dirname(script), '..')

async function main() {
  if (process.argv[2] === '--host') {
    const [craft, root] = process.argv.slice(3)
    const { CraftHubRuntime } = await import(pathToFileURL(join(craft, 'packages/craft-hub/src/runtime.ts')))
    const { startCraftHubServer } = await import(pathToFileURL(join(craft, 'packages/craft-hub/src/server.ts')))
    const { AgentConnectionService } = await import(pathToFileURL(join(craft, 'packages/craft-hub/src/agent-connection.ts')))
    const { createSessionGuard } = await import(pathToFileURL(join(craft, 'apps/desktop/src/sidecar-host.ts')))
    const runtime = new CraftHubRuntime({ dataDir: join(root, 'runtime'), configDir: join(root, 'configuration') })
    const guard = createSessionGuard('a'.repeat(64), 'b'.repeat(64))
    const server = await startCraftHubServer({ runtime, host: '127.0.0.1', port: 0, authorizeRequest: guard.authorize })
    guard.setOrigin(server.url)
    const service = new AgentConnectionService(runtime)
    let closing
    const close = () => closing ??= (async () => {
      try {
        assert.deepEqual(await runtime.runs(), [])
        assert((await runtime.projects.list()).every(project => project.trust === 'untrusted'))
        await service.update({ enabled: false })
      }
      finally {
        await server.close()
        if (process.connected)
          process.disconnect()
      }
    })()
    process.once('SIGTERM', () => {
      void close()
    })
    process.once('SIGINT', () => {
      void close()
    })
    process.once('disconnect', () => {
      void close()
    })
    try {
      const shared = join(root, 'shared-project')
      const privateProject = join(root, 'private-project')
      await mkdir(shared)
      await mkdir(privateProject)
      await writeFile(join(shared, 'package.json'), JSON.stringify({ name: 'shared-project', scripts: { verify: 'echo never-executed' } }))
      execFileSync('git', ['init', '--quiet', shared])
      execFileSync('git', ['-C', shared, 'remote', 'add', 'origin', 'https://example.com/team/shared-project.git'])
      const project = await runtime.addProject(shared)
      await runtime.addProject(privateProject)
      await service.update({ enabled: true, projectIds: [project.id] })
      const status = await service.status(server.url)
      const configPath = join(root, 'connection.json')
      await writeFile(configPath, JSON.stringify(status.mcpConfig), { mode: 0o600 })
      process.send({ configPath })
    }
    catch (error) {
      await close()
      throw error
    }
  }
  else {
    const craft = resolve(process.argv[2] ?? '../craft-hub')
    const root = await mkdtemp(join(tmpdir(), 'augma-craft-hub-check-'))
    const require = createRequire(join(craft, 'package.json'))
    const child = fork(script, ['--host', craft, root], { execArgv: ['--import', require.resolve('tsx')], stdio: ['ignore', 'ignore', 'inherit', 'ipc'] })
    const identity = () => {
      try {
        return execFileSync('/bin/ps', ['-p', String(child.pid), '-o', 'lstart=', '-o', 'comm='], { encoding: 'utf8' }).trim()
      }
      catch { return '' }
    }
    const started = identity()
    let test
    const stop = () => {
      if (test && test.exitCode === null)
        test.kill('SIGTERM')
      if (child.connected)
        child.disconnect()
    }
    process.once('SIGINT', stop)
    process.once('SIGTERM', stop)
    try {
      const [ready] = await Promise.race([
        once(child, 'message'),
        once(child, 'exit').then(() => { throw new Error('Fixture exited before it was ready') }),
        new Promise((_, reject) => { setTimeout(() => reject(new Error('Fixture startup timed out')), 20000).unref() }),
      ])
      test = spawn('swift', ['test', '--package-path', 'apps/mac', '--filter', 'CraftHubBindingTests/testRealCraftHubHostContractWhenFixtureIsProvided'], {
        cwd: augma,
        env: { ...process.env, AUGMA_CRAFT_HUB_FIXTURE_CONFIG: ready.configPath },
        stdio: 'inherit',
      })
      const [code] = await once(test, 'exit')
      assert.equal(code, 0, 'Swift real-host contract test failed')
    }
    finally {
      stop()
      if (child.exitCode === null) {
        const timer = setTimeout(() => {
          if (identity() === started)
            child.kill('SIGTERM')
        }, 10000)
        try {
          await once(child, 'exit')
        }
        finally {
          clearTimeout(timer)
        }
      }
      assert(!identity(), 'Temporary Craft Hub process did not exit')
      assert.equal(child.exitCode, 0, 'Temporary host cleanup failed')
      process.stdout.write(`Verified temporary host exit. Fixtures retained at ${root}\n`)
    }
  }
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
