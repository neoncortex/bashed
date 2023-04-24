#!/usr/bin/env bash

edbfile="$editdir/db/db"
edbfiletemp="$editdir/db/db.temp"
edbfilescache="$editdir/db/dbfiles.cache"
edbtagscache="$editdir/db/dbtags.cache"
edbopencommand="eo"

function editdbsorttags {
	[[ -z $1 ]] && return 1
	local tags_a=("$@")
	local tags_sorted="$(printf '%s\n' "${tags_a[@]}" | sort | uniq)"
	local tags_entry=
	local IFS=$'\n'
	for i in $tags_sorted
	do
		[[ -z $tags_entry ]] \
			&& tags_entry="$i" \
			|| tags_entry="$tags_entry,$i"
	done

	echo "$tags_entry"
}

function editdbassemblemovetags {
	[[ -z $1 ]] && return 1
	[[ -z $2 ]] && return 2
	local filedir="$(dirname "$1")"
	local dirtags="$(edbq tags "$filedir")"
	local removetags=()
	local IFS=$','
	if [[ -n $dirtags ]]
	then
		for j in $dirtags
		do
			removetags+=("$j")
		done
	fi

	local tags_a=()
	for j in $tags
	do
		local found=0
		for k in "${removetags[@]}"
		do
			[[ $j == $k ]] && found=1 && break
		done

		[[ $found -eq 0 ]] && tags_a+=("$j")
	done

	local newdirtags="$(edbq tags "$2")"
	for j in $newdirtags
	do
		tags_a+=("$j")
	done

	local tags_entry="$(editdbsorttags "${tags_a[@]}")"
	echo "$tags_entry"
}

function editdbwrite {
	[[ -n $1 ]] && echo "$entry" >> "$edbfile"
	cat "$edbfile" | sort > "$edbfiletemp"
	mv "$edbfiletemp" "$edbfile"
}

function editdbinsert {
	! [[ -f $edbfile ]] && touch "$edbfile"
	[[ -n $1 ]] && filename="$1" || return 1
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

	local tags_entry="$(editdbsorttags "${tags_a[@]}")"
	[[ -n $tags_entry ]] \
		&& entry="$filename	$tags_entry" \
		|| entry="$filename"
	editdbwrite "$entry"
}

function editdbdelete {
	! [[ -f $edbfile ]] && return 1
	[[ -n $1 ]] && filename="$1" || return 2
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

	[[ $found -eq 1 ]] && $(e "${n}d\nw" "$edbfile")
}

function editdbmove {
	! [[ -f $edbfile ]] && return 1
	[[ -n $1 ]] && filename="$1" || return 2
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
	[[ $found -eq 1 ]] && $(e "${n}d\nw" "$edbfile")
	local entry=
	local base="$(basename "$filename")"
	local tags_entry="$(editdbassemblemovetags "$filename" "$2")"
	[[ -n $tags_entry ]] \
		&& entry="$2/$base	$tags_entry" \
		|| entry="$2/$base"
	editdbwrite "$entry"
}

function editdbinserttag {
	! [[ -f $edbfile ]] && return 1
	[[ -n $1 ]] && filename="$1" || return 2
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
	[[ $found -eq 1 ]] && $(e "${n}d\nw" "$edbfile")
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

	local tags_entry="$(editdbsorttags "${tags_a[@]}")"
	local entry="$filename	$tags_entry"
	editdbwrite "$entry"
}

function editdbdeletetag {
	! [[ -f $edbfile ]] && return 1
	[[ -n $1 ]] && filename="$1" || return 2
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

	[[ -z $tags ]] && return 3
	$(e "${n}d\nw" "$edbfile")
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

	local tags_entry="$(editdbsorttags "${tags_n[@]}")"
	local entry="$filename	$tags_entry"
	editdbwrite "$entry"
}

function editdbmovetag {
	! [[ -f $edbfile ]] && return 1
	[[ -n $1 ]] && filename="$1" || return 2
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

	[[ -z $tags ]] && return 3
	$(e "${n}d\nw" "$edbfile")
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

	local tags_entry="$(editdbsorttags "${tags_n[@]}")"
	local entry="$filename	$tags_entry"
	editdbwrite "$entry"
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
	local n=1
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
			&& { [[ $2 -eq 1 ]] && files+=("$n") \
				|| files+=("${line/$'\t'*/}"); }
		n="$((n + 1))"
	done < "$edbfile"

	for i in ${files[@]}
	do
		[[ -d $i ]] \
			&& echo "$i/" \
			|| echo "$i"
	done
}

function editdbsearchcurses {
	[[ -z $1 ]] && return 1
	local files="$(editdbsearch "$1")"
	[[ -z $files ]] && return 2
	local files_a=()
	local IFS=$'\n\t '
	for i in $files
	do
		files_a+=("$i")
	done

	local rows=
	local cols=
	read -r rows cols < <(stty size)
	local dialog="dialog --colors --menu 'Select:' "
	local n=1
	dialog="$dialog $((rows - 1)) $((cols - 4)) $cols "
	for i in $files
	do
		dialog="$dialog $n "$i""
		n="$((n + 1))"
	done

	exec 3>&1
	echo "$dialog"
	local res="$($dialog 2>&1 1>&3)"
	exec 3>&-
	clear
	[[ -n $res ]] && $edbopencommand "${files_a[$((res - 1))]}"
}

