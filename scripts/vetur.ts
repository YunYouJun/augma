/**
 * 生成标签
 * @param frontmatter
 */
export function generateTag(frontmatter: any) {
  const tag: any = {};
  if (frontmatter.description) {
    tag.description = frontmatter.description;
  }
  if (frontmatter.subtags) {
    tag.subtags = frontmatter.subtags;
  }
  if (frontmatter.attributes) {
    tag.attributes = frontmatter.attributes;
  }
  return tag;
}
