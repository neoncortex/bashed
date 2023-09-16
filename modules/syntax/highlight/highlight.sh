#!/usr/bin/env bash

ehidir="$editdir/syntax/hi"
ehidefs="/usr/share/highlight/langDefs"
ehioutformat="xterm256"
ehitheme=camo
mkdir -p "$ehidir"

function editshowhi {
	[[ -z $1 ]] \
		&& >&2 echo "editshowhi: no argument" \
		&& return 2
	local file="${2:-$fn}"
	file="$(readlink -f "$file")"
	[[ -z $file ]] \
		&& >&2 echo "editshowhi: no file" \
		&& return 1
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
		[[ -n $ehisyntax ]] && echo "$ehisyntax" > "$syntfile"
		[[ -f $syntfile ]] \
			&& local syntax="$(cat "$syntfile")"
		[[ -n $syntax ]] \
			&& highlight --syntax "$syntax" -s $ehitheme \
			--out-format=$ehioutformat "$file" > "$dir/$name" \
			|| highlight -s $ehitheme --out-format=$ehioutformat \
			"$file" > "$dir/$name"
	fi

	editshow $1 "$dir/$name"
	[[ -z $2 ]] && editshow $1 > /dev/null
	[[ $fn == $2 ]] && editshow $1 > /dev/null
	return 0
}

function _edithiextract {
	local file="${1:-$fn}"
	file="$(readlink -f "$file")"
	[[ -z $file ]] \
		&& >&2 echo "_edithiextract: no file" \
		&& return 1
	local dir="$ehidir/$(dirname "$file")"
	local name="$(basename "$file")"
	[[ -n $2 ]] && ehisyntax="$2"
	local syntfile="$dir/${name}__syntax"
	[[ -n $ehisyntax ]] && local hi_file="$ehidefs/${ehisyntax}.lang"
	! [[ -f $hi_file ]] && hi_file=
	if [[ -f $syntfile ]] && [[ -z $hi_file ]]
	then
		syntax="$(cat "$syntfile")"
		local hi_file="$ehidefs/${syntax}.lang"
	fi

	if [[ -z $hi_file ]] && [[ -n $file ]]
	then
		local extension="${file/*.}"
		[[ -n $extension ]] && hi_file="$ehidefs/${extension}.lang"
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