function editdbaction {
	[[ -z $2 ]] && return 1
	local IFS=$'\n\t '
	local files="$(editdbsearch "$2" 1)"
	[[ -z $files ]] && return 2
	local lines=()
	local remove=()
	for i in $files
	do
		lines+=("$(e ${i}p "$edbfile")")
		remove+=("$i")
	done

	for ((i=0; i < "${#lines[@]}"; ++i))
	do
		local line="${lines[$i]}"
		local filename="${line/$'\t'*/}"
		local tags="${line/*$'\t'/}"
		if [[ $1 == delete ]] || [[ $1 == d ]]
		then
			lines[$i]=""
			[[ -f $filename ]] && rm "$filename"
		elif [[ $1 == move ]] || [[ $1 == m ]]
		then
			[[ -z $3 ]] && return 3
			local base="$(basename "$filename")"
			[[ $last_dirname != $(dirname "$filename") ]] \
				&& local tags_entry="$(editdbassemblemovetags \
					"$filename" "$3")"
			[[ -n $tags_entry ]] \
				&& lines[$i]="$3/$base	$tags_entry" \
				|| lines[$i]="$3/$base"
			local last_dirname="$(dirname "$filename")"
			[[ -f $i ]] && mv "$filename" "$3"
		elif [[ $1 == command ]] || [[ $1 == c ]]
		then
			if [[ -f $filename ]] || [[ -d $filename ]]
			then
				local cmd="${3/\%file%/\"$filename\"}"
				eval $cmd
			fi
		elif [[ $1 == inserttags ]] || [[ $1 == it ]]
		then
			[[ -z $3 ]] && return 3
			tags="$tags,$3"
			local tags_a=()
			local IFS=$','
			for j in $tags
			do
				tags_a+=("$j")
			done

			local IFS=$'\n\t '
			local tags_entry="$(editdbsorttags "${tags_a[@]}")"
			[[ -n $tags_entry ]] \
				&& lines[$i]="$filename	$tags_entry" \
				|| lines[$i]="$filename"
		elif [[ $1 == deletetags ]] || [[ $1 == dt ]]
		then
			[[ -z $3 ]] && return 3
			local tags_a=()
			local IFS=$','
			for j in $tags
			do
				local found=0
				for k in $3
				do
					echo "< $j"
					echo "> $k"
					[[ $j == $k ]] && found=1 && break
				done

				[[ $found -eq 0 ]] && tags_a+=("$j")
			done

			local IFS=$'\n\t '
			local tags_entry="$(editdbsorttags "${tags_a[@]}")"
			[[ -n $tags_entry ]] \
				&& lines[$i]="$filename	$tags_entry" \
				|| lines[$i]="$filename"
		elif [[ $1 == movetags ]] || [[ $1 == mt ]]
		then
			[[ -z $3 ]] || [[ -z $4 ]] && return 3
			tags="$tags,$4"
			local tags_a=()
			local IFS=$','
			for j in $tags
			do
				local found=0
				for k in $3
				do
					[[ $j == $k ]] && found=1 && break
				done

				[[ $found -eq 0 ]] && tags_a+=("$j")
			done

			local IFS=$'\n\t '
			local tags_entry="$(editdbsorttags "${tags_a[@]}")"
			[[ -n $tags_entry ]] \
				&& lines[$i]="$filename	$tags_entry" \
				|| lines[$i]="$filename"
		fi
	done

	for ((i=$((${#remove[@]} - 1)); i >= 0; --i))
	do
		local res="$(e "${remove[$i]}d\nw" "$edbfile")"
		[[ -n $res ]] && echo "$res"
	done

	for i in "${lines[@]}"
	do
		echo "$i" >> "$edbfile"
	done

	edbfilewrite
}

function editdbquery {
	[[ -z $1 ]] && return 1
	[[ -z $2 ]] && return 2
	local files_a=()
	local IFS=$'\n\t '
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
			[[ -d $i ]] \
				&& echo "$i/" \
				|| echo "$i"
		done
	fi
}

function editdbclean {
	local n=1
	local IFS=$'\n\t '
	while read -r line
	do
		local f="${line/$'\t'*/}"
		if ! [[ -f $f ]] && ! [[ -d $f ]]
		then
			$(e "${n}d\nw")
		fi

		n="$((n + 1))"
	done < "$edbfile"
}

function editdbgeneratecache {
	[[ -f $edbfilescache ]] && rm "$edbfilescache"
	[[ -f $edbtagscache ]] && rm "$edbtagscache"
	local IFS=$','
	while read -r line
	do
		local f="${line/$'\t'*/}"
		local t="${line/*$'\t'/}"
		echo "$f" >> "$edbfilescache"
		for i in $t
		do
			echo "$i" >> "$edbtagscache"
		done
	done < "$edbfile"

	cat "$edbtagscache" | sort | uniq > "$editdir/db/.tags"
	mv "$editdir/db/.tags" "$edbtagscache"
}

function edb { editdbsearch "$@"; }
function edba { editdbaction "$@"; }
function edbc { editdbclean "$@"; }
function edbu { editdbsearchcurses "$@"; }
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
				m command c inserttags it movetags  mt \
				deletetags dt" -- $cur))
			;;
		2)
			local prev=${COMP_WORDS[COMP_CWORD-1]}
			if [[ $prev == command ]] || [[ $prev == "c" ]]
			then
				COMPREPLY=($(compgen -o default -- $cur))
			else
				local entries="$(cat "$edbtagscache")"
				COMPREPLY=($(compgen -o bashdefault -W "$entries" -- $cur))
			fi
			;;

		3)
			local entries="$(cat "$edbtagscache")"
			COMPREPLY=($(compgen -o bashdefault -W "$entries" -- $cur))
			;;
		4)
			local entries="$(cat "$edbtagscache")"
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
