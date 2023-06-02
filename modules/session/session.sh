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

function editsession_encodepaths {
	local IFS=$'\n'
	local files="$*"
	[[ -z $files ]] && return 2
	for i in $files
	do
		local filename="${i//___/\/}"
		filename="${filename/$editsessiondir/}"
		filename="${filename//\/\//\/}"
		echo "$filename"
	done
}

function editsessioneditcurses {
	local IFS=$'\n'
	local files=()
	shopt -s dotglob
	for i in $editsessiondir/*
	do
		files+=("$i")
	done

	shopt -u dotglob
	[[ ${#files[@]} -gt 0 ]] && editsessioncurses "${files[@]}"
	[[ ${#files[@]} -gt 0 ]] \
		&& editcurses 0 "$(editsession_encodepaths ${files[@]})"
	[[ -n $e_uresult ]] \
		&& eo "${files[$((e_uresult - 1))]}" \
		&& e_uresult=
}

function editsession {
	[[ -z $1 ]] && return 1
	local files=()
	shopt -s dotglob
	local IFS=
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
		[[ -d $filename ]] \
			&& cd "$filename" \
			|| editsessionopen "$filename" "$2"
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
		[[ ${#files[@]} -gt 0 ]] \
			&& editcurses 0 "$(editsession_encodepaths ${files[@]})"
		if [[ -n $e_uresult ]]
		then
			local filename="${files[$((e_uresult - 1))]}"
			filename="${filename//___/\/}"
			filename="${filename/$editsessiondir/}"
			filename="${filename//\/\//\/}"
			[[ -d $filename ]] \
				&& cd "$filename" \
				|| eso "$filename"
			e_uresult=
		fi
	elif [[ $1 == delete ]] || [[ $1 == d ]]
	then
		[[ -z $2 ]] && return 3
		local filename="${files[$(($2 - 1))]}"
		filename="${filename//\/\//\/}"
		[[ -n $filename ]] && rm "$filename"
	elif [[ $1 == deletecurses ]] || [[ $1 == du ]]
	then
		[[ ${#files[@]} -gt 0 ]] \
			&& editcurses 1 "$(editsession_encodepaths ${files[@]})"
		if [[ ${#e_uresult[@]} -gt 0 ]]
		then
			for i in ${e_uresult[@]}
			do
				local f="${files[$((i - 1))]}"
				f="${f//\/\//\/}"
				[[ -n $f ]] && rm "$f"
			done

			e_uresult=
		fi
	elif [[ $1 == search ]] || [[ $1 == s ]]
	then
		[[ -z $2 ]] && return 4
		local searchres=()
		for ((i=0; i < ${#files[@]}; ++i))
		do
			[[ ${files[$i]} =~ $2 ]] \
				&& searchres+=("$((i + 1)) - ${files[$i]}")
		done

		for i in ${searchres[@]}
		do
			local filename="${i//___/\/}"
			filename="${filename/$editsessiondir/}"
			filename="${filename//\/\//\/}"
			echo "$filename"
		done
	elif [[ $1 == searchcontent ]] || [[ $1 == sc ]]
	then
		[[ -z $2 ]] && return 5
		local searchres=()
		for ((i=0; i < ${#files[@]}; ++i))
		do
			local filename="${files[$i]}"
			filename="${filename//___/\/}"
			filename="${filename/$editsessiondir/}"
			filename="${filename//\/\//\/}"
			local g="$(grep "$2" "$filename")"
			[[ -n $g ]] \
				&& searchres+=("$((i + 1)) - $filename
$g
")
		done

		for i in ${searchres[@]}
		do
			echo "$i"
		done
	elif [[ $1 == searchsessioncontent ]] || [[ $1 == ssc ]]
	then
		[[ -z $2 ]] && return 6
		local searchres=()
		for ((i=0; i < ${#files[@]}; ++i))
		do
			local g="$(grep "$2" "${files[$i]}")"
			[[ -n $g ]] \
				&& searchres+=("$((i + 1)) - ${files[$i]}
$g
")
		done

		for i in ${searchres[@]}
		do
			filename="${i//___/\/}"
			filename="${filename/$editsessiondir/}"
			filename="${filename//\/\//\/}"
			echo "$filename"
		done
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
				du search s searchcontent sc searchsessioncontent \
				ssc $numbers" -- $cur))
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
