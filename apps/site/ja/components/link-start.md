# Link Start リンクスタート

遷移の前に画面を覆い、到着したページの上でフェードアウトする光のトンネル。

約 240 本の光の筋が画面の中央からあふれ出し、中央に LINK START が浮かびます。1 秒後に閃光が画面を覆い、遷移先ページの背景色に落ち着きます。ページが切り替わるとオーバーレイはフェードアウトします。コンポーネントではなく、フレームワークに依存しない関数です。オーバーレイは `document.body` に置かれるため、ルートが切り替わってもアンマウントされません。

## 基本的な使い方

<DemoPreview name="link-start" />

## ルーターと組み合わせる

遷移はコールバックに書きます。`linkStart` は画面が覆われてからそれを実行し、新しいページが表示されてからフェードアウトします。`waitFor` を渡すと、古いページでそのセレクターに一致する要素がなくなるまで待つため、古いページが透けて見えません。

```ts
import { linkStart } from 'augma'
import { useRouter } from 'vue-router'

const router = useRouter()

function enter() {
  return linkStart(() => router.push('/guide/'), { waitFor: '.home' })
}
```

タイミングを自分で制御するときは、段階ごとに呼び出します。`playLinkStart` は画面が覆われた時点で完了し、フェードアウト用の関数を返します。

```ts
import { playLinkStart } from 'augma'

const finish = await playLinkStart({ text: 'SYSTEM CALL' })
await router.push('/guide/')
await finish()
```

## API

### `linkStart(navigate, options?)`

トンネルを再生し、画面が覆われてから `navigate` を実行して、新しいページの上でフェードアウトします。返される Promise はオーバーレイが取り除かれた後に完了します。`navigate` がエラーを投げてもオーバーレイは取り除かれ、エラーはそのまま伝わります。トランジションの再生中に再び呼び出すと同じ Promise を返すため、遷移が二重に実行されることはありません。

| オプション | 型 | デフォルト | 説明 |
| --- | --- | --- | --- |
| `text` | string | 'LINK START' | 中央の文字。空文字列なら表示しません |
| `duration` | number | 1000 | 画面を覆うまでの時間（ミリ秒） |
| `colors` | string[] | ダークテーマの `--agm-cyan`、`--agm-accent`、`--agm-highlight`、`--agm-text` | 光の筋の色。任意の CSS カラーを使えます |
| `arrival` | string | ページの `--agm-bg` | フェード前にとどまる色。遷移先の背景色に合わせます |
| `zIndex` | number | 1000 | オーバーレイの重なり順 |
| `waitFor` | string | undefined | このセレクターに一致する要素がなくなってからフェードします |
| `timeout` | number | 2000 | `waitFor` の最大待ち時間（ミリ秒） |

### `playLinkStart(options?)`

上の表のうち `waitFor` と `timeout` 以外のオプションを受け取ります。画面が覆われた時点で `finish(): Promise<void>` を返して完了します。呼び出すとオーバーレイがフェードアウトし、取り除かれます。

### `waitUntilGone(selector, timeout?)`

`selector` に一致する要素がなくなるか、`timeout`（デフォルト 2000 ミリ秒）を過ぎると完了します。

## アクセシビリティと利用上の注意

- 動きを減らす設定がオンのときはトンネルを再生せず、`navigate` をすぐに実行します。`playLinkStart` は何もしない関数をすぐに返します。
- キャンバスには `aria-hidden="true"` が付き、ポインターイベントを受け取らず、フォーカスも移動しません。フォーカスとタイトルは遷移先ページがいつも通り扱います。
- オーバーレイはフェード後に取り除かれます。描画に失敗した場合やブラウザーが Canvas 2D に対応していない場合もすぐに取り除かれ、遷移を妨げません。バックグラウンドのタブでアニメーションフレームが止まっても、待つのは最大で `duration` に 500 ミリ秒を加えた時間です。
- 色はダークテーマのトークン、書体は `--agm-font` から取り、ページがライトかダークかには左右されません。`[data-agm-theme='dark']` でこれらの変数を上書きするか、`colors` を渡してください。
- `@augma/core/tokens.css` を読み込んでいない場合は、ダークテーマのデフォルト値を使います。
- 「Link Start」のような、プロダクトに入る数少ない瞬間に使います。すべてのリンクには付けないでください。

## インストール

```ts
import { linkStart, playLinkStart, waitUntilGone } from 'augma'
```

Vue を使わない場合は、依存関係のない `@augma/core` から読み込みます。

```ts
import { linkStart } from '@augma/core/link-start'
```
