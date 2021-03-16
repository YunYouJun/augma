import * as indexes from "./indexes.json";

const componentNames = indexes.components.map((component) => component.name);
const hookNames = indexes.hooks.map((hook) => hook.name);

export const AugmaChildren = componentNames.concat(hookNames);

export async function getCategories(type: "components" | "hooks") {
  const categories = await import(`./categories.json`);
  return categories.default[type];
}
