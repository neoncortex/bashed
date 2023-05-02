#!/usr/bin/env bash

editsessiondir="$editdir/session"
editsessioncmd="n"
editsessionsyntax=1
editsessionimg=1
editsessionesc=1
editsessionesch=0
editsessioninclude=1
editsessionhidden=1
editsessionblock=1
editsessiontables=1
editsessiontable_ascii=0

function editsessionopen {
	[[ -z $1 ]] && return 1
	local filename="$1"
	local argument=
	if [[ $filename =~ .*:.* ]]
	then
		filename="${filename/:*/}"
		argument="${filename/*:/}"
	fi

	[[ -n $2 ]] && argument="$2"
	[[ $filename =~ ^%.*% ]] && filename="$(edbq files "$filename")"
	! [[ -d $editsessiondir ]] && mkdir -p "$editsessiondir"
	! [[ $filename =~ ^\/ ]] && filename="$PWD/$filename"
	local file="$editsessiondir/${filename//\//___}"
	edcmd="$editsessioncmd"
	edsyntax="$editsessionsyntax"
	edimg="$editsessionimg"
	edesc="$editsessionesc"
	edesch="$editsessionesch"
	edinclude="$editsessioninclude"
	edhidden="$editsessionhidden"
	edblock="$editsessionblock"
	edtables="$editsessiontables"
	edtable_ascii="$editsessiontable_ascii"
	editopen "$filename" > /dev/null
	[[ -n $argument ]] && editarg "$argument" > /dev/null
	printf "\033]2;$filename\a"
	if [[ -f $file ]]
	then
		if [[ -n $argument ]]
		then
			editsessionwrite "$filename"
		fi

		source "$file"
		editshow "$fl"
	else
		editsessionwrite "$filename"
	fi
}

