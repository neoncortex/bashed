#!/usr/bin/env bash

edbfile="$editdir/db/db"
edbfiletemp="$editdir/db/db.temp"
edbfilescache="$editdir/db/dbfiles.cache"
edbtagscache="$editdir/db/dbtags.cache"
edbopencommand="eo"
edbextensions=(org ms tex)

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
	! [[ -f $filename ]] && ! [[ -d $filename ]] && return 2
	[[ -z $2 ]] && return 3
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

	[[ $exist -eq 1 ]] && return 4
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
	[[ -n $1 ]] && local filename="$1" || return 2
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

	[[ $found -eq 1 ]] \
		&& $(e "${n}d\nw" "$edbfile") \
		&& { [[ $2 -eq 1 ]] && rm "$filename"; }
}

function editdbmove {
	! [[ -f $edbfile ]] && return 1
	[[ -n $1 ]] && local filename="$1" || return 2
	[[ -n $2 ]] && local dest="$2" || return 3
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
	local tags_entry="$(editdbassemblemovetags "$filename" "$dest")"
	[[ -n $tags_entry ]] \
		&& entry="$dest/$base	$tags_entry" \
		|| entry="$dest/$base"
	editdbwrite "$entry"
	mv "$filename" "$dest/$base"
}

function editdbrename {
	! [[ -f $edbfile ]] && return 1
	[[ -n $1 ]] && local filename="$1" || return 2
	[[ -n $2 ]] && local dest="$2" || return 3
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
	local dirname="$(dirname "$filename")"
	entry="$dirname/$dest	$tags"
	editdbwrite "$entry"
	mv "$filename" "$dirname/$dest"
}

