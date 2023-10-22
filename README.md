# nim_expander

PythonのソースコードをAtCoderに提出可能な単一ソースのものに変換します。

[このツールを使った提出](https://atcoder.jp/contests/abc325/submissions/46861763)

<details>
<summary>展開前のコード</summary>

```nim
include byslib/core

proc main =
  let s, _ = read(string)
  print(s, "san")

if isMainModule: main()
```

</details>

## 注意

* まだバグが存在する可能性があります。コンテスト中に使用する場合は正しく実行できるかを確認してから提出してください。
* コンパイル時にジャッジサーバーにファイルを作成します。AtCoder以外のコンテストサイトでは使用しないでください。

## インストール

```sh
nimble install https://github.com/bayashi-cl/nim_expander
```

## 実行コマンド

```sh
nim_expander -m:path/to/module source.nim
```

例:

```sh
nim_expander -m:~/byslib-nim/src test.nim
```
