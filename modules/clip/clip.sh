#!/usr/bin/env bash

edclipdir="$editdir/clip"
! [[ -f $edclipdir ]] && mkdir -p "$edclipdir"

edclipimg=$edimg
edclipinclude=$edinclude
edclipsyntax=$edsyntax
edcliptables=$edtables
edclipcmd=$edcmd
edclipesc=$edesc
edclipesch=$edesch

function editclipboard {
	[[ -z $1 ]] && return 1
	local filename="$fn"
	local files=()
	local IFS=$' \t\n'
	local n=1
	for i in $edclipdir/*
	do
		files[$n]="$i"
		n="$((n + 1))"
	done

	[[ ${#files[@]} -eq 0 ]] && return 2
	if [[ $1 == copy ]] || [[ $1 == c ]]
	then
		local region="$fl"
		[[ -n $2 ]] && region="$2"
		[[ -z $region ]] && return 3
		[[ -n $3 ]] && filename="$3"
		[[ -z $filename ]] && return 4
		content="$(edsyntax=0 edcmd=p edimg=0 edtables=0 edesc=0 \
			edesch=0 edinclude=0 es $region "$filename")"
		[[ -z $content ]] && return 5
		local extension="$(basename "$filename")"
		[[ $extension =~ (^.)?[^.]+\.[^.]+ ]] \
			&& extension=".${filename##*.}" \
			|| extension=
		echo "$content" > "$edclipdir/$(date +'%Y-%m-%d_%H-%M-%S')$extension"
	elif [[ $1 == paste ]] || [[ $1 == p ]]
	then
		[[ -z $2 ]] && return 6 || clipfile="${files[$2]}"
		local line="$fl"
		[[ -n $3 ]] && line="$3"
		[[ -n $4 ]] && filename="$4"
		[[ -z $filename ]] && return 4
		[[ -z $line ]] && return 7
		editregion 1 '$' "$clipfile"
		editread 0 0 "$filename" "$line"
	elif [[ $1 == cut ]] || [[ $1 == x ]]
	then
		local region="$fl"
		[[ -n $2 ]] && region="$2"
		[[ -z $region ]] && return 3
		[[ -n $3 ]] && filename="$3"
		[[ -z $filename ]] && return 4
		content="$(edsyntax=0 edcmd=p edimg=0 edtables=0 edesc=0 \
			edesch=0 edinclude=0 es $region "$filename")"
		[[ -z $content ]] && return 5
		if [[ $region =~ , ]]
		then
			local head="${region/,*/}"
			local tail="${region/*,/}"
			[[ $head == . ]] && head="$fl"
			local res="$(eo "$filename"; es "$head"; edel "$tail")"
		else
			local res="$(eo "$filename"; es "$region"; edel)"
		fi

		echo "$content" > "$edclipdir/$(date +'%Y-%m-%d_%H-%M-%S')"
	elif [[ $1 == list ]] || [[ $1 == l ]]
	then
		read -r rows cols < <(stty size)
		local separator=
		for ((j=0; j < $cols; ++j))
		do
			[[ -z $separator ]] \
				&& separator="-" \
				|| separator="${separator}-"
		done
		for ((i=1; i <= "${#files[@]}"; ++i))
		do
			echo "$separator"
			echo "$i - ${files[$i]}"
			echo "$separator"
			(edimg=$edclipimg edsyntax=$edclipsyntax edcmd=$edclipcmd \
				edtables=$edcliptables edesc=$edclipesc \
				edesch=$edclipesch edinclude=$edclipinclude \
				es a "${files[$i]}")
		done
	elif [[ $1 == delete ]] || [[ $1 == d ]]
	then
		[[ -z $2 ]] && return 6 || clipfile="${files[$2]}"
	elif [[ $1 == deletecurses ]] || [[ $1 == du ]]
	then
		editcurses 1 "${files[@]}"
		if [[ ${#e_uresult[@]} -gt 0 ]]
		then
			local IFS=
			for i in "${e_uresult[@]}"
			do
				[[ -f ${files[$i]} ]] && rm "${files[$i]}"
			done

			e_uresult=
		fi
	elif [[ $1 == tx ]]
	then
		[[ -z $2 ]] && return 6 || clipfile="${files[$2]}"
		cat "$clipfile" | xclip -r -i
	elif [[ $1 == fx ]]
	then
		local content="$(xclip -o)"
		[[ -z $content ]] && return 5
		[[ -n $2 ]] && local filetype=".$2"
		echo "$content" > "$edclipdir/$(date +'%Y-%m-%d_%H-%M-%S')$filetype"
	elif [[ $1 == tw ]]
	then
		[[ -z $2 ]] && return 6 || clipfile="${files[$2]}"
		cat "$clipfile" | wl-copy
	elif [[ $1 == fw ]]
	then
		local content="$(wl-paste)"
		[[ -z $content ]] && return 5
		[[ -n $2 ]] && local filetype=".$2"
		echo "$content" > "$edclipdir/$(date +'%Y-%m-%d_%H-%M-%S')$filetype"
	fi
}

function eclip { editclipboard "$@"; }

function _editclipboard {
	local cur=${COMP_CWORDS[COMP_CWORD]}
	case "$COMP_CWORD" in
		1)
			COMPREPLY=($(compgen -o bashdefault -W "copy c paste p \
				list l delete d deletecurses du cut x tx tw \
				fx fw" -- $cur))
			;;
		*)
			COMPREPLY=($(compgen -o bashdefault --$cur))
			;;
	esac
}

complete -F _editclipboard editclipboard
complete -F _editclipboard eclip
