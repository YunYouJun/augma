# AI 連携

コーディングアシスタントが、実在するコンポーネント、明確な API、一貫したデザインシステムを使えるようにします。初回リリースは、開発時の統合とインターフェースの構築を対象にしています。

## Skill をインストール

```sh
npx skills add YunYouJun/augma --skill augma
```

リポジトリの Skill は、Codex や Claude など、Agent Skills に対応したコーディングアシスタントで使えます。次のプロンプトはそのまま使えます：

```text
$augma を使って、この Vue プロジェクトにデバイスのコントロールパネルを作成してください。
公開コンポーネントとセマンティックトークンを使い、既存のブランドとアクセシブルな振る舞いを保ってください。
先にコンポーネント API を確認してから、状態の切り替えとインタラクティブなサンプルを実装してください。
```

Skill には次が含まれます：

- `SKILL.md`：統合方法の選び方と、アクセシビリティと動きの約束事。
- `references/components.md`：各コンポーネントのインポート、Props、デフォルト値、イベント、スロット、完全なサンプル。リリースごとにコンポーネントのソースから生成されます。
- `references/recipes.md`：コントロールパネル、HUD ステータス、テーマのカスタマイズの 3 つの完全な画面。
- `references/design.md`：ビジュアル言語とレイアウトの原則。

リファレンスは英語で書かれ、Skill と一緒にインストールされるため、オフラインでも現在のリリースと一致する API を参照できます。このリポジトリ内で開発する場合は、`skills/augma/` を直接読み込んでください。

## 機械可読なエントリー

- [llms.txt](/llms.txt)：簡潔なドキュメントの索引。
- [llms-full.txt](/llms-full.txt)：Markdown ドキュメント一式（簡体字中国語）。
- [components.json](/components.json)：バージョン、インポート、API、サンプル、Registry の URL を含むコンポーネントの契約（説明は簡体字中国語）。
- <a href="/markdown/ja/guide/index.md" download>プレーンテキストのガイド</a>：コーディングアシスタントが直接読み込めます。

すべてのエントリーは、同じソース、サンプル、メタデータから生成されます。`components.json` は `schemaVersion: 1` を使っているため、利用側はバージョンを確認してください。

## コンポーネント Registry {#component-registry}

shadcn-vue を初期化済みの Vue プロジェクトで、次を実行します：

```sh
pnpm dlx shadcn-vue@2.8.2 add https://augma.yyj.moe/r/button.json
pnpm dlx shadcn-vue@2.8.2 add https://augma.yyj.moe/r/dialog.json
```

現在は Button、Input、Panel、Dialog、HudStatus、HudProgress、HudGauge に対応しています。Registry は npm のコンポーネントと同じソースファイルをコピーし、スタイルと振る舞いの依存関係も宣言します。

アプリのエントリーで読み込みます：

```ts
import '@augma/core/style.css'
```

コピーした Vue ファイルは自由に変更できます。Registry 自体は、Augma のスタイルを描画するのに Tailwind を必要としません。ホストプロジェクトに対する CLI の初期化要件は shadcn-vue に従います。

## AI が生成したインターフェースを確認する

実際のインポートと Props が存在するかを確かめ、型チェックとビルドを実行し、キーボードでメインの操作を一通り試し、狭い画面と動きを減らす設定も確認します。次のタスクでコーディングアシスタントを試せます：

1. Select、Switch、Slider を含むコントロールパネルを作る。
2. 正常、待機、エラーの状態を同時に表示する HUD を作る。
3. トークンでアクセントカラーを変え、フォーカスと文字のコントラストを保つ。

[ショーケース](/ja/showcase/) には、この 3 種類のタスクの動作するリファレンスがあり、各サンプルのソースは展開してコピーできます。プレーンテキストのソースファイル：

- <a href="/markdown/compositions/control-panel.vue" download>コントロールパネル</a>
- <a href="/markdown/compositions/hud.vue" download>HUD ステータス</a>
- <a href="/markdown/compositions/theme.vue" download>テーマのカスタマイズ</a>

Skill はデザインと統合の知識を提供します。サイト内のチャットやリアルタイムの UI 生成は、今後の別の機能です。
