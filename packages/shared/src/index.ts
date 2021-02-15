export type AgmColorType =
  | "primary"
  | "success"
  | "warning"
  | "danger"
  | "info"
  | "default";

export const colorTypes: AgmColorType[] = [
  "primary",
  "success",
  "warning",
  "danger",
  "info",
  "default",
];

export function getAgmColorByType(type: AgmColorType) {
  if (colorTypes.includes(type)) {
    return `var(--agm-${type})`;
  } else {
    return type;
  }
}