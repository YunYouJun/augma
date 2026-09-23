// Read types and defaults from the same inline Vue macros that compile the library.
// Fail on unsupported declarations instead of quietly producing guessed AI APIs.
export function extractProps(descriptor, compiled) {
  const source = descriptor.scriptSetup.content
  const props = new Map()
  const defaults = new Map()
  const code = node =>
    source.slice(node.start, node.end).replace(/\s+/g, ' ').trim()
  function readDefault(options, target) {
    for (const property of options?.properties ?? []) {
      if (property.type !== 'ObjectProperty')
        throw new Error('Component defaults must use literal object properties')
      target.set(property.key.name ?? property.key.value, code(property.value))
    }
  }
  function visit(node) {
    if (!node || typeof node !== 'object')
      return
    if (node.type === 'CallExpression' && node.callee.type === 'Identifier') {
      const macro = node.callee.name
      if (macro === 'withDefaults')
        readDefault(node.arguments[1], defaults)
      if (macro === 'defineProps') {
        const type = node.typeParameters?.params[0]
        if (type?.type !== 'TSTypeLiteral') {
          throw new Error(
            'Public component props must be an inline TypeScript type',
          )
        }
        for (const member of type.members) {
          if (member.type !== 'TSPropertySignature')
            throw new Error('Unsupported public property declaration')
          const type = code(member.typeAnnotation.typeAnnotation)
          const name = member.key.name ?? member.key.value
          props.set(name, {
            name,
            type,
            required: !member.optional,
            default: !member.optional
              ? '必填'
              : type === 'boolean'
                ? 'false'
                : 'undefined',
          })
        }
      }
      if (macro === 'defineModel') {
        const named = node.arguments[0]?.type === 'StringLiteral'
        const name = named ? node.arguments[0].value : 'modelValue'
        const options = new Map()
        readDefault(node.arguments[named ? 1 : 0], options)
        props.set(name, {
          name,
          type: code(node.typeParameters.params[0]),
          required: options.get('required') === 'true',
          default: options.get('default') ?? 'undefined',
        })
      }
    }
    for (const value of Object.values(node)) {
      if (Array.isArray(value))
        value.forEach(visit)
      else if (value && typeof value === 'object')
        visit(value)
    }
  }
  compiled.scriptSetupAst.forEach(visit)
  for (const [name, value] of defaults) {
    if (!props.has(name))
      throw new Error(`Default for undeclared prop: ${name}`)
    props.get(name).default = value
  }
  return props
}
