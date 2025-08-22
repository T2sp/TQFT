#!/usr/bin/env bash
# check-refs-and-labels.sh
# 参照:   \hyperref[<label>]{...} ・・・ 引数で渡した TeX ファイル群のみを対象
# 定義:   \label{<label>} と \begin{my...}[label=...] ・・・ カレントの *.tex 全部を対象
#
# 生成物（TSV; タブ区切り）:
#   defs.tsv      : label <TAB> file <TAB> line <TAB> kind
#   refs.tsv      : label <TAB> file <TAB> line <TAB> macro
#   undefined.tsv : 未定義参照（refs にあるが defs に無い）
#   unused.tsv    : 未使用定義（defs にあるが refs に無い）
#
# 使い方例:
#   ./check-refs-and-labels.sh main.tex chap1.tex
#     → 参照は main.tex/chap1.texのみ、定義は *.tex 全部から

set -euo pipefail

# 引数: 参照元として走査するファイル群（必須）
if [ $# -eq 0 ]; then
  echo "Usage: $0 file.tex [more.tex ...]" >&2
  exit 1
fi
REF_FILES=("$@")

# 定義抽出は *.tex 全部
DEF_FILES=( *.tex )
if [ "${DEF_FILES[0]}" = "*.tex" ]; then
  echo "No .tex files in current directory for definition scan." >&2
  exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

defs="$tmpdir/defs.tsv"
refs="$tmpdir/refs.tsv"
: > "$defs"
: > "$refs"

# -------- 参照（\hyperref[...]{...}）収集：引数の TeX のみ ----------
for f in "${REF_FILES[@]}"; do
  if [ ! -f "$f" ]; then
    echo "Warning: '$f' not found, skipped." >&2
    continue
  fi
  perl -0777 -e '
    use strict; use warnings;
    my $file = shift @ARGV;
    local $/;
    open my $FH, "<:encoding(UTF-8)", $file or die "Cannot open $file: $!";
    my $src = <$FH>;
    close $FH;

    # コメント除去（\% は残す）。改行は保持して行番号の整合性を保つ
    $src =~ s/(?<!\\)%[^\n]*//g;

    # \hyperref[<label>]{...} を複数行対応で走査
    while ( $src =~ /\\hyperref\s*\[([^\]]*)\]\s*{([^}]*)}/gms ) {
      my ($label, $macro) = ($1, $&);
      my $start = $-[0];
      my $line  = (substr($src, 0, $start) =~ tr/\n//) + 1;
      $label =~ s/^\s+|\s+$//g; next unless length $label;
      $macro =~ s/\s+/ /g;  # 出力整形（改行→空白）
      print "$label\t$file\t$line\t$macro\n";
    }
  ' "$f" >> "$refs"
done

# -------- 定義（\label{...}）収集：*.tex 全横断 ----------
for f in "${DEF_FILES[@]}"; do
  perl -0777 -e '
    use strict; use warnings;
    my $file = shift @ARGV;
    local $/;
    open my $FH, "<:encoding(UTF-8)", $file or die "Cannot open $file: $!";
    my $src = <$FH>;
    close $FH;

    $src =~ s/(?<!\\)%[^\n]*//g;

    while ( $src =~ /\\label\s*{([^}]*)}/gms ) {
      my $lab = $1;
      my $start = $-[0];
      my $line  = (substr($src, 0, $start) =~ tr/\n//) + 1;
      $lab =~ s/^\s+|\s+$//g; next unless length $lab;
      print "$lab\t$file\t$line\tlabel\n";
    }
  ' "$f" >> "$defs"
done

# -------- 定義（tcolorbox: \begin{my...}[label=...,...]）収集：*.tex 全横断 ----------
for f in "${DEF_FILES[@]}"; do
  perl -0777 -e '
    use strict; use warnings;
    my $file = shift @ARGV;
    local $/;
    open my $FH, "<:encoding(UTF-8)", $file or die "Cannot open $file: $!";
    my $src = <$FH>;
    close $FH;

    $src =~ s/(?<!\\)%[^\n]*//g;

    # \begin{my...}[ ... ] の最初の [] を対象に options を取り出し、label=... を抽出
    while ( $src =~ /\\begin\s*{(my[^\}]+)}\s*\[([^\]]*)\]/gms ) {
      my ($env, $opt) = ($1, $2);
      my $start = $-[0];
      my $line  = (substr($src, 0, $start) =~ tr/\n//) + 1;

      # label={...} も label=... も拾う（, ] 空白 } まで）
      if ( $opt =~ /(?:^|[,;])\s*label\s*=\s*(\{[^}]*\}|[^\s,\]\}]+)/ ) {
        my $lab = $1;
        $lab =~ s/^\{//; $lab =~ s/\}$//;   # {..} を外す
        $lab =~ s/^\s+|\s+$//g; next unless length $lab;
        print "$lab\t$file\t$line\t$env\n";
      }
    }
  ' "$f" >> "$defs"
done

# -------- 重複除去・突き合わせ（TSV生成） --------
# defs.tsv は file名 (2列目) → label (1列目) の順でソート
sort -t $'\t' -k2,2 -k1,1 -u "$defs" > defs.tsv
sort -u "$refs" > refs.tsv

# 未定義参照（refs にあるが defs にない）
awk -F '\t' 'NR==FNR{defs[$1]=1; next} {if(!($1 in defs)) print $0}' defs.tsv refs.tsv > undefined.tsv

# 未使用定義（defs にあるが refs にない）
awk -F '\t' 'NR==FNR{refs[$1]=1; next} {if(!($1 in refs)) print $0}' refs.tsv defs.tsv > unused.tsv

echo "生成物:"
echo "  defs.tsv      # 定義:  label<TAB>file<TAB>line<TAB>kind"
echo "  refs.tsv      # 参照:  label<TAB>file<TAB>line<TAB>macro"
echo "  undefined.tsv # 未定義参照（参照元ファイル・行番号つき）"
echo "  unused.tsv    # 未使用定義（定義元ファイル・行番号つき）"