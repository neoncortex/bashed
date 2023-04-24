#!/usr/bin/env bash

editsessiondir="$editdir/session"

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
	! [[ -d $editsessiondir ]] && mkdir -p "$editsessiondir"
	! [[ $filename =~ ^\/ ]] && filename="$PWD/$filename"
	local file="$editsessiondir/${filename//\//___}"
	editopen "$filename" > /dev/null
	[[ -n $argument ]] && editarg "$argument" > /dev/null
	printf "\033]2;$filename\a"
	if [[ -f $file ]]
	then
		if [[ -n $argument ]]
		then
			echo "fl=$fl" > "$file"
			echo "edcmd=$edcmd" >> "$file"
			echo "edimg=$edimg" >> "$file"
			echo "edesc=$edesc" >> "$file"
			echo "edesch=$edesch" >> "$file"
			echo "edinclude=$edinclude" >> "$file"
			echo "edhidden=$edhidden" >> "$file"
			echo "edblock=$edblock" >> "$file"
			echo "diffarg=$diffarg" >> "$file"
			echo "edtables=$edtables" >> "$file"
			echo "edtable_ascii=$edtable_ascii" >> "$file"
		fi

		source "$file"
		editshow "$fl"
	else
		echo "fl=$fl" > "$file"
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
	local file="$editsessiondir/${fn//\//___}"
	echo "fl=$fl" > "$file"
	echo "edcmd=$edcmd" >> "$file"
	echo "edimg=$edimg" >> "$file"
	echo "edesc=$edesc" >> "$file"
	echo "edesch=$edesch" >> "$file"
	echo "edinclude=$edinclude" >> "$file"
	echo "edhidden=$edhidden" >> "$file"
	echo "edblock=$edblock" >> "$file"
	echo "diffarg=$diffarg" >> "$file"
	echo "edtables=$edtables" >> "$file"
	echo "edtable_ascii=$edtable_ascii" >> "$file"
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
	elif [[ $1 == delete ]] || [[ $1 == d ]]
	then
		[[ -z $2 ]] && return 3
		local filename="${files[$(($2 - 1))]}"
		filename="${filename//\/\//\/}"
		[[ -n $filename ]] && rm "$filename"
	fi
}

function eso { editsessionopen "$@"; }
function esq { editsessionclose "$@"; }
function ese { editsession "$@"; }
function esw { editsessionwrite "$@"; }

function _editsession {
	local cur=${COMP_WORDS[COMP_CWORD]}
	local files=()
	shopt -s dotglob
	local n=1
	for i in $editsessiondir/*
	do
		files+=("$n")
		n="$((n + 1))"
	done

	shopt -u dotglob
	local numbers="${files[@]}"
	case "$COMP_CWORD" in
		1)
			COMPREPLY=($(compgen -o bashdefault \
				-W "delete d list l $numbers" -- $cur))
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
