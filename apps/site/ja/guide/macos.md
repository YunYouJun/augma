# macOS アプリ

macOS アプリは [AR デモ](/ja/guide/ar) をネイティブウインドウに収めたものです。サイドバーでアプリを切り替えられ、オフラインでも使えます。没入モードでは透明なオーバーレイがデスクトップを覆い、音声コマンドでデモを操作することもできます。

<div class="macos-downloads">
  <a class="agm-button agm-button--primary macos-download" href="https://github.com/YunYouJun/augma/releases/latest/download/Augma-macOS-arm64.zip">Apple シリコン版をダウンロード</a>
  <a class="agm-button agm-button--outline macos-download" href="https://github.com/YunYouJun/augma/releases/latest/download/Augma-macOS-x86_64.zip">Intel 版をダウンロード</a>
</div>

macOS 26 以降が必要です。「Apple メニュー → この Mac について」でチップを確認し、Apple シリコンは arm64 版、Intel プロセッサは x86_64 版を選んでください。過去のバージョンと各アーキテクチャの SHA-256 チェックサムは [GitHub Releases](https://github.com/YunYouJun/augma/releases) にあります。

## インストールと初回の起動

1. 対応する `Augma-macOS-arm64.zip` または `Augma-macOS-x86_64.zip` を展開し、`Augma.app` を「アプリケーション」フォルダにドラッグします。
2. ダブルクリックして開きます。アプリはまだ Apple Developer 証明書による署名と公証を受けていないため、macOS が検証できないと表示します。「完了」をクリックします。
3. 「システム設定 → プライバシーとセキュリティ」を開き、「セキュリティ」の「このまま開く」をクリックして確認します。以降は警告なしで開けます。

## できること

- **デモウインドウ**：サイドバーから天気、サウンド、空間、カメラ、ナビなどのアプリを開けます。Web 版の AR デモと同じです。ツールバーで「常に手前に表示」をオンにできます。
- **没入モード**：インターフェースが透明なオーバーレイとして現在のディスプレイを覆い、何もない部分のクリックは下のデスクトップに届きます。右上のコントロールバーで、アプリの切り替え、デスクトップの操作、終了ができます。
- **音声コマンド**：左上のマイクをクリックするか `⌥⌘V` を押して、「地図を開いて」「ナビを開始して」などと話しかけます。英語や中国語でも話せます。初回の利用時に、macOS がマイクと音声認識の許可を求めます。別のキーにするには、「システム設定 → キーボード → キーボードショートカット → アプリのショートカット」で、Augma にメニュータイトル「音声コマンドを開始／終了」を追加します。
- **多言語**：メニューと設定は macOS の言語（简体中文、English、日本語）に従います。「システム設定 → 一般 → 言語と地域 → アプリケーション」で、Augma だけ別の言語を指定することもできます。デモ画面の言語は、その設定パネルでも切り替えられます。

カメラと WebXR は、WebKit のローカルページへの対応状況によります。シミュレーション画面はこれらの許可を必要としません。オプションの DeepSeek アシスタントは質問に答えたりデモの操作を実行したりでき、自分の API キーが必要です。詳しくは[アプリの説明](https://github.com/YunYouJun/augma/tree/main/apps/mac)をご覧ください。

## ソースからビルドする

Node.js 24、pnpm、Xcode 26 以降が必要です。リポジトリのルートで `pnpm mac:run` を実行すると、既定で arm64 版をビルドして起動します。Intel Mac では `AUGMA_BUILD_ARCH=x86_64 pnpm mac:run` を使用してください。`pnpm mac:package` は、リリースと同じ 2 つの Release パッケージ `apps/mac/dist/Augma-macOS-arm64.zip` と `Augma-macOS-x86_64.zip`、それぞれの `.sha256` を生成します。片方だけ作成する場合は `pnpm mac:package arm64` または `pnpm mac:package x86_64` を実行してください。
