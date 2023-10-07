#!/usr/bin/env bash

[[ -z $editdir ]] && \
	_editalert "highlight: editdir is not set"
! [[ -d $editdir ]] && \
	_editalert "highlight: editdir does not exist"
ehidir="$editdir/syntax/hi"
ehidefs="/usr/share/highlight/langDefs"
ehioutformat="xterm256"
ehitheme=camo

mkdir -p "$ehidir"

function editshowhi {
	local arg="$1"
	[[ -z $arg ]] && arg="+"
	local file="${2:-$fn}"
	file="$(readlink -f "$file")"
	[[ -z $file ]] \
		&& >&2 _editalert "editshowhi: no file" \
		&& return 1
	[[ -z $ehidir ]] \
		&& >&2 _editalert "editshowhi: ehidir is not set" \
		&& return 2
	! [[ -d $ehidir ]] \
		&& >&2 _editalert "editshowhi: ehidir does not exist" \
		&& return 3
	local dir="$ehidir/$(dirname "$file")"
	local name="$(basename "$file")"
	mkdir -p "$dir"
	[[ -n $3 ]] && ehisyntax="$3"
	local rewrite=0
	if [[ $4 -eq rewrite ]]
	then
		rewrite=1
	else
		if [[ -f $dir/$name ]]
		then
			local modorig="$(stat -c %Y "$file")"
			local modsynt="$(stat -c %Y "$dir/$name")"
			[[ $modorig > $modsynt ]] && rewrite=1
		else
			rewrite=1
		fi
	fi

	local syntfile="$dir/${name}__syntax"
	if [[ $rewrite == 1 ]]
	then
		local format="${ehioutformat:-xterm256}"
		local theme="${ehitheme:-camo}"
		[[ -n $ehisyntax ]] && echo "$ehisyntax" > "$syntfile"
		[[ -f $syntfile ]] \
			&& local syntax="$(cat "$syntfile")"
		[[ -n $syntax ]] \
			&& highlight --syntax "$syntax" -s $theme \
				--out-format=$format "$file" > "$dir/$name" \
			|| highlight -s $theme --out-format=$format \
				"$file" > "$dir/$name"
	fi

	edcolor=0 editshow $arg "$dir/$name"
	[[ -z $2 ]] && editshow $arg > /dev/null
	[[ $fn == $2 ]] && editshow $arg > /dev/null
	return 0
}

function _edithiextract {
	local file="${1:-$fn}"
	file="$(readlink -f "$file")"
	[[ -z $file ]] \
		&& >&2 _editalert "_edithiextract: no file" \
		&& return 1
	[[ -z $ehidir ]] \
		&& >&2 _editalert "_edithiextract: ehidir is not set" \
		&& return 2
	! [[ -d $ehidir ]] \
		&& >&2 _editalert "_edithiextract: ehidir does not exist" \
		&& return 3
	local dir="$ehidir/$(dirname "$file")"
	local name="$(basename "$file")"
	[[ -n $2 ]] && ehisyntax="$2"
	local syntfile="$dir/${name}__syntax"
	local defs="${ehidefs:-/usr/share/highlight/langDefs}"
	[[ -n $ehisyntax ]] && local hi_file="$defs/${ehisyntax}.lang"
	! [[ -f $hi_file ]] && hi_file=
	if [[ -f $syntfile ]] && [[ -z $hi_file ]]
	then
		syntax="$(cat "$syntfile")"
		local hi_file="$defs/${syntax}.lang"
	fi

	if [[ -z $hi_file ]] && [[ -n $file ]]
	then
		local extension="${file/*.}"
		[[ -n $extension ]] && hi_file="$defs/${extension}.lang"
		! [[ -f $hi_file ]] && hi_file=
	fi

	if [[ -f $hi_file ]]
	then
		local inside=0
		local words=()
		while read line
		do
			if [[ $line =~ List\ ?=\ ?\{ ]] || [[ $inside -eq 1 ]]
			then
				inside=1
				[[ $line == } ]] && inside=0 && continue
				local word="${line/List\=\{/}"
				word="${word/List\ =\{/}"
				word="${word/List\ =\ \{/}"
				word="${word/List\=\ \{/}"
				word="${word/List\=\{/}"
				word="${word//\"/}"
				word="${word//,/}"
				word="${word//\}/}"
				words+=($word)
				[[ $line =~ },?$ ]] && inside=0
			fi
		done < "$hi_file"

		echo "${words[@]}"
	fi
}

function ess { editshowhi "$@"; }

function _editshowhi {
	local cur=${COMP_WORDS[COMP_CWORD]}
	case "$COMP_CWORD" in
		1)
			COMPREPLY=($(compgen -W "a b c d e f fz g G l m mf n p u v / \
				. $ + -" -- $cur))
			;;
		3)
			local defs=()
			local IFS=$'\n\t '
			local defs="${ehidefs:-/usr/share/highlight/langDefs}"
			for i in $defs/*.lang
			do
				lang="${i/.lang/}"
				lang="${lang/*\//}"
				defs+=("$lang")
			done

			COMPREPLY=($(compgen -W "$(echo ${defs[@]})" -- $cur))
			;;
		4)
			COMPREPLY=($(compgen -W "rewrite" -- $cur))
			;;
		*)
			COMPREPLY=($(compgen -f -- $cur))
			;;
	esac
}

complete -o nospace -o filenames -F _editshowhi editshowhi
complete -o nospace -o filenames -F _editshowhi ess
