# クイックスタート

Augma は『劇場版 ソードアート・オンライン -オーディナル・スケール-』に登場する AR インターフェースの軽やかさを、再利用できる Web コンポーネントにしたものです。独立したデザイン基盤だけを使うことも、すぐに Vue でインターフェースを作り始めることもできます。

## Vue コンポーネント

Vue 3.5 以降が必要です。

```sh
pnpm add augma
```

::: tip pnpm 11 以降
pnpm は承認されていないインストールスクリプトがあるとインストールを失敗させます。augma 0.2.2 以降は `vue-demi` に依存しないため、承認するスクリプトはありません。0.2.1 以前は Reka UI と Floating UI 経由でインストールスクリプトを持つ `vue-demi` が入るため、`pnpm approve-builds` で承認するか、`pnpm-workspace.yaml` に次を書いてください：

```yaml
allowBuilds:
  vue-demi: true
```

また pnpm は公開から 1 日未満のバージョンを既定でスキップするため、リリース当日は 1 つ前のバージョンが入ります。0.1.x は互換性のない旧 API なので、0.2 以降が入っていることを確認してください。
:::

アプリのエントリーでスタイルを読み込みます：

```ts
import 'augma/style.css'
```

コンポーネントでは名前付きでインポートします：

```vue
<script setup lang="ts">
import { AgmButton, AgmPanel } from 'augma'
</script>

<template>
  <AgmPanel title="デバイスに接続">
    <AgmButton>接続を開始</AgmButton>
  </AgmPanel>
</template>
```

グローバル登録も、UnoCSS や Tailwind の設定も不要です。パッケージには TypeScript の型定義が含まれます。Vue コンポーネントが振る舞いを担い、複雑な操作のキーボードとフォーカスは Reka UI が支えます。

## スタイルだけを使う

```sh
pnpm add @augma/core
```

```ts
// セマンティックな変数だけを読み込み、グローバルな要素のスタイルは変えません。
import '@augma/core/tokens.css'
// または、コンポーネントのスタイルを含む完全なエントリー。
import '@augma/core/style.css'
```

```html
<button class="agm-button agm-button--primary" type="button">デバイスに接続</button>
```

CSS パッケージは Vue のランタイムに依存しません。複雑なコンポーネントの操作、セマンティクス、キーボード、フォーカス管理には、ネイティブ要素または対応する振る舞いのコンポーネントが必要です。

## 編集できるソース

shadcn-vue を初期化済みの Vue プロジェクトでは、[Registry](/ja/ai/#component-registry) から任意のコンポーネントのソースをコピーできます。コピーしたコードはプロジェクト側で管理し、スタイルは引き続き `@augma/core/style.css` を参照します。

## テーマ

既定はライトテーマです。ルート要素に `class="dark"` または `data-agm-theme="dark"` を付けるとダークテーマになります。オーバーレイは body にマウントされるため、テーマは局所的なコンテナではなく `html` または `body` に設定してください。

## 0.1 からの移行

0.2 では公開 API を作り直しました。`AgmButton` などの名前付きインポートを使い、スタイルのエントリーは `augma/style.css` です。以前の `app.use(augma)`、ワークスペース内部からのインポート、UnoCSS プリセットは公開インターフェースではなくなりました。

以前の Card のレイアウトには Panel を使えます。Clock とアプリメニューは組み合わせの例になりました。カメラと WebXR は `/ar/` のデモアプリに残るため、コンポーネントをインストールしてもこれらの依存は読み込まれません。
