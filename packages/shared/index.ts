import { Indexable } from "@augma/utils/types";

export type AgmColorType =
  | "default"
  | "primary"
  | "success"
  | "warning"
  | "danger"
  | "info";

export const TypeArray: AgmColorType[] = [
  "default",
  "primary",
  "success",
  "warning",
  "danger",
  "info",
];

export const TypeMap: Indexable<AgmColorType> = {
  default: "default",
  primary: "primary",
  success: "success",
  warning: "warning",
  danger: "danger",
  info: "info",
};

export function getAgmColorByType(type: AgmColorType) {
  if (type && TypeMap[type]) {
    return `var(--agm-${type})`;
  } else {
    return type;
  }
}

export type ComponentSize = "large" | "medium" | "small" | "mini";
