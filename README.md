# TQFT

各章のpdfファイルは `doc/out/` にあります．
コンパイル時に必要となる自作スタイルファイルは `https://github.com/T2sp/texmf` に置いてあります．間違いや誤植を発見した場合は `Issues` にて報告していただけると大変助かります．

## ゼミの記録

[YouTube再生リスト](https://www.youtube.com/playlist?list=PLnLS84cs-wbwcPnh9sRyukjq4TURN7PqN)

## Shell Scripts

### `extract-cites.sh`

コメントは除外して引用を検索

- 入力：TeXファイルソース名（複数可）
- 出力：
    - オプション無し：指定したTeXソース内の引用キーを重複を除去して列挙．
    - `-m`：`\cite` の全文（オプション込み）を，ソース内の行数と共に列挙．
    - `-ma`：`\cite` の全文（オプション込み）を，ファイル名およびソース内の行数と共に列挙．

### `extract-hyperref.sh`

コメントは除外して相対参照を検索

- 入力：TeXファイルソース名（複数可）
- 出力：
    - オプション無し：指定したTeXソース内の `\hyperref[A]{B}` の `A` を重複を除去して列挙．
    - `-m`：`\hyperref` の全文（オプション込み）を，ソース内の行数と共に列挙．
    - `-ma`：`\hyperref` の全文（オプション込み）を，ファイル名およびソース内の行数と共に列挙．

### `check-labels.sh`

コメントは除外して相対参照を検索し，参照元と照合

- 入力：TeXファイルソース名（複数可）
- 出力：
    - `defs.tsv`      # 定義:  label<TAB>file<TAB>line<TAB>kind
    - `refs.tsv`      # 参照:  label<TAB>file<TAB>line<TAB>macro
    - `undefined.tsv` # 未定義参照（参照元ファイル・行番号つき）
    - `unused.tsv`    # 未使用定義（定義元ファイル・行番号つき）