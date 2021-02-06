interface Category {
  name: string;
  title: string;
}

export interface Component {
  name: string;
  /**
   * 中文标题
   */
  title: string;
  description?: string;
  category: string;
}

export interface PackageIndexes {
  /**
   * 组件的种类
   */
  categories: Category[];
  components: Component[];
}
