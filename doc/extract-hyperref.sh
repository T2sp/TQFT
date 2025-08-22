#!/usr/bin/env bash
# extract-hyperref.sh
#   -m : \hyperref[...] {...} のマクロ全文 + 行番号（1行内にある想定）
#   -a : 出力の先頭にファイル名を付与
# 既定 : [] 内のラベル（キー）一覧を重複除去して出力

set -euo pipefail

show_macros=false
with_filename=false
while getopts ":ma" opt; do
  case "$opt" in
    m) show_macros=true ;;
    a) with_filename=true ;;
    *) echo "Usage: $0 [-m] [-a] file.tex ..." >&2; exit 1 ;;
  esac
done
shift $((OPTIND-1))

if [ $# -lt 1 ]; then
  echo "Usage: $0 [-m] [-a] file.tex ..." >&2
  exit 1
fi

# 環境変数は空文字にしない（Perl 側で誤解されないよう 0/1 で渡す）
FN_FLAG=0
$with_filename && FN_FLAG=1

if $show_macros; then
  # 行番号付きで \hyperref[...] {...} を出力（1行に複数あってもすべて拾う）
  for f in "$@"; do
    env FN="$FN_FLAG" perl -ne '
      # コメント除去（\% は残す）
      s/(?<!\\)%.*$//;

      # \hyperref[...]{...} にマッチ（* 付きは通常ないが許容してもOK）
      while ( /(\\hyperref\s*\[[^\]]*\]\s*{[^}]*})/g ) {
        my $macro = $1;
        my $out = "";
        $out .= "$ARGV\t" if $ENV{FN} && $ENV{FN} ne "0";
        $out .= "$.\t$macro\n";
        print $out;
      }
    ' "$f"
  done
else
  # ラベル（[] の中身）を抽出。複数行またぎに対応して全文読み込み
  tmp=$(mktemp)
  trap 'rm -f "$tmp"' EXIT
  for f in "$@"; do
    env FN="$FN_FLAG" perl -0777 -ne '
      # 複数行対象でコメント除去
      s/(?<!\\)%.*$//mg;

      # \hyperref[...]{...} を走査して [] の中身を抜き出す
      while ( /\\hyperref\s*\[([^\]]*)\]\s*{[^}]*}/gms ) {
        my $label = $1;
        $label =~ s/^\s+|\s+$//g;  # 前後空白除去
        next unless length $label;
        print(($ENV{FN} && $ENV{FN} ne "0") ? "$ARGV\t$label\n" : "$label\n");
      }
    ' "$f"
  done > "$tmp"
  sort -u "$tmp"
fi