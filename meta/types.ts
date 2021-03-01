interface Category {
  name: string;
  title: string;
}

interface BaseChild {
  name: string;
  title: string;
  description?: string;
  category: string;
}

export interface Component extends BaseChild {}
export interface Hook extends BaseChild {}

export interface PackageIndexes {
  /**
   * 组件的种类
   */
  components: Component[];
  hooks: Hook[];
}
