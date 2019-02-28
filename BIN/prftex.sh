#!/bin/sh

######################################################################
#
# prftex.sh
#
# 概要
# TeXファイルを読み込み，推奨されない特定の言い回しに対して警告メッセージを出力
#
# Written by Shinichi Yanagido (s.yanagido@gmail.com) on 2019-02-28
#
######################################################################


######################################################################
# Initial Configuration
######################################################################

# === Initialize shell environment ===================================
set -u
umask 0022
export LC_ALL=C
export UNIX_STD=2003  # to make HP-UX conform to POSIX

# === Define the functions for printing usage and exiting ============
print_usage_and_exit () {
    cat <<-USAGE 1>&2
	Usage   : ${0##*/} [option...] <texfile>
	          ${0##*/} [-h|--help]
	Options : -n          禁止句の個数を表示
	          -w          コメント内も探索
	USAGE
    exit 1
}
exit_trap() {
    set -- ${1:-} $?  # $? is set as $1 if no argument given
    trap '-' EXIT HUP INT QUIT PIPE ALRM TERM
    [ -d "${Tmp:-}" ] && rm -rf "${Tmp%/*}/_${Tmp##*/_}"
    exit $1
}
error_exit() {
    ${2+:} false && echo "${0##*/}: $2" 1>&2
    exit $1
}

# === Detect home directory of this app. and define more =============
Homedir="$(d=${0%/*}/; [ "_$d" = "_$0/" ] && d='./'; pwd)"


######################################################################
# Argument Parsing
######################################################################

# === Print usage and exit if one of the help options is set =========
case "$# ${1:-}" in
    '1 -h'|'1 --help'|'1 --version') print_usage_and_exit;;
esac

# === Initialize parameters ==========================================
red=$(printf    '\e[31m')
green=$(printf  '\e[32m')
yellow=$(printf '\e[33m')
cyan=$(printf   '\e[36m')
clr=$(printf    '\e[0m')
file=''
fform="$Homedir/DATA/forms"
count=''
comment=''

# === Read options ===================================================
while :; do
    case "${1:-}" in
        -n)     # カウント
                count=1
                shift
                ;;
        -w)     # コメント内も探索
                comment=1
                shift
                ;;
        --)     break
                ;;
        --*|-*) error_exit 1 'Invalid option'
                ;;
        *)      break
                ;;
    esac
done

# === Validate argument ==============================================
case $# in [!1]) print_usage_and_exit;; esac # 対象のtexファイルが与えられること
file="$1"
[ ! -r "$file" ] && error_exit 1 'File Open Error'


######################################################################
# Main Routine
######################################################################

# === 検索結果の一時置き場 ===========================================
trap 'exit_trap' EXIT HUP INT QUIT PIPE ALRM TERM
Tmp=`mktemp -d -t "_${0##*/}.$$.XXXXXXXXXXX"` || error_exit 1 'Failed to mktemp'

# === 禁止句の探索 ===================================================
# --- 0.対象ファイルを移動 -------------------------------------------
cp "$file" $Tmp/prfing

# --- 1.標準出力がパイプなら色をつけない -----------------------------
if ! [ -t 1 ]; then
    red=''
    green=''
    yellow=''
    cyan=''
    clr=''
fi

# --- 2.必要に応じてコメントを削除 -----------------------------------
if [ -z "$comment" ]; then
    (rm $Tmp/prfing                                        &&
     nl -s ":" "$file"                                     |
     grep -v '^\s*[0-9]\{1,\}:\s*\(%\|$\)'                 |
     sed 's/\([^\]\)%.*$/\1/'                              |
     awk 'BEGIN             {incomment = 0}                #
          /\\begin{comment}/{incomment = 1}                #
          incomment == 0                                   #
          /\\end{comment}/  {incomment = 0}'               |
     sed "s/^\(\s*[0-9]\{1,\}\)\(:\)/$green\1$cyan\2$clr/" \
     > $Tmp/prfing                                         ) < $Tmp/prfing
fi

# --- 3.禁止句を処理 -------------------------------------------------
if [ -n "$count" ]; then
    # --- 禁止句を数え上げ
    # 1:禁止句 2:分類 3:備考
    cat "$fform" | while read line; do
        pattern=$(echo $line | cut -d ' ' -f 1)
        class=$(echo $line                        |
                cut -d ' ' -f 2                   |
                sed "s/Warning/${red}\0${clr}/"   |
                sed "s/Notice/${yellow}\0${clr}/" )
        desc=$(echo $line | cut -d ' ' -f 3)
        sed "s/$pattern/$pattern\n/g" $Tmp/prfing |
        grep -c "$pattern"                        |
        grep -v '^0$'                             |
        sed "s/^/[$class] $pattern\t:/"           |
        sed "s/$/ :$desc/"
    done

else
    # --- 禁止句を表示
    sed -i "s/^/-/" $Tmp/prfing
    # 1:禁止句 2:分類 3:備考
    cat "$fform" | while read line; do
        pattern=$(echo $line | cut -d ' ' -f 1)
        (rm $Tmp/prfing                      &&
         sed "s/^-\(.*$pattern\)/\1/"        |
         sed "s/$pattern/$red$pattern$clr/g" \
         > $Tmp/prfing                       ) < $Tmp/prfing
    done
    grep -v '^-' $Tmp/prfing
fi


######################################################################
# Finish
######################################################################

exit_trap 0
