#!/usr/bin/env bash

[[ -z $editdir ]] && \
	_editalert "clip: editdir is not set"
! [[ -d $editdir ]] && \
	_editalert "clip: editdir does not exist"
edclipcolor=31
edclipdir="$editdir/clip"
edclipkey="b"

mkdir -p "$edclipdir"

function _edclipfile {
	[[ -z $1 ]] \
		&& _editalert "_edclipfile: no file name" \
		&& return 1
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

function _editclipword {
	[[ -z $edclipdir ]] \
		&& _editalert "_editclipword: edclipdir is not set" \
		&& return 1
	! [[ -d $edclipdir ]] \
		&& _editalert "_editclipword: edclipdir does not exist" \
		&& return 2
	if tmux run 2>/dev/null
	then
		local res="$(_editfzf '' "$edclipdir" 1 1 "$@")"
	else
		_editalert "_edclipword: tmux session not found"
		return 3
	fi

	[[ -n $res ]] \
		&& local content="$(cat "$edclipdir/$res")" \
		&& tmux send-keys -l "$content"
	return 0
}

function _editclipstart {
	local IFS=$' \n\t'
	local files=()
	local n=1
	[[ -z $edclipdir ]] \
		&& _editalert "_editclipstart: edclipdir is not set" \
		&& return 1
	! [[ -d $edclipdir ]] \
		&& _editalert "_editclipstart: edclipdir does not exist" \
		&& return 2
	for i in $edclipdir/*
	do
		files+=("$(basename "$i")")
	done

	local res="$(echo ${files[@]})"
	if tmux run 2>/dev/null
	then
		local key="${edclipkey:-b}"
		tmux bind-key $key run -b "bash -ic \"_editclipword $res\""
	fi

	echo "${files[@]}"
	return 0
}

_editclipstart > /dev/null

function editclipboard {
	[[ -z $edclipdir ]] \
		&& _editalert "editclipboard: edclipdir is not set" \
		&& return 1
	! [[ -d $edclipdir ]] \
		&& _editalert "editclipboard: edclipdir does not exist" \
		&& return 2
	[[ -z $1 ]] \
		&& _editalert "editclipboard: no argument" \
		&& return 3
	local filename="$fn"
	local IFS=$' \n\t'
	local files=($(_editclipstart))
	[[ ${#files[@]} -eq 0 ]] \
		&& _editalert "editclipboard: no files" \
		&& return 4
	if [[ $1 == copy ]] || [[ $1 == c ]]
	then
		local region="$fl"
		[[ -n $2 ]] && region="$2"
		[[ -z $region ]] \
			&& _editalert "editclipboard: copy: no region" \
			&& return 5
		[[ -n $3 ]] && resname="$3"
		[[ -n $4 ]] && filename="$4" \
			&& filename="$(readlink -f "$filename")"
		[[ -z $filename ]] \
			&& _editalert "editclipboard: copy: no filename" \
			&& return 6
		content="$(es $region "$filename")"
		[[ -z $content ]] \
			&& _editalert "editclipboard: copy: no content" \
			&& return 7
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
		[[ -z $2 ]] \
			&& _editalert "editclipboard: add: no content" \
			&& return 8
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
		[[ -z $2 ]] \
			&& _editalert "editclipboard: paste: no clipfile name" \
			&& return 9
		local clipfile="$(_edclipfile "$2" "${files[@]}")"
		[[ -z $clipfile ]] \
			&& _editalert "editclipboard: paste: no clipfile" \
			&& return 10
		local line="${3:-$fl}"
		[[ -n $4 ]] \
			&& filename="$4" \
			&& filename="$(readlink -f "$filename")"
		[[ -z $filename ]] \
			&& _editalert "editclipboard: paste: no filename" \
			&& return 11
		[[ -z $line ]] \
			&& _editalert "editclipboard: paste: no line" \
			&& return 12
		editcopy 1 '$' '' '' "$edclipdir/$clipfile"
		editpaste "$line" '' "$filename"
	elif [[ $1 == cut ]] || [[ $1 == x ]]
	then
		local region="$fl"
		[[ -n $2 ]] && region="$2"
		[[ -z $region ]] \
			&& _editalert "editclipboard: cut: no region" \
			&& return 13
		[[ -n $3 ]] && resname="$3"
		[[ -n $4 ]] \
			&& filename="$4" \
			&& filename="$(readlink -f "$filename")"
		[[ -z $filename ]] \
			&& _editalert "editclipboard: cut: no filename" \
			&& return 14
		content="$(es $region "$filename")"
		[[ -z $content ]] \
			&& _editalert "editclipboard: cut: no content" \
			&& return 15
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
			local color="${edclipcolor:-31}"
			printf -- '\033[%sm%s\n' "$color" "$separator"
			echo "$i - ${files[$i]}"
			printf -- '%s\033[0m\n' "$separator"
			(es a "$edclipdir/${files[$i]}")
		done
	elif [[ $1 == search ]] || [[ $1 == s ]]
	then
		[[ -z $2 ]] \
			&& _editalert "editclipboard: search: no argument" \
			&& return 16
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
		[[ -z $2 ]] \
			&& _editalert "editclipboard: searchcontent: no argument" \
			&& return 17
		local searchresult=()
		for ((i=0; i < ${#files[@]}; ++i))
		do
			local g="$(grep --color=always "$2" "$edclipdir/${files[$i]}")"
			[[ -n $g ]] \
				&& local color="${edclipcolor:-31}" \
				&& searchresult+=("\033[${color}m$i - ${files[$i]}\033[0m
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
		[[ -z $2 ]] \
			&& _editalert "editclipboard: show: no clip filename" \
			&& return 18
		local clipfile="$(_edclipfile "$2" "${files[@]}")"
		[[ -z $clipfile ]] \
			&& _editalert "editclipboard: show: no clip file" \
			&& return 19
		content="$(cat "$edclipdir/$clipfile")"
		printf -- '%s' "$content"
	elif [[ $1 == delete ]] || [[ $1 == d ]]
	then
		[[ -z $2 ]] \
			&& _editalert "editclipboard: delete: no clip filename" \
			&& return 20
		local clipfile="$(_edclipfile "$2" "${files[@]}")"
		[[ -z $clipfile ]] \
			&& _editalert "editclipboard: delete: no clip file" \
			&& return 21
		[[ -f $edclipdir/$clipfile ]] && rm "$edclipdir/$clipfile"
	elif [[ $1 == rename ]] || [[ $1 == r ]]
	then
		[[ -z $2 ]] \
			&& _editalert "editclipboard: rename: no clip filename" \
			&& return 22
		local clipfile="$(_edclipfile "$2" "${files[@]}")"
		[[ -z $clipfile ]] \
			&& _editalert "editclipboard: rename: no clip file" \
			&& return 23
		local newname="$3"
		[[ -z $newname ]] \
			&& _editalert "editclipboard: rename: no new name" \
			&& return 24
		[[ -f $edclipdir/$clipfile ]] \
			&& mv "$edclipdir/$clipfile" "$edclipdir/$newname"
	elif [[ $1 == deletecurses ]] || [[ $1 == du ]]
	then
		local res="$(_editfzf '-m' "$edclipdir" 1 1 "${files[@]}")"
		local IFS=
		for i in $res
		do
			[[ -f $edclipdir/$i ]] \
				&& edsound=0 _edialert "deleted $edclipdir/$i" \
				&& rm "$edclipdir/$i"
		done
	elif [[ $1 == tx ]]
	then
		[[ -z $2 ]] \
			&& _editalert "editclipboard: tx: no clip filename" \
			&& return 25
		local clipfile="$(_edclipfile "$2" "${files[@]}")"
		[[ -z $clipfile ]] \
			&& _editalert "editclipboard: tx: no clip file" \
			&& return 26
		cat "$edclipdir/$clipfile" | xclip -r -i
	elif [[ $1 == fx ]]
	then
		local content="$(xclip -o)"
		[[ -z $content ]] \
			&& _editalert "editclipboard: fx: no content" \
			&& return 27
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
		[[ -z $2 ]] \
			&& _editalert "editclipboard: tw: no clip filename" \
			&& return 28
		local clipfile="$(_edclipfile "$2" "${files[@]}")"
		[[ -z $clipfile ]] \
			&& _editalert "editclipboard: tw: no clip file" \
			&& return 29
		cat "$edclipdir/$clipfile" | wl-copy
	elif [[ $1 == fw ]]
	then
		local content="$(wl-paste)"
		[[ -z $content ]] \
			&& _editalert "editclipboard: fw: no content" \
			&& return 30
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
				|| [[ $prev == tx ]] || [[ $prev == tw ]] \
				|| [[ $prev == type ]]
			then
				COMPREPLY=($(compgen -o default -W \
					"$(_editclipboardcompletion)" -- $cur))
			elif [[ $prev == copy ]] || [[ $prev == c ]] \
				|| [[ $prev == cut ]] || [[ $prev == x ]]
			then
				COMPREPLY=($(compgen -W "a b c d e f g G l m mf \
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
