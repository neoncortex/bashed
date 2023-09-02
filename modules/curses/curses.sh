#!/usr/bin/env bash

function _editcurses {
	local IFS=$'\n'
	local multiple="$1"
	shift
	local files="$*"
	local files_a=()
	for i in $files
	do
		files_a+=("$i")
	done

	[[ ${#files_a[@]} -eq 0 ]] && return
	local rows=
	local cols=
	local IFS=$'\n\t '
	read -r rows cols < <(stty size)
	local dialog="dialog --colors --menu 'Select:' "
	[[ $multiple -eq 1 ]] \
		&& dialog="dialog --colors --checklist 'Select:' "
	local items=()
	local n=1
	dialog="$dialog $((rows - 1)) $((cols - 4)) $cols "
	for i in "${files_a[@]}"
	do
		[[ $multiple -eq 1 ]] \
			&& items+=("$n" "$i" "off") \
			|| items+=("$n" "$i")
		n="$((n + 1))"
	done

	[[ ${#items[@]} -eq 0 ]] && return
	exec 3>&1
	local res="$($dialog "${items[@]}" 2>&1 1>&3)"
	exec 3>&-
	clear
	if [[ $multiple -eq 1 ]]
	then
		e_uresult=()
		if [[ -n $res ]]
		then
			for i in $res
			do
				e_uresult+=("$i")
			done
		fi
	else
		[[ -n $res ]] && e_uresult="$res"
	fi
}

