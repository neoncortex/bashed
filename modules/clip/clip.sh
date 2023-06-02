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

function edclipfile {
	[[ -z $1 ]] && return 1
	local name="$1"
	shift
	local files=("$@")
	local clipfile=
	if [[ $name =~ [0-9]+ ]]
	then
		clipfile="${files[$((name - 1))]}"
	else
		for ((i=0; i <= ${#files[@]}; ++i))
		do
			[[ ${files[$i]} == $name ]] && clipfile="${files[$i]}"
		done
	fi

	echo "$clipfile"
}

function editclipboard {
	[[ -z $1 ]] && return 1
	local filename="$fn"
	local files=()
	local IFS=$' \n\t'
	local n=1
	for i in $edclipdir/*
	do
		files[$n]="$(basename "$i")"
		n="$((n + 1))"
	done

	[[ ${#files[@]} -eq 0 ]] && return 2
	if [[ $1 == copy ]] || [[ $1 == c ]]
	then
		local region="$fl"
		[[ -n $2 ]] && region="$2"
		[[ -z $region ]] && return 3
		[[ -n $3 ]] && resname="$3"
		[[ -n $4 ]] && filename="$4"
		[[ -z $filename ]] && return 4
		content="$(edsyntax=0 edcmd=p edimg=0 edtables=0 edesc=0 \
			edesch=0 edinclude=0 es $region "$filename")"
		[[ -z $content ]] && return 5
		if [[ -n $resname ]]
		then
			echo "$content" > "$edclipdir/$resname"
		else
			local date="$(date +'%Y-%m-%d_%H-%M-%S')"
			local extension="$(basename "$filename")"
			[[ $extension =~ (^.)?[^.]+\.[^.]+ ]] \
				&& extension=".${filename##*.}" \
				|| extension=
			echo "$content" > "$edclipdir/$date$extension"
		fi
	elif [[ $1 == paste ]] || [[ $1 == p ]]
	then
		[[ -z $2 ]] && return 6
		local clipfile="$(edclipfile "$2" "${files[@]}")"
		[[ -z $clipfile ]] && return 8
		local line="$fl"
		[[ -n $3 ]] && line="$3"
		[[ -n $4 ]] && filename="$4"
		[[ -z $filename ]] && return 4
		[[ -z $line ]] && return 7
		editregion 1 '$' "$edclipdir/$clipfile"
		editread 0 0 "$filename" "$line"
		es "$filename"
	elif [[ $1 == cut ]] || [[ $1 == x ]]
	then
		local region="$fl"
		[[ -n $2 ]] && region="$2"
		[[ -z $region ]] && return 3
		[[ -n $3 ]] && resname="$3"
		[[ -n $4 ]] && filename="$4"
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

		local extension="$(basename "$filename")"
		local date="$(date +'%Y-%m-%d_%H-%M-%S')"
		[[ $extension =~ (^.)?[^.]+\.[^.]+ ]] \
			&& extension=".${filename##*.}" \
			|| extension=
		[[ -n $resname ]] \
			&& echo "$content" > "$edclipdir/$resname" \
			|| echo "$content" > "$edclipdir/$date$extension"
	elif [[ $1 == list ]] || [[ $1 == l ]]
	then
		read -r rows cols < <(stty size)
		local separator=
		for ((i=0; i < $cols; ++i))
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
				es a "$edclipdir/${files[$i]}")
		done
	elif [[ $1 == search ]] || [[ $1 == s ]]
	then
		[[ -z $2 ]] && return 1
		local searchresult=()
		for ((i=1; i <= ${#files[@]}; ++i))
		do
			[[ ${files[$i]} =~ $2 ]] \
				&& searchresult+=("$i - ${files[$i]}")
		done

		local IFS=
		for i in ${searchresult[@]}
		do
			echo "$i"
		done
	elif [[ $1 == searchcontent ]] || [[ $1 == sc ]]
	then
		[[ -z $2 ]] && return 1
		local searchresult=()
		for ((i=1; i <= ${#files[@]}; ++i))
		do
			local g="$(grep "$2" "$edclipdir/${files[$i]}")"
			[[ -n $g ]] \
				&& searchresult+=("$i - ${files[$i]}
$g
")
		done

		local IFS=
		for i in ${searchresult[@]}
		do
			echo "$i"
		done
	elif [[ $1 == delete ]] || [[ $1 == d ]]
	then
		[[ -z $2 ]] && return 6
		local clipfile="$(edclipfile "$2" "${files[@]}")"
		[[ -z $clipfile ]] && return 8
		[[ -f $edclipdir/$clipfile ]] && rm "$edclipdir/$clipfile"
	elif [[ $1 == rename ]] || [[ $1 == r ]]
	then
		[[ -z $2 ]] && return 6
		local clipfile="$(edclipfile "$2" "${files[@]}")"
		[[ -z $clipfile ]] && return 8
		[[ -n $3 ]] && local newname="$3" || return 9
		[[ -f $edclipdir/$clipfile ]] && mv "$edclipdir/$clipfile" \
			"$edclipdir/$newname"
	elif [[ $1 == deletecurses ]] || [[ $1 == du ]]
	then
		editcurses 1 "${files[@]}"
		if [[ ${#e_uresult[@]} -gt 0 ]]
		then
			local IFS=
			for i in "${e_uresult[@]}"
			do
				[[ -f $edclipdir/${files[$i]} ]] && \
					rm "$edclipdir/${files[$i]}"
			done

			e_uresult=
		fi
	elif [[ $1 == tx ]]
	then
		[[ -z $2 ]] && return 6
		local clipfile="$(edclipfile "$2" "${files[@]}")"
		[[ -z $clipfile ]] && return 8
		cat "$edclipdir/$clipfile" | xclip -r -i
	elif [[ $1 == fx ]]
	then
		local content="$(xclip -o)"
		[[ -z $content ]] && return 5
		local resname="$2"
		if [[ -n $resname ]]
		then
			echo "$content" > "$edclipdir/$resname"
		else
			local date="$(date +'%Y-%m-%d_%H-%M-%S')"
			echo "$content" > "$edclipdir/$date"
		fi
	elif [[ $1 == tw ]]
	then
		[[ -z $2 ]] && return 6
		local clipfile="$(edclipfile "$2" "${files[@]}")"
		[[ -z $clipfile ]] && return 8
		cat "$edclipdir/$clipfile" | wl-copy
	elif [[ $1 == fw ]]
	then
		local content="$(wl-paste)"
		[[ -z $content ]] && return 5
		local resname="$2"
		if [[ -n $resname ]]
		then
			echo "$content" > "$edclipdir/$resname"
		else
			local date="$(date +'%Y-%m-%d_%H-%M-%S')"
			echo "$content" > "$edclipdir/$date"
		fi
	fi
}

function eclip { editclipboard "$@"; }

function _editclipboardcompletion {
	local files=()
	for i in $edclipdir/*
	do
		files+=("$(basename "$i")")
	done

	echo "${files[@]}"
}

function _editclipboard {
	local cur=${COMP_WORDS[COMP_CWORD]}
	local prev=${COMP_WORDS[COMP_CWORD-1]}
	case "$COMP_CWORD" in
		1)
			COMPREPLY=($(compgen -o default -W "copy c paste p \
				list l delete d deletecurses du cut x tx tw \
				fx fw rename r search s searchcontent sc" -- $cur))
			;;
		2)
			if [[ $prev == delete ]] || [[ $prev == d ]] \
				|| [[ $prev == rename ]] || [[ $prev == r ]] \
				|| [[ $prev == paste ]] || [[ $prev == p ]] \
				|| [[ $prev == tx ]] || [[ $prev == tw ]]
			then
				COMPREPLY=($(compgen -o default -W \
					"$(_editclipboardcompletion)" -- $cur))
			elif [[ $prev == copy ]] || [[ $prev == c ]] \
				|| [[ $prev == cut ]] || [[ $prev == x ]]
			then
				COMPREPLY=($(compgen -W "a b c d e f g G l m \
					n p u v / . $ + - {1..$fs}" -- $cur))
			else
				COMPREPLY=($(compgen -o default -- $cur))
			fi
			;;
		*)
			COMPREPLY=($(compgen -o default -- $cur))
			;;
	esac
}

complete -F _editclipboard editclipboard
complete -F _editclipboard eclip
