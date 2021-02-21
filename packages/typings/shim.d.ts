// index
declare type Indexable<T> = {
  [key: string]: T;
};

declare type Hash<T> = Indexable<T>;

declare type Nullable<T> = T | null;
