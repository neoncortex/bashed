#!/usr/bin/env bash

editversiondir="$editdir/version"
diffarg="--color -c"

function editstore {
	[[ -n $1  ]] && local fn="$1" && fn="$(readlink -f "$fn")"
	[[ -z $fn ]] \
		&& >&2 echo "editstore: no file" \
		&& return 1
	[[ ${fn:0:1} != '/' ]] && fn="$PWD/$fn"
	local date="$(date +'%Y-%m-%d_%H-%M-%S')"
	local dir="$editversiondir/$(dirname "$fn")"
	mkdir -p "$dir"
	cp "$fn" "$dir"
	mv "$editversiondir/$fn" "$editversiondir/${fn}_${date}"
}

function editundo {
	[[ -n $4  ]] && local fn="$4" && fn="$(readlink -f "$fn")"
	[[ -z $fn ]] \
		&& >&2 echo "editundo: no file" \
		&& return 1
	[[ ${fn:0:1} != '/' ]] && fn="$PWD/$fn"
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
		&& >&2 echo "editundo: no files" \
		&& return 2
	if [[ $1 == l ]] || [[ $1 == list ]]
	then
		local n=1
		for i in ${files[@]}
		do
			local version="/${i/*\/\//}"
			local f="${version:0:${#fn}}"
			if  [[ -f $i ]] && [[ "$fn" == "$f" ]]
			then
				echo "$n - $version"
				n="$((n + 1))"
			fi
		done
	elif [[ $1 == listcurses ]] || [[ $1 == lu ]]
	then
		local res="$(_editfzf '' '/' 1 "${files[@]}")"
		[[ -z $res ]] && return 0
		if [[ -f $res ]]
		then
			 cp "$res" "$fn"
		else
			echo >&2 "editundo: listcurses: file not found"
			return 3
		fi
	elif [[ $1 == delete ]] || [[ $1 == rm ]]
	then
		[[ -z $2 ]] \
			&& >&2 echo "editundo: delete: no start file" \
			&& return 4
		local head="$2"
		local tail="$3"
		[[ -z $3 ]] && tail="$2"
		for ((i=$head; i<=$tail; ++i))
		do
			if [[ -f ${files[$i]} ]]
			then
				rm "${files[$i]}"
			else
				echo >&2 "editundo: delete: file not found"
				return 5
			fi
		done
	elif [[ $1 == deletecurses ]] || [[ $1 == du ]]
	then
		local res="$(_editfzf '-m' '/' 1 "${files[@]}")" \
		[[ -z $res ]] && return 0
		local IFS=$'\n'
		for i in $res
		do
			rm "$i"
		done
	elif [[ $1 == diff ]]
	then
		[[ -z $2 ]] && [[ -z $3 ]] \
			&& >&2 echo "editundo: diff: no files" \
			&& return 6
		local f1="$2"
		local f2="$3"
		[[ $2 =~ ^[0-9]+ ]] && f1="${files[$2]}"
		[[ $3 =~ ^[0-9]+ ]] && f2="${files[$3]}"
		if [[ -f $f1 ]] && [[ -f $f2 ]]
		then
			diff $diffarg "$f1" "$f2" 
		else
			echo >&2 "editundo: diff: cant read files"
			return 7
		fi
	elif [[ $1 == diffcurses ]]
	then
		if [[ -n $2 ]]
		then
			local res="$(_editfzf '' "/" 1 "${files[@]}")"
			[[ -z $res ]] && return 0
			if [[ -f $res ]]
			then
				diff $diffarg "$2" "$res"
			else
				echo >&2 "editundo: diffcurses: file not found"
				return 8
			fi
		else
			local res="$(_editfzf '' "/" 1 "${files[@]}")"
			[[ -z $res ]] && return 0
			local resfiles=()
			for i in $res
			do
				resfiles+=($i)
			done

			if [[ ${#resfiles[@]} -gt 0 ]]
			then
				local f1="${resfiles[0]}"
				local f2="${resfiles[1]}"
			else
				return 9
			fi

			if [[ -f $f1 ]] && [[ -f $f2 ]]
			then
				diff $diffarg "$f1" "$f2"
			else
				echo >&2 "editundo: diffcurses: cant read files"
				return 10
			fi
		fi
	elif [[ $1 == es ]] || [[ $1 == show ]]
	then
		[[ -z $2 ]] \
			&& >&2 echo "editundo: es: no filename" \
			&& return 11
		if [[ -f ${files[$2]} ]]
		then
			editshow a "${files[$2]}"
		else
			echo >&2 "editundo: show: file not found"
			return 12
		fi
	elif [[ $1 == esu ]] || [[ $1 == showcurses ]]
	then
		local res="$(_editfzf '' '/' 1 "${files[@]}")" \
		[[ -z $res ]] && return 0
		if [[ -f $res ]]
		then
			editshow ${2:-a} "$res"
		else
			echo >&2 "editundo: showcurses: file not found"
			return 13
		fi
	elif [[ $1 == p ]] || [[ $1 == print ]]
	then
		[[ -z $2 ]] \
			&& >&2 echo "editundo: print: no filename" \
			&& return 14
		if [[ -f ${files[$2]} ]]
		then
			editshow a "${files[$2]}"
		else
			echo >&2 "editundo: print: file not found"
			return 15
		fi
	elif [[ $1 == pu ]] || [[ $1 == printcurses ]]
	then
		local res="$(_editfzf '' '/' 1 "${files[@]}")" \
		[[ -z $res ]] && return 0
		if [[ -f $res ]]
		then
			 editshow a "$res"
		else
			echo >&2 "editundo: printcurses: file not found"
			return 16
		fi
	elif [[ $1 == copy ]] || [[ $1 == cp ]]
	then
		[[ -z $2 ]] && [[ -z $3 ]] \
			&& >&2 echo "editundo: copy: no file names" \
			&& return 17
		local f1="$2"
		local f2="$3"
		[[ $2 =~ ^[0-9]+ ]] && f1="${files[$2]}"
		[[ $3 =~ ^[0-9]+ ]] && f2="${files[$3]}"
		if [[ -f $f1 ]] && [[ -f $f2 ]]
		then
			cp "$f1" "$f2"
		else
			echo "editundo: copy: file not found"
			return 18
		fi
	elif [[ $1 == copycurses ]] || [[ $1 == cpu ]]
	then
		[[ -z $2 ]] \
			&& >&2 echo "editundo: copycurses: no destiny" \
			&& return 19
		local res="$(_editfzf '' '/' 1 "${files[@]}")" \
		[[ -z $res ]] && return 0
		if [[ -f $res ]]
		then
			cp "$res" "$2"
		else
			echo >&2 "editundo: copycurses: file not found"
			return 20
		fi
	elif [[ $1 =~ [0-9]+ ]]
	then
		if [[ -f ${files[$1]} ]]
		then
			cp "${files[$1]}" "$fn"
		else
			echo >&2 "editundo: file not found"
			return 21
		fi

		fs="$(wc -l "$fn" | cut -d ' ' -f1)"
		es 1
	else
		echo >&2 "?"
		return 22
	fi
}

function et { editstore "$@"; }
function eu { editundo "$@"; }

function _editundo {
	local cur=${COMP_WORDS[COMP_CWORD]}
	case "$COMP_CWORD" in
		1)
			COMPREPLY=($(compgen -o bashdefault -W "copy cp copycurses \
				cpu delete deletecurses du diff diffcurses list \
				listcurses lu print printcurses pu es esu show \
				showcurses" -- $cur))
			;;
		*)
			COMPREPLY=($(compgen -o default -- $cur))
			;;
	esac
}

complete -o nospace -o filenames -F _editundo editundo
complete -o nospace -o filenames -F _editundo eu
