#!/bin/sh

######################################################################
#
# prftex.sh
#
# # 概要
# .texファイルを読み込み，推奨されない特定の言い回しに対して警告メッセージを出力
#
# Written by Shinichi Yanagido (s.yanagido@gmail.com) on 2018-11-27
#
######################################################################

# === Initialize shell environment ===================================
set -u
umask 0022
export LC_ALL=C
type command >/dev/null 2>&1 && type getconf >/dev/null 2>&1 &&
    export PATH="$(command -p getconf PATH)${PATH+:}${PATH-}"
export UNIX_STD=2003  # to make HP-UX conform to POSIX

# === Define the functions for printing usage and exiting ============
print_usage_and_exit () {
    cat <<-USAGE 1>&2
	Usage   : ${0##*/}
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
Homedir="$(d=${0%/*}/; [ "_$d" = "_$0/" ] && d='./'; cd "$d.."; pwd)"
# PATH="$Homedir/bin:$Homedir/tool:$PATH"       # for additional command
# . "$Homedir/conf/COMMON.SHLIB" # read common configuration


######################################################################
# Argument Parsing
######################################################################

# === Print usage and exit if one of the help options is set =========
case "$# ${1:-}" in
    '1 -h'|'1 --help'|'1 --version') print_usage_and_exit;;
esac

# === Initialize parameters ==========================================
file=''
fform='./forms'
grepopts=''

# === Validate argument ==============================================
case $# in [!1]) print_usage_and_exit;; esac # 対象のtexファイルが与えられること
file="$1"
[ ! -r "$file" ] && error_exit 1 'File Open Error'


######################################################################
# Main Routine
######################################################################

# === コメントを除いて，禁止句の探索 =================================
nl -s ': ' "$file"                                                        |
    grep -v '^\s*%'                                                       |
    sed 's/[^\]%.*$//'                                                    |
    awk 'BEGIN{incomment = 0;}                                            #
         /\\begin{comment}/{incomment = 1}                                #
         incomment == 0                                                   #
         /\\end{comment}/{incomment = 0}'                                 |
    while read line; do                                                   #
        cut -d ' ' -f 1 "$fform"                                        | #
            while read pattern; do                                      # #
                echo "$line"                                          | # #
                    grep "$pattern"                                   | # #
                    sed -r "s/$pattern/\x1b[38;5;9m$pattern\x1b[0m/g" | # #
                    sed "s/$/\n/"                                       # #
            done                                                          #
    done


######################################################################
# Finish
######################################################################

exit_trap 0
