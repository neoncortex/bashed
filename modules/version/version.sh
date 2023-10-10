#!/usr/bin/env bash

[[ -z $editdir ]] \
	&& _editalert "version: editdir is not set"
! [[ -d $editdir ]] \
	&& _editalert "version: editdir does not exist"
editversiondir="$editdir/version"
diffarg="--color -c"

mkdir -p "$editversiondir"

function editstore {
	[[ -n $1  ]] \
		&& local fn="$1" \
		&& fn="$(readlink -f "$fn")"
	[[ -z $fn ]] \
		&& _editalert "editstore: no file" \
		&& return 1
	[[ ${fn:0:1} != '/' ]] && fn="$PWD/$fn"
	local date="$(date +'%Y-%m-%d_%H-%M-%S')"
	[[ -z $editversiondir ]] \
		&& _editalert "editstore: editversiondir is not set" \
		&& return 2
	! [[ -d $editversiondir ]] \
		&& _editalert "editstore: editversiondir does not exist" \
		&& return 3
	local dir="$editversiondir/$(dirname "$fn")"
	mkdir -p "$dir"
	cp -- "$fn" "$dir"
	mv -- "$editversiondir/$fn" "$editversiondir/${fn}_${date}"
}

function editundo {
	[[ -n $4  ]] && local fn="$4" && fn="$(readlink -f "$fn")"
	[[ -z $fn ]] \
		&& _editalert "editundo: no file" \
		&& return 1
	[[ ${fn:0:1} != '/' ]] && fn="$PWD/$fn"
	[[ -z $editversiondir ]] \
		&& _editalert "editundo: editversiondir is not set" \
		&& return 2
	! [[ -d $editversiondir ]] \
		&& _editalert "editundo: editversiondir does not exist" \
		&& return 3
	local dir="$editversiondir/$(dirname "$fn")"
	local files=()
	local IFS=$' \t\n'
	if [[ -d "$dir" ]]
	then
		local n=1
		shopt -s dotglob
		for i in $dir/*
		do
			local version="/${i/*\/\//}"
			local f="${version:0:${#fn}}"
			if  [[ -f $i ]] && [[ "$fn" == "$f" ]]
			then
				files[$n]="$i"
				n="$((n + 1))"
			fi
		done

		shopt -u dotglob
	fi

	[[ ${#files[@]} -eq 0 ]] \
		&& _editalert "editundo: no files" \
		&& return 4

	local versionfiles=()
	for i in ${files[@]}
	do
		local version="/${i/*\/\//}"
		local f="${version:0:${#fn}}"
		[[ -f $i ]] \
			&& [[ "$fn" == "$f" ]] \
			&& versionfiles+=("$version")
	done

	if [[ $1 == l ]] || [[ $1 == list ]]
	then
		local n=1
		for i in ${versionfiles[@]}
		do
			local f="${version:0:${#fn}}"
			if  [[ -f $editversiondir$i ]] && [[ "$fn" == "$f" ]]
			then
				printf -- '%s\n' "$n - $i"
				n="$((n + 1))"
			fi
		done
	elif [[ $1 == listcurses ]] || [[ $1 == lu ]]
	then
		local res="$(_editfzf '' "$editversiondir" 1 1 "${versionfiles[@]}")"
		[[ -z $res ]] && return 0
		if [[ -f $editversiondir$res ]]
		then
			cp -- "$editversiondir$res" "$fn"
			fs="$(wc -l "$fn" | cut -d ' ' -f1)"
		else
			_editalert "editundo: listcurses: file not found"
			return 5
		fi
	elif [[ $1 == delete ]] || [[ $1 == rm ]]
	then
		[[ -z $2 ]] \
			&& _editalert "editundo: delete: no start file" \
			&& return 6
		local head="$2"
		local tail="$3"
		[[ -z $3 ]] && tail="$2"
		for ((i=$head; i<=$tail; ++i))
		do
			if [[ -f ${files[$i]} ]]
			then
				edsound=0 _edialert "deleted ${files[$i]}"
				rm "${files[$i]}"
			else
				_editalert "editundo: delete: file not found"
				return 7
			fi
		done
	elif [[ $1 == deletecurses ]] || [[ $1 == du ]]
	then
		local res="$(_editfzf '-m' "$editversiondir" 1 1 "${versionfiles[@]}")"
		[[ -z $res ]] && return 0
		local IFS=$'\n'
		for i in $res
		do
			[[ -f $editversiondir$i ]] \
				&& edsound=0 _editalert "deleted $editversiondir$i" \
				&& rm "$editversiondir$i"
		done
	elif [[ $1 == diff ]]
	then
		[[ -z $2 ]] && [[ -z $3 ]] \
			&& _editalert "editundo: diff: no files" \
			&& return 8
		local f1="$2"
		local f2="$3"
		[[ $2 =~ ^[0-9]+ ]] && f1="${files[$2]}"
		[[ $3 =~ ^[0-9]+ ]] && f2="${files[$3]}"
		if [[ -f $f1 ]] && [[ -f $f2 ]]
		then
			diff $diffarg "$f1" "$f2" 
		else
			_editalert "editundo: diff: cant read files"
			return 9
		fi
	elif [[ $1 == diffcurses ]]
	then
		if [[ -n $2 ]]
		then
			local res="$(_editfzf '' "$editversiondir" 1 1 "${versionfiles[@]}")"
			[[ -z $res ]] && return 0
			if [[ -f $editversiondir$res ]]
			then
				diff $diffarg "$2" "$editversiondir$res"
			else
				_editalert "editundo: diffcurses: file not found"
				return 10
			fi
		else
			local res="$(_editfzf '' "$editversiondir" 1 1 "${versionfiles[@]}")"
			[[ -z $res ]] && return 0
			local resfiles=()
			for i in $res
			do
				resfiles+=($editversiondir$i)
			done

			if [[ ${#resfiles[@]} -gt 0 ]]
			then
				local f1="${resfiles[0]}"
				local f2="${resfiles[1]}"
			else
				return 11
			fi

			if [[ -f $f1 ]] && [[ -f $f2 ]]
			then
				diff $diffarg "$f1" "$f2"
			else
				_editalert "editundo: diffcurses: cant read files"
				return 12
			fi
		fi
	elif [[ $1 == es ]] || [[ $1 == show ]]
	then
		[[ -z $2 ]] \
			&& _editalert "editundo: es: no filename" \
			&& return 13
		if [[ -f ${files[$2]} ]]
		then
			editshow a "${files[$2]}"
		else
			_editalert "editundo: show: file not found"
			return 14
		fi
	elif [[ $1 == esu ]] || [[ $1 == showcurses ]]
	then
		local res="$(_editfzf '' "$editversiondir" 1 1 "${versionfiles[@]}")"
		[[ -z $res ]] && return 0
		if [[ -f $editversiondir$res ]]
		then
			editshow ${2:-a} "$editversiondir$res"
		else
			_editalert "editundo: showcurses: file not found"
			return 15
		fi
	elif [[ $1 == p ]] || [[ $1 == print ]]
	then
		[[ -z $2 ]] \
			&& _editalert "editundo: print: no filename" \
			&& return 16
		if [[ -f ${files[$2]} ]]
		then
			editshow a "${files[$2]}"
		else
			_editalert "editundo: print: file not found"
			return 17
		fi
	elif [[ $1 == pu ]] || [[ $1 == printcurses ]]
	then
		local res="$(_editfzf '' "$editversiondir" 1 1 "${versionfiles[@]}")"
		[[ -z $res ]] && return 0
		if [[ -f $editversiondir$res ]]
		then
			 editshow a "$editversiondir$res"
		else
			_editalert "editundo: printcurses: file not found"
			return 18
		fi
	elif [[ $1 == copy ]] || [[ $1 == cp ]]
	then
		[[ -z $2 ]] && [[ -z $3 ]] \
			&& _editalert "editundo: copy: no file names" \
			&& return 19
		local f1="$2"
		local f2="$3"
		[[ $2 =~ ^[0-9]+ ]] && f1="${files[$2]}"
		[[ $3 =~ ^[0-9]+ ]] && f2="${files[$3]}"
		if [[ -f $f1 ]] && [[ -f $f2 ]]
		then
			cp -- "$f1" "$f2"
		else
			_editalert "editundo: copy: file not found"
			return 20
		fi
	elif [[ $1 == copycurses ]] || [[ $1 == cpu ]]
	then
		[[ -z $2 ]] \
			&& _editalert "editundo: copycurses: no destiny" \
			&& return 21
		local res="$(_editfzf '' "$editversiondir" 1 1 "${versionfiles[@]}")"
		[[ -z $res ]] && return 0
		if [[ -f $editversiondir$res ]]
		then
			cp -- "$editversiondir$res" "$2"
		else
			_editalert "editundo: copycurses: file not found"
			return 22
		fi
	elif [[ $1 =~ [0-9]+ ]]
	then
		if [[ -f ${files[$1]} ]]
		then
			cp -- "${files[$1]}" "$fn"
		else
			_editalert "editundo: file not found"
			return 23
		fi

		fs="$(wc -l "$fn" | cut -d ' ' -f1)"
		es 1
	else
		_editalert "?"
		return 24
	fi
}

function et { editstore "$@"; }
function eu { editundo "$@"; }

function _editundo {
	local IFS=$' \t\n'
	local cur=${COMP_WORDS[COMP_CWORD]}
	case "$COMP_CWORD" in
		1)
			COMPREPLY=($(compgen -o bashdefault -W "copy cp copycurses \
				cpu delete deletecurses du diff diffcurses list \
				listcurses lu print printcurses pu es esu show \
				showcurses" -- $cur))
			;;
		*)
			local IFS=$'\n'
			COMPREPLY=($(compgen -o default -- $cur))
			;;
	esac
}

complete -o nospace -o filenames -F _editundo editundo
complete -o nospace -o filenames -F _editundo eu
