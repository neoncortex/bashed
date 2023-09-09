#!/usr/bin/env bash

edclipcolor=31
edclipdir="$editdir/clip"
edclipkey="b"
! [[ -f $edclipdir ]] && mkdir -p "$edclipdir"

function _edclipfile {
	[[ -z $1 ]] && return 1
	local name="$1"
	shift
	local files=("$@")
	local clipfile=
	if [[ $name =~ ^[0-9]+$ ]]
	then
		clipfile="${files[$((name - 1))]}"
	else
		for ((i=0; i < ${#files[@]}; ++i))
		do
			[[ ${files[$i]} == $name ]] && clipfile="${files[$i]}"
		done
	fi

	echo "$clipfile"
}

function _editclippopup {
	[[ -z $1 ]] && return 1
	local words=($*)
	[[ -z $words ]] && return 2
	_editfzf 0 "${words[@]}"
	[[ -n $e_uresult ]] && echo "$e_uresult" > "$editwordfile"
}

function _editclipword {
	if tmux run 2>/dev/null
	then
		tmux display-popup -w 80% -h 80% -E \
			"bash -lic '_editclippopup \"$*\"'"
	else
		return 1
	fi

	[[ -f $editwordfile ]] \
		&& local word="$(cat "$editwordfile")" \
		&& local content="$(cat "$edclipdir/$word")" \
		&& tmux send-keys -l "$content" \
		&& rm "$editwordfile"
}

function _editclipstart {
	local IFS=$' \n\t'
	local files=()
	local n=1
	for i in $edclipdir/*
	do
		files+=("$(basename "$i")")
	done

	local res="$(echo ${files[@]})"
	if tmux run 2>/dev/null
	then
		tmux bind-key $edclipkey run -b "bash -ic \"_editclipword $res\""
	fi

	echo "${files[@]}"
}

_editclipstart > /dev/null

function editclipboard {
	[[ -z $1 ]] && return 1
	local filename="$fn"
	local IFS=$' \n\t'
	local files=($(_editclipstart))
	[[ ${#files[@]} -eq 0 ]] && return 2
	if [[ $1 == copy ]] || [[ $1 == c ]]
	then
		local region="$fl"
		[[ -n $2 ]] && region="$2"
		[[ -z $region ]] && return 3
		[[ -n $3 ]] && resname="$3"
		[[ -n $4 ]] && filename="$4" \
			&& filename="$(readlink -f "$filename")"
		[[ -z $filename ]] && return 4
		content="$(es $region "$filename")"
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
	elif [[ $1 == add ]] || [[ $1 == a ]]
	then
		[[ -z $2 ]] && return 5
		[[ -n $3 ]] && resname="$3"
		local content="$2"
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
		local clipfile="$(_edclipfile "$2" "${files[@]}")"
		[[ -z $clipfile ]] && return 8
		local line="$fl"
		[[ -n $3 ]] && line="$3"
		[[ -n $4 ]] && filename="$4" \
			&& filename="$(readlink -f "$filename")"
		[[ -z $filename ]] && return 4
		[[ -z $line ]] && return 7
		editcopy 1 '$' "$edclipdir/$clipfile"
		editpaste "$line" "$filename"
	elif [[ $1 == cut ]] || [[ $1 == x ]]
	then
		local region="$fl"
		[[ -n $2 ]] && region="$2"
		[[ -z $region ]] && return 3
		[[ -n $3 ]] && resname="$3"
		[[ -n $4 ]] && filename="$4" \
			&& filename="$(readlink -f "$filename")"
		[[ -z $filename ]] && return 4
		content="$(es $region "$filename")"
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

		for ((i=0; i < "${#files[@]}"; ++i))
		do
			printf -- '\033[%sm%s\n' "$edclipcolor" "$separator"
			echo "$i - ${files[$i]}"
			printf -- '%s\033[0m\n' "$separator"
			(es a "$edclipdir/${files[$i]}")
		done
	elif [[ $1 == search ]] || [[ $1 == s ]]
	then
		[[ -z $2 ]] && return 1
		local searchresult=()
		for ((i=0; i < ${#files[@]}; ++i))
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
		for ((i=0; i < ${#files[@]}; ++i))
		do
			local g="$(grep --color=always "$2" "$edclipdir/${files[$i]}")"
			[[ -n $g ]] \
				&& searchresult+=("\033[${edclipcolor}m$i - ${files[$i]}\033[0m
$g
")
		done

		local IFS=
		for i in ${searchresult[@]}
		do
			printf -- '%b\n' "$i"
		done
	elif [[ $1 == show ]] || [[ $1 == sh ]]
	then
		[[ -z $2 ]] && return 6
		local clipfile="$(_edclipfile "$2" "${files[@]}")"
		[[ -z $clipfile ]] && return 8
		content="$(cat "$edclipdir/$clipfile")"
		printf -- '%s' "$content"
	elif [[ $1 == delete ]] || [[ $1 == d ]]
	then
		[[ -z $2 ]] && return 6
		local clipfile="$(_edclipfile "$2" "${files[@]}")"
		[[ -z $clipfile ]] && return 8
		[[ -f $edclipdir/$clipfile ]] && rm "$edclipdir/$clipfile"
	elif [[ $1 == rename ]] || [[ $1 == r ]]
	then
		[[ -z $2 ]] && return 6
		local clipfile="$(_edclipfile "$2" "${files[@]}")"
		[[ -z $clipfile ]] && return 8
		[[ -n $3 ]] && local newname="$3" || return 9
		[[ -f $edclipdir/$clipfile ]] && mv "$edclipdir/$clipfile" \
			"$edclipdir/$newname"
	elif [[ $1 == deletecurses ]] || [[ $1 == du ]]
	then
		_editfzf 1 "${files[@]}"
		if [[ ${#e_uresult[@]} -gt 0 ]]
		then
			local IFS=
			for i in "${e_uresult[@]}"
			do
				[[ -f $edclipdir/$i ]] && rm "$edclipdir/$i"
			done

			e_uresult=
		fi
	elif [[ $1 == tx ]]
	then
		[[ -z $2 ]] && return 6
		local clipfile="$(_edclipfile "$2" "${files[@]}")"
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
		local clipfile="$(_edclipfile "$2" "${files[@]}")"
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
	elif [[ $1 == type ]]
	then
		_editclipword "${files[@]}"
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
			COMPREPLY=($(compgen -o default -W "a addcopy c paste p \
				list l delete d deletecurses du cut x tx tw \
				fx fw rename r search s searchcontent sc sh show \
				type" \
				-- $cur))
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
			COMPREPLY=($(compgen -f -- $cur))
			;;
	esac
}

complete -o nospace -o filenames -F _editclipboard editclipboard
complete -o nospace -o filenames -F _editclipboard eclip
