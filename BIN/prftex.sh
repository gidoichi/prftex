#!/bin/sh

######################################################################
#
# prftex.sh
#
# 概要
# .texファイルを読み込み，推奨されない特定の言い回しに対して警告メッセージを出力
#
# Written by Shinichi Yanagido (s.yanagido@gmail.com) on 2019-02-26
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
	Usage   : ${0##*/} <texfile>
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
file=''
fform="$Homedir/DATA/forms"
count=false

# === Read options ===================================================
while :; do
    case "${1:-}" in
        -n)     # カウント
                count=true
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
# --- 0.コメントの削除 -----------------------------------------------
nl -s ': ' "$file"                      |
grep -v '^\s*[0-9]\{1,\}:\s*%'          |
sed 's/[^\]%.*$//'                      |
awk 'BEGIN             {incomment = 0}  #
     /\\begin{comment}/{incomment = 1}  #
     incomment == 0                     #
     /\\end{comment}/  {incomment = 0}' > $Tmp/prfing

# --- 1.禁止句の処理 -------------------------------------------------
if $count; then
    # --- 禁止句の数え上げ
    cut -d ' ' -f 1 "$fform" | while read pattern; do
        grep -c $pattern $Tmp/prfing | grep -v 0 | sed "s/^/$pattern: /"
    done
else
    # --- 禁止句の表示
    cut -d ' ' -f 1 "$fform" | while read pattern; do
        sed -i "s/$pattern/\x1b[38;5;1m${pattern}\x1b[0m/g" $Tmp/prfing
    done
    grep '\[38;5;1m' $Tmp/prfing
fi


######################################################################
# Finish
######################################################################

exit_trap 0