function editdbinserttag {
	! [[ -f $edbfile ]] && return 1
	[[ -n $1 ]] && filename="$1" || return 2
	! [[ -f $filename ]] && ! [[ -d $filename ]] && return 3
	[[ -z $2 ]] && return 4
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
	[[ -z $2 ]] && return 3
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

	[[ -z $tags ]] && return 4
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
	[[ -z $2 ]] && return 3
	[[ -z $3 ]] && return 4
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

	[[ -z $tags ]] && return 5
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
	! [[ -f $edbfile ]] && return 1
	[[ -z $1 ]] && return 2
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

		local IFS=$'\n'
		local found_a=()
		for ((i=0; i < ${#tags_s[@]}; ++i))
		do
			local found=0
			local t="${tags_s[$i]}"
			[[ $t =~ ^- ]] \
				&& t="${t/-/}" \
				&& found=1
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
	! [[ -f $edbfile ]] && return 1
	[[ -z $1 ]] && return 2
	local IFS=$'\n'
	local files=($(editdbsearch "$1"))
	editcurses 0 "${files[@]}"
	[[ -n $e_uresult ]] && $edbopencommand "${files[$((e_uresult - 1))]}"
}

function editdbsearchcontent {
	! [[ -f $edbfile ]] && return 1
	[[ -z $1 ]] && return 2
	local files=
	[[ -n $2 ]] \
		&& files="$(editdbsearch "$2")" \
		|| files="$(cat "$edbfile" | cut -f1)"
	local searchres=()
	local IFS=$'\n'
	for i in $files
	do
		[[ -f $i ]] && local g="$(grep "$1" "$i")"
		[[ -n $g ]] && searchres+=("$i
$g
")
	done

	local IFS=
	for i in ${searchres[@]}
	do
		echo "$i"
	done
}

function editdbaction {
	! [[ -f $edbfile ]] && return 1
	[[ -z $2 ]] && return 2
	local IFS=$'\n\t '
	local files="$(editdbsearch "$2" 1)"
	[[ -z $files ]] && return 3
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
			[[ -z $3 ]] && return 4
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
			[[ -z $3 ]] && return 5
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
			[[ -z $3 ]] && return 6
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
			[[ -z $3 ]] || [[ -z $4 ]] && return 7
			local IFS=$','
			local tags_a=()
			for j in $3
			do
				local found=0
				for k in $tags
				do
					if [[ $j == $k ]]
					then
						found=1
					else
						tags_a+=("$k")
					fi
				done

				[[ $found -eq 0 ]] && break
			done

			if [[ $found -eq 1 ]]
			then
				for k in $4
				do
					tags_a+=("$k")
				done
			fi

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

	editdbwrite
}

function editdbquery {
	! [[ -f $edbfile ]] && return 1
	[[ -z $1 ]] && return 2
	[[ -z $2 ]] && return 3
	local files_a=()
	local IFS=$'\n\t '
	local rex="$2"
	local tail=
	if [[ $1 == files ]] && [[ $rex =~ ^%.*% ]]
	then
		tail="${rex/*%/}"
		rex="${rex/\%/}"
		rex="${rex/\%*/}"
	fi

	local IFS=$'\n'
	while read -r line
	do
		local f="${line/$'\t'*/}"
		if [[ $1 == tags ]] || [[ $1 == taglist ]]
		then
			[[ $f == $2 ]] \
				&& local tags="${line/*$'\t'/}" \
				&& break
		elif [[ $1 == files ]]
		then
			if [[ $f =~ $rex ]]
			then
				local data="$f"
				[[ -n $tail ]] && data="$f$tail"
				files_a+=("$data")
			fi
		fi
	done < "$edbfile"

	if [[ -n $tags ]]
	then
		if [[ $1 == taglist ]]
		then
			local IFS=$','
			for i in $tags
			do
				echo "$i"
			done
		else
			echo "$tags"
		fi
	fi

	for i in ${files_a[@]}
	do
		[[ -d $i ]] \
			&& echo "$i/" \
			|| echo "$i"
	done
}

function editdbquerycurses {
	! [[ -f $edbfile ]] && return 1
	[[ -z $1 ]] && return 2
	[[ -z $2 ]] && return 3
	local IFS=$'\n'
	local files=($(editdbquery "$1" "$2"))
	editcurses 0 "${files[@]}"
	local file="${files[$((e_uresult - 1))]}"
	if [[ -n $e_uresult ]]
	then
		[[ -d $file ]] \
			&& cd "$file" \
			|| $edbopencommand "$file"
	fi
}

function editdbclean {
	! [[ -f $edbfile ]] && return 1
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

function editdbscan {
	! [[ -f $edbfile ]] && return 1
	[[ -n $1 ]] && local path="$1" || return 2
	! [[ -d $path ]] && return 3
	local IFS=
	local dirname="$(basename "$path")"
	editdbinsert "$path" "$dirname"
	if [[ -f $path/.bashed ]]
	then
		local dirtags=""
		while read -r line
		do
			if [[ $line =~ ^\#\+db: ]]
			then
				local t="${line/\#\+db:\ /}"
				t="${line/\#\+db:/}"
				local IFS=$','
				for i in $t
				do
					[[ -z $dirtags ]] \
						&& dirtags="$i" \
						|| dirtags="$dirtags,$i"
				done

				local IFS=
			fi
		done < "$path/.bashed"

		[[ ${#dirtags} -gt 0 ]] && edbit "$path" "$dirtags"
	fi

	for i in $path/*
	do
		if [[ -f $i ]]
		then
			local ext
			for j in $edbextensions
			do
				[[ $i =~ \.${j}$ ]] && ext="$j"
			done

			[[ -z $ext ]] && continue
			editdbinsert "$i" "$j"
		elif [[ -d $i ]]
		then
			editdbscan "$i"
		fi
	done
}

function editdbgeneratecache {
	! [[ -f $edbfile ]] && return 1
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
function edbqu { editdbquerycurses "$@"; }
function edbr { editdbrename "$@"; }
function edbsc { editdbsearchcontent "$@"; }
function edbs { editdbscan "$@"; }

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
		2)
			COMPREPLY=($(compgen -o bashdefault -W "1" --$cur))
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

complete -F _editdbmove editdbmove
complete -F _editdbmove edbm
complete -F _editdbmove editdbrename
complete -F _editdbmove edbr

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

function _editdbsearchcontent {
	local cur=${COMP_WORDS[COMP_CWORD]}
	local entries="$(cat "$edbtagscache")"
	case "$COMP_CWORD" in
		2)
			COMPREPLY=($(compgen -o bashdefault -W "$entries" -- $cur))
			;;
		*)
			COMPREPLY=($(compgen -o default -- $cur))
			;;
	esac
}

complete -F _editdbsearchcontent editdbsearchcontent
complete -F _editdbsearchcontent edbsc

function _editdbsearch {
	local cur=${COMP_WORDS[COMP_CWORD]}
	local entries="$(cat "$edbtagscache")"
	COMPREPLY=($(compgen -o bashdefault -W "$entries" -- $cur))
}

complete -F _editdbsearch editdbsearch
complete -F _editdbsearch edb
complete -F _editdbsearch edbu

function _editdbquery {
	local cur=${COMP_WORDS[COMP_CWORD]}
	local prev=${COMP_WORDS[COMP_CWORD-1]}
	case "$COMP_CWORD" in
		1)
			COMPREPLY=($(compgen -o bashdefault -W \
				"files tags taglist" -- $cur))
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
complete -F _editdbquery edbqu
