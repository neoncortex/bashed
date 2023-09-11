#!/usr/bin/env bash

editversiondir="$editdir/version"
diffarg="--color -c"

function editstore {
	[[ -n $1  ]] && local fn="$1" && fn="$(readlink -f "$fn")"
	[[ -z $fn ]] && return 1
	[[ ${fn:0:1} != '/' ]] && fn="$PWD/$fn"
	local date="$(date +'%Y-%m-%d_%H-%M-%S')"
	local dir="$editversiondir/$(dirname "$fn")"
	mkdir -p "$dir"
	cp "$fn" "$dir"
	mv "$editversiondir/$fn" "$editversiondir/${fn}_${date}"
}

function editundo {
	[[ -n $4  ]] && local fn="$4" && fn="$(readlink -f "$fn")"
	[[ -z $fn ]] && return 1
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

	[[ ${#files[@]} -eq 0 ]] && return 2
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
		[[ ${#files[@]} -gt 0 ]] && _editfzf 0 "${files[@]}"
		if [[ -n $e_uresult ]]
		then
			eo "$e_uresult"
			e_uresult=
		fi
	elif [[ $1 == delete ]] || [[ $1 == rm ]]
	then
		[[ -z $2 ]] && return 3
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
		[[ ${#files[@]} -gt 0 ]] && _editfzf 1 "${files[@]}"
		if [[ ${#e_uresult[@]} -gt 0 ]]
		then
			local IFS=$'\n'
			for i in "${e_uresult[@]}"
			do
				[[ -f $i ]] && rm "$i"
			done

			e_uresult=
		fi
	elif [[ $1 == diff ]]
	then
		[[ -z $2 ]] && [[ -z $3 ]] && return 4
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
			[[ ${#files[@]} -gt 0 ]] && _editfzf 0 "${files[@]}"
			if [[ -n $e_uresult ]]
			then
				diff $diffarg "$2" "$e_uresult"
				e_uresult=
			fi
		else
			[[ ${#files[@]} -gt 0 ]] && _editfzf 1 "${files[@]}"
			if [[ ${#e_uresult[@]} -gt 0 ]]
			then
				local f1="${e_uresult[0]}"
				local f2="${e_uresult[1]}"
				diff $diffarg "$f1" "$f2"
				e_uresult=
			fi
		fi
	elif [[ $1 == es ]] || [[ $1 == show ]]
	then
		[[ -z $2 ]] && return 5
		[[ -f ${files[$2]} ]] && editshow a "${files[$2]}"
	elif [[ $1 == esu ]] || [[ $1 == showcurses ]]
	then
		[[ ${#files[@]} -gt 0 ]] && _editfzf 0 "${files[@]}"
		if [[ -n $e_uresult ]]
		then
			editshow a "$e_uresult"
			e_uresult=
		fi
	elif [[ $1 == p ]] || [[ $1 == print ]]
	then
		[[ -z $2 ]] && return 6
		[[ -f ${files[$2]} ]] \
			&& editshow a "${files[$2]}"
	elif [[ $1 == pu ]] || [[ $1 == printcurses ]]
	then
		[[ ${#files[@]} -gt 0 ]] && _editfzf 0 "${files[@]}"
		if [[ -n $e_uresult ]]
		then
			editshow a "$e_uresult"
			e_uresult=
		fi
	elif [[ $1 == copy ]] || [[ $1 == cp ]]
	then
		[[ -z $2 ]] && [[ -z $3 ]] && return 7
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
		[[ -z $2 ]] && return 8
		[[ ${#files[@]} -gt 0 ]] && _editfzf 0 "${files[@]}"
		if [[ -n $e_uresult ]]
		then
			cp "$e_uresult" "$2"
			e_uresult=
		fi
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
