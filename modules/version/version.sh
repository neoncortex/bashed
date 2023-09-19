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
		[[ ${#files[@]} -gt 0 ]] \
			&& local res="$(_editfzf '' '/' 1 "${files[@]}")"
		[[ -n $res ]] && cp "$res" "$fn"
	elif [[ $1 == delete ]] || [[ $1 == rm ]]
	then
		[[ -z $2 ]] \
			&& >&2 echo "editundo: delete: no start file" \
			&& return 3
		local head="$2"
		local tail="$3"
		[[ -z $3 ]] && tail="$2"
		for ((i=$head; i<=$tail; ++i))
		do
			[[ -n ${files[$i]} ]] \
				&& rm "${files[$i]}" \
				|| echo "?"
		done
	elif [[ $1 == deletecurses ]] || [[ $1 == du ]]
	then
		[[ ${#files[@]} -gt 0 ]] \
			&& local res="$(_editfzf '-m' '/' 1 "${files[@]}")"
		local IFS=$'\n'
		for i in $res
		do
			rm "$i"
		done
	elif [[ $1 == diff ]]
	then
		[[ -z $2 ]] && [[ -z $3 ]] \
			&& >&2 echo "editundo: diff: no files" \
			&& return 4
		local f1="$2"
		local f2="$3"
		[[ $2 =~ ^[0-9]+ ]] && f1="${files[$2]}"
		[[ $3 =~ ^[0-9]+ ]] && f2="${files[$3]}"
		if [[ -f $f1 ]] && [[ -f $f2 ]]
		then
			diff $diffarg "$f1" "$f2" 
		else
			echo "?"
		fi
	elif [[ $1 == diffcurses ]]
	then
		if [[ -n $2 ]]
		then
			[[ ${#files[@]} -gt 0 ]] \
				&& local res="$(_editfzf '' "/" 1 "${files[@]}")"
			[[ -n $res ]] && diff $diffarg "$2" "$res"
		else
			[[ ${#files[@]} -gt 0 ]] \
				&& local res="$(_editfzf '' "/" 1 "${files[@]}")"
			local resfiles=()
			for i in $res
			do
				resfiles+=($i)
			done

			if [[ ${#resfiles[@]} -gt 0 ]]
			then
				local f1="${resfiles[0]}"
				local f2="${resfiles[1]}"
				[[ -f $f1 ]] && [[ -f $f2 ]] \
					&& diff $diffarg "$f1" "$f2"
			fi
		fi
	elif [[ $1 == es ]] || [[ $1 == show ]]
	then
		[[ -z $2 ]] \
			&& >&2 echo "editundo: es: no filename" \
			&& return 5
		[[ -f ${files[$2]} ]] && editshow a "${files[$2]}"
	elif [[ $1 == esu ]] || [[ $1 == showcurses ]]
	then
		[[ ${#files[@]} -gt 0 ]] \
			&& local res="$(_editfzf '' '/' 1 "${files[@]}")"
		[[ -n $res ]] && editshow a "$res"
	elif [[ $1 == p ]] || [[ $1 == print ]]
	then
		[[ -z $2 ]] \
			&& >&2 echo "editundo: print: no filename" \
			&& return 6
		[[ -f ${files[$2]} ]] \
			&& editshow a "${files[$2]}"
	elif [[ $1 == pu ]] || [[ $1 == printcurses ]]
	then
		[[ ${#files[@]} -gt 0 ]] \
			&& local res="$(_editfzf '' '/' 1 "${files[@]}")"
		[[ -n $res ]] && editshow a "$res"
	elif [[ $1 == copy ]] || [[ $1 == cp ]]
	then
		[[ -z $2 ]] && [[ -z $3 ]] \
			&& >&2 echo "editundo: copy: no file names" \
			&& return 7
		local f1="$2"
		local f2="$3"
		[[ $2 =~ ^[0-9]+ ]] && f1="${files[$2]}"
		[[ $3 =~ ^[0-9]+ ]] && f2="${files[$3]}"
		if [[ -f $f1 ]] && [[ -f $f2 ]]
		then
			cp "$f1" "$f2"
		else
			echo "?"
		fi
	elif [[ $1 == copycurses ]] || [[ $1 == cpu ]]
	then
		[[ -z $2 ]] \
			&& >&2 echo "editundo: copycurses: no destiny" \
			&& return 8
		[[ ${#files[@]} -gt 0 ]] \
			&& local res="$(_editfzf '' '/' 1 "${files[@]}")"
		[[ -n $res ]] && cp "$res" "$2"
	elif [[ $1 =~ [0-9]+ ]]
	then
		[[ -f ${files[$1]} ]] \
			&& cp "${files[$1]}" "$fn" \
			|| echo "?"
		fs="$(wc -l "$fn" | cut -d ' ' -f1)"
		es 1
	else
		echo "?"
		return 9
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
