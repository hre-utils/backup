#!/bin/bash
#
# changelog:
#  2021-04-12 :: Added CLI args (--help, and --config to edit the conf file)

#───────────────────────────────────( init )────────────────────────────────────
# Colors:
rst=$(tput sgr0)                          # Reset
bk="\033[30m"                             # Black
rd="\033[31m"     ; brd="\033[31;1m"      # Red    / Bright Red
gr="\033[32m"     ; bgr="\033[32;1m"      # Green  / Bright Green
yl="\033[33m"     ; byl="\033[33;1m"      # Yellow / Bright Yellow
bl="\033[34m"     ; bbl="\033[34;1m"      # Blue   / Bright Blue
cy="\033[36m"     ; bcy="\033[36;1m"      # Cyan   / Bright Cyan
wh="\033[37m"     ; bwh="\033[37;1m"      # White  / Bright White

trap 'printf $rst' EXIT    # Ensure we're not left with a whacky terminal color
trap 'exit 0' INT          # ^C breaks out of everything, not just one rsync

# If file is linked from this repo to another dir (~/bin, /usr/bin/, etc), will
# still properly load its lib file.
if [[ -L "${BASH_SOURCE[0]}" ]] ; then
   PROGDIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" ; pwd)"
else
   PROGDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd)"
fi

LOGDIR="${PROGDIR}/logs/backup"
[[ ! -d "$LOGDIR" ]] && mkdir -p "$LOGDIR"

CONFIGFILE="${PROGDIR}/config/backup.config"
[[ ! -e "$CONFIGFILE" ]] && {
   echo "${rd}◆${rst} No config file found."
   exit 1
}

source "$CONFIGFILE"

[[ -z "${__basedir__}" ]] && {
   echo "${rd}◆${rst} ERROR: No ${bwh}__basedir__${rst} specified."
   exit 2
}

[[ -z "${__sections__[@]}" ]] && {
   echo "${rd}◆${rst} ERROR: No ${bwh}__sections__${rst} specified."
   exit 3
}

#────────────────────────────────( function(s) )────────────────────────────────
function usage {
cat <<EOF

USAGE: $(basename ${BASH_SOURCE[0]}) [-ch]

Utility for more easily backing up a number of directories with rsync. Paths are
specified in a bash-syntax configuration file, located relative to this file. By
default: ./config/backup.config

Options:
   -h | --help       Print this message and exit
   -c | --conf       Opens config file in EDITOR

EOF

exit $1
}

declare -ag exclusions

function build_exclusions {
   section="$1" 

   declare -n section_exclusions=${section}_exclude
   [[ ${#section_exclusions[@]} -eq 0 ]] && return 0

   for ex in "${section_exclusions[@]}" ; do
      exclusions+=( --exclude $ex )
   done
}


function do_backup {
   for section in "${!__sections__[@]}" ; do
      eval "src=( "\${${section}[@]}" )"
      [[ ${#src[@]} -eq 0 ]] && continue

      unset exclusions
      build_exclusions $section

      _dest="${__sections__[$section]}"
      dest="${__host__:+${__host__}:}${__basedir__}/${_dest}"

      echo "#──( START )──┤ $(date '+%Y/%b/%d %H:%m:%S')" >> "${LOGDIR}/${section}.errlog"
      
      rsync -avLK --delete --mkpath ${exclusions[@]} -e ssh "${src[@]}" "$dest" \
            2>>"${LOGDIR}/${section}.errlog"

      echo "#──(  END  )──┤ $(date '+%Y/%b/%d %H:%m:%S')" >> "${LOGDIR}/${section}.errlog"
   done
}


#══════════════════════════════════╡ ENGAGE ╞═══════════════════════════════════
# Set defaults:
__edit_conf__=false

while [[ $# -gt 0 ]] ; do
   case $1 in
      -h|--help|help)
            usage 0
            ;;
      -c|--conf|--config|conf|config)
            exec ${EDITOR:-vi} $CONFIGFILE
            ;;
      -e|--err|--error|err|error|errors)
            exec xdg-open $LOGDIR
            ;;
      *)
            echo -e "${rd}◆${rst} '${bwh}${1}${rst}' is not a valid option"
            usage 1
            ;;
   esac
done

do_backup