function editsessionclose {
	[[ -z $fn ]] && return 1
	[[ -n $editsessiondir/${fn//\//___} ]] && rm "$editsessiondir/${fn//\//___}"
	editclose
	printf "\033]2;bash\a"
}

function editsessionwrite {
	[[ -z $fn ]] && return 1
	local file="$1"
	[[ -z $1 ]] && file="$fn"
	local file="$editsessiondir/${file//\//___}"
	echo "fl=$fl" > "$file"
	echo "edcmd=$edcmd" >> "$file"
	echo "edimg=$edimg" >> "$file"
	echo "edesc=$edesc" >> "$file"
	echo "edesch=$edesch" >> "$file"
	echo "edinclude=$edinclude" >> "$file"
	echo "edhidden=$edhidden" >> "$file"
	echo "edblock=$edblock" >> "$file"
	echo "diffarg=\"$diffarg\"" >> "$file"
	echo "edtables=$edtables" >> "$file"
	echo "edtable_ascii=$edtable_ascii" >> "$file"
}

function editsessionedit {
	[[ -z $1 ]] && return 1
	local IFS=$' \n\t'
	local n=1
	for i in $editsessiondir/*
	do
		[[ $n -eq $1 ]] && eo "$i" && break
		n="$((n + 1))"
	done
}

function editsessioncurses {
	local IFS=$'\n'
	local files="$*"
	[[ -z $files ]] && return 2
	local files_a=()
	for i in $files
	do
		local filename="${i//___/\/}"
		filename="${filename/$editsessiondir/}"
		filename="${filename//\/\//\/}"
		files_a+=("$filename")
	done

	local IFS=$'\n\t '
	local rows=
	local cols=
	read -r rows cols < <(stty size)
	local dialog="dialog --colors --menu 'Select:' "
	local n=1
	dialog="$dialog $((rows - 1)) $((cols - 4)) $cols "
	for i in "${files_a[@]}"
	do
		dialog="$dialog $n "$i""
		n="$((n + 1))"
	done

	exec 3>&1
	local res="$($dialog 2>&1 1>&3)"
	exec 3>&-
	clear
	[[ -n $res ]] && edsession_uresult="$res"
}

function editsessioneditcurses {
	local IFS=$'\n\t '
	local files=()
	shopt -s dotglob
	for i in $editsessiondir/*
	do
		files+=("$i")
	done

	shopt -u dotglob
	[[ ${#files[@]} -gt 0 ]] && editsessioncurses "${files[@]}"
	[[ -n $edsession_uresult ]] \
		&& eo "${files[$((edsession_uresult - 1))]}" \
		&& edsession_uresult=
}

function editsession {
	[[ -z $1 ]] && return 1
	local IFS=$' \n\t'
	local files=()
	shopt -s dotglob
	for i in $editsessiondir/*
	do
		files+=("$i")
	done

	shopt -u dotglob
	[[ -z ${files[@]} ]] && return 2
	if [[ $1 =~ [0-9]+ ]]
	then
		local session="${files[$(($1 - 1))]}"
		local filename="${session//___/\/}"
		filename="${filename/$editsessiondir/}"
		filename="${filename/\/\//\/}"
		editsessionopen "$filename" "$2"
	elif [[ $1 == list ]] || [[ $1 == l ]]
	then
		local n=1
		for i in ${files[@]}
		do
			if [[ -n $i ]]
			then
				local filename="${i//___/\/}"
				filename="${filename/$editsessiondir/}"
				filename="${filename//\/\//\/}"
				echo "$n - $filename"
				n="$((n + 1))"
			fi
		done
	elif [[ $1 == listcurses ]] || [[ $1 == lu ]]
	then
		[[ ${#files[@]} -gt 0 ]] && editsessioncurses "${files[@]}"
		if [[ -n $edsession_uresult ]]
		then
			local filename="${files[$((edsession_uresult - 1))]}"
			filename="${filename//___/\/}"
			filename="${filename/$editsessiondir/}"
			filename="${filename//\/\//\/}"
			eso "$filename"
			edsession_uresult=
		fi
	elif [[ $1 == delete ]] || [[ $1 == d ]]
	then
		[[ -z $2 ]] && return 3
		local filename="${files[$(($2 - 1))]}"
		filename="${filename//\/\//\/}"
		[[ -n $filename ]] && rm "$filename"
	elif [[ $1 == deletecurses ]] || [[ $1 == du ]]
	then
		[[ ${#files[@]} -gt 0 ]] && editsessioncurses "${files[@]}"
		if [[ -n $edsession_uresult ]]
		then
			local f="${files[$((edsession_uresult - 1))]}"
			f="${f//\/\//\/}"
			[[ -n $f ]] && rm "$f"
			edsession_uresult=
		fi
	fi
}

function eso { editsessionopen "$@"; }
function esq { editsessionclose "$@"; }
function ese { editsession "$@"; }
function esee { editsessionedit "$@"; }
function eseeu { editsessioneditcurses "$@"; }
function esw { editsessionwrite "$@"; }

function _editsessioncompletion {
	local files=()
	shopt -s dotglob
	local n=1
	for i in $editsessiondir/*
	do
		files+=("$n")
		n="$((n + 1))"
	done

	shopt -u dotglob
	echo "${files[@]}"
}

function _editsession {
	local cur=${COMP_WORDS[COMP_CWORD]}
	local files=("$(_editsessioncompletion)")
	local numbers="${files[@]}"
	case "$COMP_CWORD" in
		1)
			COMPREPLY=($(compgen -o bashdefault \
				-W "delete d list l listcurses lu deletecurses \
				du $numbers" -- $cur))
			;;
		2)
			COMPREPLY=($(compgen -o bashdefault -W "$numbers" -- $cur))
			;;
		*)
			COMPREPLY=($(compgen -o bashdefault -- $cur))
			;;
	esac
}

complete -F _editsession editsession
complete -F _editsession ese

function _editsessionedit {
	local cur=${COMP_WORDS[COMP_CWORD]}
	local files=("$(_editsessioncompletion)")
	local numbers="${files[@]}"
	COMPREPLY=($(compgen -o bashdefault -W "$numbers" -- $cur))
}

complete -F _editsessionedit editsessionedit
complete -F _editsessionedit esee
