#!/usr/bin/env bash

ehidir="$editdir/syntax/hi"
ehidefs="/usr/share/highlight/langDefs"
ehioutformat="xterm256"
mkdir -p "$ehidir"

function editshowhi {
	[[ -z $1 ]] && return 1
	local file="${2:-$fn}"
	[[ -z $file ]] && return 2
	local dir="$ehidir/$(dirname "$file")"
	local name="$(basename "$file")"
	mkdir -p "$dir"
	[[ -n $3 ]] && ehisyntax="$3"
	local rewrite=0
	if [[ -f $dir/$name ]]
	then
		local modorig="$(stat -c %Y "$file")"
		local modsynt="$(stat -c %Y "$dir/$name")"
		[[ $modorig > $modsynt ]] && rewrite=1
	else
		rewrite=1
	fi

	local syntfile="$dir/${name}__syntax"
	if [[ $rewrite == 1 ]]
	then
		[[ -n $ehisyntax ]] && echo "$ehisyntax" > "$syntfile"
		[[ -f $syntfile ]] \
			&& local syntax="$(cat "$syntfile")"
		[[ -n $syntax ]] \
			&& highlight --syntax "$syntax" \
			--out-format=$ehioutformat "$file" > "$dir/$name" \
			|| highlight --out-format=$ehioutformat \
			"$file" > "$dir/$name"
	fi

	editshow $1 "$dir/$name"
	[[ -z $2 ]] && editshow $1 > /dev/null
	[[ $fn == $2 ]] && editshow $1 > /dev/null
}

function ess { editshowhi "$@"; }

function _editshowhi {
	local cur=${COMP_WORDS[COMP_CWORD]}
	case "$COMP_CWORD" in
		1)
			COMPREPLY=($(compgen -W "a b c d e f g G l m n p u v / \
				. $ + - {1..$fs}" -- $cur))
			;;
		3)
			local defs=()
			for i in $ehidefs/*.lang
			do
				lang="${i/.lang/}"
				lang="${lang/*\//}"
				defs+=("$lang")
			done

			COMPREPLY=($(compgen -W "$(echo ${defs[@]})" -- $cur))
			;;
		*)
			COMPREPLY=($(compgen -f -- $cur))
			;;
	esac
}

complete -o nospace -o filenames -F _editshowhi editshowhi
complete -o nospace -o filenames -F _editshowhi ess
