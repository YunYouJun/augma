/**
 * 生成标签
 * @param frontmatter
 */
export function generateTag(frontmatter: any) {
  const tag: any = {}
  if (frontmatter.description)
    tag.description = frontmatter.description

  if (frontmatter.subtags)
    tag.subtags = frontmatter.subtags

  if (frontmatter.props)
    tag.attributes = frontmatter.props.map(prop => prop.name)

  return tag
}
