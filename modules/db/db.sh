#!/usr/bin/env bash

edbfile="$editdir/db"
edbfiletemp="$editdir/db.temp"
edbfilescache="$editdir/dbfiles.cache"
edbtagscache="$editdir/dbtags.cache"

function editdbinsert {
	! [[ -f $edbfile ]] && touch "$edbfile"
	local filename="$fn"
	[[ -n $1 ]] && filename="$1"
	local exist=0
	local IFS=$'\n'
	while read -r line
	do
		local f="${line/$'\t'*/}"
		[[ $f == $filename ]] \
			&& exist=1 \
			&& local tags="${line/*$'\t'/}" \
			&& break
	done < "$edbfile"

	[[ $exist -eq 1 ]] && return 2
	local filedir="$(dirname "$filename")"
	while read -r line
	do
		local f="${line/$'\t'*/}"
		[[ $f == $filedir ]] \
			&& local tags="${line/*$'\t'/}" \
			&& break
	done < "$edbfile"

	local entry="$filename"
	local tags_a=()
	local IFS=$','
	for i in $tags
	do
		tags_a+=("$i")
	done

	for i in $2
	do
		tags_a+=("$i")
	done

	local tags_entry=
	for ((i=0; i < ${#tags_a[@]}; ++i))
	do
		[[ -z $tags_entry ]] \
			&& tags_entry="$i" \
			|| tags_entry="$tags_entry,$i"
	done

	local tags_sorted=($(printf '%s\n' "${tags_a[@]}" | sort | uniq))
	local tags_entry=
	local IFS=$'\n'
	for i in $tags_sorted
	do
		[[ -z $tags_entry ]] \
			&& tags_entry="$i" \
			|| tags_entry="$tags_entry,$i"
	done

	[[ -n $tags_entry ]] \
		&& entry="$filename	$tags_entry" \
		|| entry="$filename"
	echo "$entry" >> $edbfile
	cat "$edbfile" | sort > "$edbfiletemp"
	mv "$edbfiletemp" "$edbfile"
}

function editdbdelete {
	! [[ -f $edbfile ]] && return 1
	local filename="$fn"
	[[ -n $1 ]] && filename="$1"
	local n=1
	local found=0
	local IFS=$'\n'
	while read -r line
	do
		local f="${line/$'\t'*/}"
		[[ $f == $filename ]] \
			&& found=1 \
			&& break
		n="$((n + 1))"
	done < "$edbfile"

	[[ $found -eq 1 ]] && e "${n}d\nw" "$edbfile" > /dev/null
}

function editdbmove {
	! [[ -f $edbfile ]] && return 1
	local filename="$fn"
	[[ -n $1 ]] && filename="$1"
	local n=1
	local found=0
	local IFS=$'\n'
	while read -r line
	do
		local f="${line/$'\t'*/}"
		[[ $f == $filename ]] \
			&& local tags="${line/*$'\t'/}" \
			&& found=1 \
			&& break
		n="$((n + 1))"
	done < "$edbfile"

	[[ $tags == $filename ]] && tags=
	[[ $found -eq 1 ]] && e "${n}d\nw" "$edbfile" > /dev/null
	local entry="$2/$(basename "$filename")	$tags"
	[[ -z $tags ]] && entry="$2/$(basename "$filename")"
	echo "$entry" >> "$edbfile"
	cat "$edbfile" | sort > "$edbfiletemp"
	mv "$edbfiletemp" "$edbfile"
}

function editdbinserttag {
	! [[ -f $edbfile ]] && return 1
	local filename="$fn"
	[[ -n $1 ]] && filename="$1"
	local IFS=$'\n'
	local n=1
	local found=0
	while read -r line
	do
		local f="${line/$'\t'*/}"
		[[ $filename == $f ]] \
			&& local tags="${line/*$'\t'/}" \
			&& found=1 \
			&& break
		n="$((n + 1))"
	done < "$edbfile"

	[[ $tags == $filename ]] && tags=
	[[ $found -eq 1 ]] && e "${n}d\nw" "$edbfile" > /dev/null
	local tags_a=()
	local IFS=$','
	for i in $tags
	do
		tags_a+=("$i")
	done

	for i in $2
	do
		tags_a+=("$i")
	done

	local filedir="$(dirname "$filename")"
	while read -r line
	do
		local f="${line/$'\t'*/}"
		[[ $f == $filedir ]] \
			&& local dirtags="${line/*$'\t'/}" \
			&& break
	done < "$edbfile"

	for i in $dirtags
	do
		tags_a+=("$i")
	done

	local tags_sorted=($(printf '%s\n' "${tags_a[@]}" | sort | uniq))
	local tags_entry=
	local IFS=$'\n'
	for i in $tags_sorted
	do
		[[ -z $tags_entry ]] \
			&& tags_entry="$i" \
			|| tags_entry="$tags_entry,$i"
	done

	local entry="$filename	$tags_entry"
	echo "$entry" >> "$edbfile"
	cat "$edbfile" | sort > "$edbfiletemp"
	mv "$edbfiletemp" "$edbfile"
}

function editdbdeletetag {
	! [[ -f $edbfile ]] && return 1
	local filename="$fn"
	[[ -n $1 ]] && filename="$1"
	local n=1
	local IFS=$'\n'
	while read -r line
	do
		local f="${line/$'\t'*/}"
		[[ $f == $filename ]] \
			&& local tags="${line/*$'\t'/}" \
			&& break
		n="$((n + 1))"
	done < "$edbfile"

	[[ -z $tags ]] && return 2
	e "${n}d\nw" "$edbfile" > /dev/null
	local tags_r=()
	local tags_a=()
	local IFS=$','
	for i in $2
	do
		tags_r+=("$i")
	done

	for i in $tags
	do
		tags_a+=("$i")
	done

	local tags_n=()
	for ((i=0; i < ${#tags_a[@]}; ++i))
	do
		local match=0
		for ((j=0; j < ${#tags_r[@]}; ++j))
		do
			[[ ${tags_r[$j]} == ${tags_a[$i]} ]] \
				&& match=1 \
				&& break
		done

		[[ $match -eq 0 ]] && tags_n+=("${tags_a[$i]}")
	done

	local tags_sorted=($(printf '%s\n' "${tags_n[@]}" | sort))
	local tags_entry=
	local IFS=$'\n'
	for i in $tags_sorted
	do
		[[ -z $tags_entry ]] \
			&& tags_entry="$i" \
			|| tags_entry="$tags_entry,$i"
	done

	local entry="$filename	$tags_entry"
	echo "$entry" >> $edbfile
	cat "$edbfile" | sort > "$edbfiletemp"
	mv "$edbfiletemp" "$edbfile"
}

function editdbmovetag {
	! [[ -f $edbfile ]] && return 1
	local filename="$fn"
	[[ -n $1 ]] && filename="$1"
	local n=1
	local IFS=$'\n'
	while read -r line
	do
		local f="${line/$'\t'*/}"
		[[ $f == $filename ]] \
			&& local tags="${line/*$'\t'/}" \
			&& break
		n="$((n + 1))"
	done < "$edbfile"

	[[ -z $tags ]] && return 2
	e "${n}d\nw" "$edbfile" > /dev/null
	local tags_r=()
	local tags_a=()
	local IFS=$','
	for i in $2
	do
		tags_r+=("$i")
	done

	for i in $3
	do
		tags_a+=("$i")
	done

	for i in $tags
	do
		tags_a+=("$i")
	done

	local tags_n=()
	for ((i=0; i < ${#tags_a[@]}; ++i))
	do
		local match=0
		for ((j=0; j < ${#tags_r[@]}; ++j))
		do
			[[ ${tags_r[$j]} == ${tags_a[$i]} ]] \
				&& match=1 \
				&& break
		done

		[[ $match -eq 0 ]] && tags_n+=("${tags_a[$i]}")
	done

	local tags_sorted=($(printf '%s\n' "${tags_n[@]}" | sort))
	local tags_entry=
	local IFS=$'\n'
	for i in $tags_sorted
	do
		[[ -z $tags_entry ]] \
			&& tags_entry="$i" \
			|| tags_entry="$tags_entry,$i"
	done

	local entry="$filename	$tags_entry"
	echo "$entry" >> $edbfile
	cat "$edbfile" | sort > "$edbfiletemp"
	mv "$edbfiletemp" "$edbfile"
}

function editdbsearch {
	[[ -z $1 ]] && return 1
	local tags_s=()
	local IFS=$','
	for i in $1
	do
		tags_s+=("$i")
	done

	local files=()
	local IFS=$'\n'
	while read -r line
	do
		local tags="${line/*$'\t'/}"
		local tags_a=()
		local IFS=$','
		for i in $tags
		do
			tags_a+=("$i")
		done

		local found_a=()
		for ((i=0; i < ${#tags_s[@]}; ++i))
		do
			local found=0
			local t="${tags_s[$i]}"
			[[ $t =~ ^- ]] \
				&& t="$t/-/}" \
				&& found=1
			local t="${tags_s[$i]/-/}"
			for ((j=0; j < ${#tags_a[@]}; ++j))
			do
				if [[ ${tags_a[$j]} == $t ]]
				then
					[[ $found -eq 0 ]] \
						&& found=1 \
						|| found=0
					break
				fi
			done
				
			found_a+=("$found")
		done
		! [[ ${found_a[@]} =~ 0 ]] \
			&& local f="${line/$'\t'*/}" \
			&& files+=("$f")
	done < "$edbfile"

	for i in ${files[@]}
	do
		echo "$i"
	done
}

function editdbaction {
	[[ -z $2 ]] && return 1
	local files="$(editdbsearch "$2")"
	[[ -z $files ]] && return 2
	for i in $files
	do
		if [[ $1 == delete ]] || [[ $1 == d ]]
		then
			editdbdelete "$i"
			[[ -f $i ]] && rm "$i"
		elif [[ $1 == move ]] || [[ $1 == m ]]
		then
			[[ -z $3 ]] && return 3
			editdbmove "$i" "$3"
			[[ -f $i ]] && mv "$i" "$3"
		elif [[ $1 == command ]] || [[ $1 == c ]]
		then
			if [[ -f $i ]] || [[ -d $i ]]
			then
				local cmd="${3/\%file%/\"$i\"}"
				eval $cmd
			fi
		fi
	done
}

function editdbquery {
	[[ -z $1 ]] && return 1
	[[ -z $2 ]] && return 2
	local files_a=()
	while read -r line
	do
		local f="${line/$'\t'*/}"
		if [[ $1 == tags ]]
		then
			[[ $f == $2 ]] \
				&& local tags="${line/*$'\t'/}" \
				&& break
		elif [[ $1 == files ]]
		then
			[[ $f =~ $2 ]] \
				&& local files+=("$f")
		fi
	done < "$edbfile"

	[[ -n $tags ]] && echo "$tags"
	if [[ -n $files ]]
	then
		for i in ${files[@]}
		do
			echo "$i"
		done
	fi
}

function editdbclean {
	local n=1
	while read -r line
	do
		local f="${line/$'\t'*/}"
		if ! [[ -f $f ]] && ! [[ -d $f ]]
		then
			e "${n}d\nw"
		fi

		n="$((n + 1))"
	done < "$edbfile"
}

function editdbgeneratecache {
	[[ -f $eddbfilescache ]] && rm "$edbfilescache"
	[[ -f $eddbtagscache ]] && rm "$edbtagscache"
	while read -r line
	do
		local f="${line/$'\t'*/}"
		local t="${line/*$'\t'/}"
		echo "$f" >> "$edbfilescache"
		echo "$t" >> "$edbtagscache"
	done < "$edbfile"
}

function edb { editdbsearch "$@"; }
function edba { editdbaction "$@"; }
function edbc { editdbclean "$@"; }
function edbdt { editdbdeletetag "$@"; }
function edbd { editdbdelete "$@"; }
function edbg { editdbgeneratecache "$@"; }
function edbit { editdbinserttag "$@"; }
function edbi { editdbinsert "$@"; }
function edbm { editdbmove "$@"; }
function edbmt { editdbmovetag "$@"; }
function edbq { editdbquery "$@"; }

function _editdbaction {
	local cur=${COMP_WORDS[COMP_CWORD]}
	case "$COMP_CWORD" in
		1)
			COMPREPLY=($(compgen -o bashdefault -W "delete d move \
				m command c" -- $cur))
			;;
		2)
			local entries="$(cat "$edbfilescache")"
			COMPREPLY=($(compgen -o bashdefault -W "$entries" -- $cur))
			;;
		*)
			COMPREPLY=($(compgen -o default -- $cur))
			;;
	esac
}

complete -F _editdbaction editdbaction
complete -F _editdbaction edba

function _editdbdelete {
	local cur=${COMP_WORDS[COMP_CWORD]}
	case "$COMP_CWORD" in
		1)
			local entries="$(cat "$edbfilescache")"
			COMPREPLY=($(compgen -o bashdefault -W "$entries" -- $cur))
			;;
		*)
			COMPREPLY=($(compgen -o default -- $cur))
			;;
	esac
}

complete -F _editdbdelete editdbdelete
complete -F _editdbdelete edbd

function _editdbinserttag {
	local cur=${COMP_WORDS[COMP_CWORD]}
	case "$COMP_CWORD" in
		1)
			local entries="$(cat "$edbfilescache")"
			COMPREPLY=($(compgen -o bashdefault -W "$entries" -- $cur))
			;;
		*)
			local entries="$(cat "$edbtagscache")"
			COMPREPLY=($(compgen -o bashdefault -W "$entries" -- $cur))
			;;
	esac
}

complete -F _editdbinserttag editdbdeletetag
complete -F _editdbinserttag edbdt
complete -F _editdbinserttag editdbinserttag
complete -F _editdbinserttag edbit

function _editdbinsert {
	local cur=${COMP_WORDS[COMP_CWORD]}
	case "$COMP_CWORD" in
		1)
			COMPREPLY=($(compgen -o default -- $cur))
			;;
		*)
			local entries="$(cat "$edbtagscache")"
			COMPREPLY=($(compgen -o bashdefault -W "$entries" -- $cur))
			;;
	esac
}

complete -F _editdbinsert editdbinsert
complete -F _editdbinsert edbi

function _editdbmove {
	local cur=${COMP_WORDS[COMP_CWORD]}
	case "$COMP_CWORD" in
		1)
			local entries="$(cat "$edbfilescache")"
			COMPREPLY=($(compgen -o bashdefault -W "$entries" -- $cur))
			;;
		2)
			local entries="$(cat "$edbfilescache")"
			COMPREPLY=($(compgen -o bashdefault -W "$entries" -- $cur))
			;;
		*)
			COMPREPLY=($(compgen -o default -- $cur))
			;;
	esac
}

function _editdbmovetag {
	local cur=${COMP_WORDS[COMP_CWORD]}
	case "$COMP_CWORD" in
		1)
			local entries="$(cat "$edbfilescache")"
			COMPREPLY=($(compgen -o bashdefault -W "$entries" -- $cur))
			;;
		*)
			local entries="$(cat "$edbtagscache")"
			COMPREPLY=($(compgen -o bashdefault -W "$entries" -- $cur))
			;;
	esac
}

complete -F _editdbmovetag editdbmovetag
complete -F _editdbmovetag edbmt

function _editdbsearch {
	local cur=${COMP_WORDS[COMP_CWORD]}
	local entries="$(cat "$edbtagscache")"
	COMPREPLY=($(compgen -o bashdefault -W "$entries" -- $cur))
}

complete -F _editdbsearch editdbsearch
complete -F _editdbsearch edb

function _editdbquery {
	local cur=${COMP_WORDS[COMP_CWORD]}
	local prev=${COMP_WORDS[COMP_CWORD-1]}
	case "$COMP_CWORD" in
		1)
			COMPREPLY=($(compgen -o bashdefault -W "files tags" -- $cur))
			;;
		2)
			local entries=
			[[ $prev == files ]] \
				&& entries="$(cat "$edbfilescache")" \
				|| entries="$(cat "$edbtagscache")"
			COMPREPLY=($(compgen -o bashdefault -W "$entries" -- $cur))
			;;
		*)
			COMPREPLY=($(compgen -o bashdefault -- $cur))
			;;
	esac
}

complete -F _editdbquery editdbquery
complete -F _editdbquery edbq
