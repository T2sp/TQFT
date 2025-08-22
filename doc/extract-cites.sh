#!/usr/bin/env bash
# extract-cites.sh
#   -m : \cite マクロ全文 + 行番号（ファイル名オプション可）
#   -a : ファイル名も出力（-m と併用推奨）
# 既定 : 引用キー一覧（重複除去）

set -euo pipefail

show_macros=false
with_filename=false
while getopts ":ma" opt; do
  case "$opt" in
    m) show_macros=true ;;
    a) with_filename=true ;;
    *) echo "Usage: $0 [-m] [-a] file.tex ..."; exit 1 ;;
  esac
done
shift $((OPTIND-1))

if [ $# -lt 1 ]; then
  echo "Usage: $0 [-m] [-a] file.tex ..."
  exit 1
fi

# 0/1 で常に渡す（空文字にしない）
FN_FLAG=0
$with_filename && FN_FLAG=1

if $show_macros; then
  # 行番号付きで \cite... を出す（1行に複数あっても全部）
  for f in "$@"; do
    env FN="$FN_FLAG" perl -ne '
      # コメント除去（\% は残す）
      s/(?<!\\)%.*$//;

      # 1行内の複数 \cite... をすべて拾う
      while ( /(\\cite[a-zA-Z]*\s*(?:\[[^\]]*\]\s*)*{[^}]*})/g ) {
        my $macro = $1;
        my $out = "";
        $out .= "$ARGV\t" if $ENV{FN} && $ENV{FN} ne "0";
        $out .= "$.\t$macro\n";
        print $out;
      }
    ' "$f"
  done
else
  # キー抽出（重複除去）
  tmp=$(mktemp)
  trap 'rm -f "$tmp"' EXIT
  for f in "$@"; do
    env FN="$FN_FLAG" perl -0777 -ne '
      s/(?<!\\)%.*$//mg;  # コメント除去（複数行）
      while ( /\\cite[a-zA-Z]*\s*(?:\[[^\]]*\]\s*)*{([^}]*)}/gms ) {
        my $keys = $1;
        $keys =~ s/\s+//g;
        for my $k (split /,/, $keys) {
          next unless length $k;
          print(($ENV{FN} && $ENV{FN} ne "0") ? "$ARGV\t$k\n" : "$k\n");
        }
      }
    ' "$f"
  done > "$tmp"
  sort -u "$tmp"
fi