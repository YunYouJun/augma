import assert from 'node:assert/strict'
import test from 'node:test'
import { connect } from '../agent.js'
import { onRequest } from '../middleware.js'

test('connection leaves model and effort to their owners; contains no gateway credentials', () => {
  assert.deepEqual(connect({ gateway: { key: 'must-not-copy' }, model: { id: 'group/augma' } }),
    { version: 1, runtime: 'dsh', managed: true, plugin: 'magpie-plugin-augma' })
})

test('Augma effort applies to Chat and Responses without changing input, tools or reasoning summary', () => {
  for (const effort of ['low', 'medium', 'high', 'xhigh', 'max']) {
    const body = { model: 'group/augma', input: 'hello', tools: [{ type: 'function' }], reasoning: { summary: 'auto', effort: 'low' } }
    const snapshot = structuredClone(body)
    const response = onRequest(body, { agent: 'augma', protocol: 'responses', options: { effort } })
    assert.deepEqual(response.reasoning, { summary: 'auto', effort })
    assert.equal(response.model, 'group/augma')
    assert.deepEqual(response.tools, body.tools)
    assert.equal(response.input, body.input)
    assert.equal(onRequest(body, { agent: 'augma', protocol: 'chat', options: { effort } }).reasoning_effort, effort)
    assert.deepEqual(body, snapshot)
  }
})

test('unrelated clients and unsupported protocols are unchanged', () => {
  const body = { model: 'group/augma', reasoning_effort: 'high' }
  for (const agent of ['codex', 'dsh', undefined, 'augma-other']) {
    assert.equal(onRequest(body, { agent, protocol: 'chat', options: { effort: 'low' } }), body)
  }
  assert.equal(onRequest(body, { agent: 'augma', protocol: 'anthropic' }), body)
})

test('defaults to Medium and rejects invalid saved effort explicitly', () => {
  assert.equal(onRequest({}, { agent: 'augma', protocol: 'chat' }).reasoning_effort, 'medium')
  let rejected
  onRequest({}, { agent: 'augma', protocol: 'chat', options: { effort: 'invalid' }, reject: (status, message) => { rejected = { status, message } } })
  assert.equal(rejected.status, 400)
})
