#!/usr/bin/env bash

# highlight
himode="xterm256"
#hitheme="neon"
#hitheme="lucretia"
hitheme="bluegreen"
function hi { highlight "$1" --syntax "$2" -s $hitheme -O $himode; }

# edit
editreadlines="$HOME/.edit/readlines"
edcmd="n"
editsyntax="y"
diffarg="--color -c"

function editwindow {
	local window=
	local pane=
	local session="$(tmux display-message -p '#S')"
	[[ -n $3 ]] && session="$3"
	for i in $(tmux lsp -s -t "$session:0" -F '#I::#D #T')
	do
		if [[ $i == $1 ]] && [[ -n $window ]] && [[ -n $pane ]]
		then
			tmux select-window -t "$session:$window"
			tmux select-pane -t "$pane"
			[[ -n $2 ]] && editarg "$2" "$session"
			return 1
		fi

		window="${i/::*/}"
		pane="${i/*::/}"
	done

	return 0
}

function edit {
	[[ -n $2 ]] && local filename="$2"
	[[ -z $filename ]] && return 0
	[[ ${filename:0:1} != '/' ]] && filename="$PWD/$filename"
	if [[ -n $1 ]]
	then
		result="$(echo -e "$1" | ed -s "$filename")"
		echo "$result"
		filesize="$(wc -l "$filename" | cut -d ' ' -f1)"
	fi
}

function editread {
	if [[ $1 != 0 ]] && [[ $2 != 0 ]] && [[ $3 != 0 ]]
	then
		local f="$3"
		[[ ${f:0:1} != '/' ]] && f="$PWD/$f"
		local lines="$(edit "${1},${2}p" "$f")"
		mkdir -p "$HOME/.edit"
		echo "$lines" > "$editreadlines"
	fi

	if [[ -n $4 ]] && [[ -f $editreadlines ]]
	then
		if [[ -n $5 ]]
		then
			local f="$5"
			[[ ${f:0:1} != '/' ]] && f="$PWD/$f"
			edit "${4}r $editreadlines\nw" "$f"
		else
			edit "${4}r $editreadlines\nw"
		fi
	fi
}

function editcmd {
	[[ -n $4 ]] && local filename="$4"
	[[ -z $filename ]] && return 1
	[[ ${filename:0:1} != '/' ]] && filename="$PWD/$filename"
	if [[ -n $1 ]] && [[ -n $2 ]]
	then
		local lines="$(sed -n "${1},${2}p" "$filename")"
		editread $1 $2 "$filename"
		cat "$editreadlines" | $3 > "$HOME/.edit/temp"
		mv "$HOME/.edit/temp" "$editreadlines"
		edit "${1},${2}d\nw"
		editread 0 0 0 $(($1 - 1))		
		editshow ${1},$2
	fi
}

function editstore {
	[[ -n $1  ]] && local filename="$1"
	[[ -z $filename ]] && return 1
	[[ ${filename:0:1} != '/' ]] && filename="$PWD/$filename"
	local date="$(date +'%Y-%m-%d_%H-%M-%S')"
	local dir="$HOME/.edit/$(dirname "$filename")"
	mkdir -p "$dir"
	cp "$filename" "$dir"
	mv "$HOME/.edit/$filename" "$HOME/.edit/${filename}_${date}"
}

function editundo {
	[[ -n $4  ]] && local filename="$4"
	[[ -z $filename ]] && return 1
	[[ ${filename:0:1} != '/' ]] && filename="$PWD/$filename"
	local dir="$HOME/.edit/$(dirname "$filename")"
	local files=()
	if [[ -d "$dir" ]]
	then
		local n=1
		shopt -s dotglob
		for i in $dir/*
		do
			local version="/${i/*\/\//}"
			local f="${version:0:${#filename}}"
			if  [[ -f $i ]] && [[ "$filename" == "$f" ]]
			then
				files[$n]="$i"
				n=$((n + 1))
			fi
		done

		shopt -u dotglob
	fi

	[[ ${#files[@]} -eq 0 ]] && return 2
	if [[ $1 == "l" ]] || [[ $1 == "list" ]]
	then
		local n=1
		for i in ${files[@]}
		do
			local version="/${i/*\/\//}"
			local f="${version:0:${#filename}}"
			if  [[ -f $i ]] && [[ "$filename" == "$f" ]]
			then
				echo "$n - $version"
				n=$((n + 1))
			fi
		done
	elif [[ $1 == "-" ]] || [[ $2 == "delete" ]]
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
	elif [[ $1 == "diff" ]]
	then
		[[ -z $2 ]] && [[ -z $3 ]] && return 3
		if [[ -f ${files[$2]} ]] && [[ -f ${files[$3]} ]]
		then
			diff $diffarg "${files[$2]}" "${files[$3]}" 
		else
			echo "?"
		fi
	elif [[ $1 == "es" ]] || [[ $1 == "show" ]]
	then
		[[ -z $2 ]] && return 3
		[[ -f ${files[$2]} ]] && editshow a "${files[$2]}"
	elif [[ $1 == "p" ]] || [[ $1 == "print" ]]
	then
		[[ -z $2 ]] && return 3
		[[ -f ${files[$2]} ]] \
			&& editsyntax=n edcmd=p editshow a "${files[$2]}"
	elif [[ $1 =~ [0-9]+ ]]
	then
		[[ -f ${files[$1]} ]] \
			&& cp "${files[$1]}" "$filename" \
			|| echo "?"
		filesize="$(wc -l "$filename" | cut -d ' ' -f1)"
	else
		echo "?"
		return 4
	fi
}

function editarg {
	[[ -n $1 ]] && argument="$1"
	[[ -z $argument ]] && return 1
	local session="$(tmux display-message -p '#S')"
	[[ -n $2 ]] && session="$2"
	if [[ $argument =~ ^[0-9]+$ ]]
	then
		tmux send-keys -t "$session" "edit \"${argument}n\""
	else
		argument="${argument//\//\\/}"
		argument="${argument//\*/\\*}"
		tmux send-keys -t "$session" "edit \"/${argument}/n\""
	fi

	tmux send-keys -t "$session" Enter
}

function editsyntax {
	local shebang="$(edit 1p "$1")"
	[[ $shebang =~ \#\!.*\ ?(bash|sh) ]] && syntax=bash
	[[ $shebang =~ \#\!.*\ ?lua ]] && syntax=lua
	[[ $shebang =~ \#\!.*\ ?perl ]] && syntax=perl
	[[ $shebang =~ \#\!.*\ ?ruby ]] && syntax=ruby
	[[ $shebang =~ \#\!.*\ ?python ]] && syntax=python
	[[ -n $syntax ]] && return
	[[ $1 == $HOME/.bashrc ]] && syntax=bash 
	[[ $1 =~ \.awk ]] && syntax=awk
	[[ $1 =~ \.conf ]] && syntax=conf
	[[ $1 =~ \.cmake ]] && syntax=cmake
	[[ $1 =~ \.css ]] && syntax=css
	[[ $1 =~ \.cpp ]] && syntax=c
	[[ $1 =~ \.c ]] && syntax=c
	[[ $1 =~ \.diff ]] && syntax=diff
	[[ $1 == /etc/fstab ]] && syntax=fstab
	[[ $1 =~ \.elisp ]] && syntax=lisp
	[[ $1 =~ \.el ]] && syntax=lisp
	[[ $1 =~ \.gdb ]] && syntax=gdb
	[[ $1 =~ \.GNUmakefile ]] && syntax=makefile
	[[ $1 =~ \.html ]] && syntax=html
	[[ $1 =~ \.ini ]] && syntax=ini
	[[ $1 =~ \.INI ]] && syntax=ini
	[[ $1 =~ \.java ]] && syntax=java
	[[ $1 =~ \.json ]] && syntax=json
	[[ $1 =~ \.js ]]  && syntax=javascript
	[[ $1 =~ \.lisp ]] && syntax=lisp
	[[ $1 =~ \.lang ]] && syntax=json
	[[ $1 =~ \.lua ]] && syntax=lua
	[[ $1 =~ \.latex ]] && syntax=latex
	[[ $1 =~ \.less ]] && syntax=less
	[[ $1 =~ \.markdown ]] && syntax=markdown
	[[ $1 =~ \.md ]] && syntax=markdown
	[[ $1 =~ .*\/makefile ]] && syntax=makefile
	[[ $1 =~ .*\/Makefile ]] && syntax=makefile
	[[ $1 =~ \.meson ]] && syntax=meson
	[[ $1 =~ \.objc ]] && syntax=objc
	if [[ $1 =~ \.org ]]
	then
		local f="$HOME/.highlight/org-simple.lang"
		[[ -f $f ]] \
			&& syntax=$HOME/.highlight/org-simple.lang \
			|| syntax=org
	fi

	[[ $1 =~ \.perl ]] && syntax=perl
	[[ $1 =~ \.php ]] && syntax=php
	[[ $1 =~ \.pl ]] && syntax=perl
	[[ $1 =~ \.py ]] && syntax=python
	[[ $1 =~ \.qmake ]] && syntax=qmake
	[[ $1 =~ \.ruby ]] && syntax=ruby
	[[ $1 =~ \.sh ]] && syntax=bash
	[[ $1 =~ \.s ]] && syntax=assembler
	[[ $1 =~ \.tex ]] && syntax=latex
}

function editopen {
	if [[ -n $1 ]]
	then
		local argument="${1#*:}"
		local f="${1/:*/}"
		[[ $f == $argument ]] && argument=
		[[ $f =~ ^% ]] && f="$(cortex-db -q "$f")"
	fi

	[[ -z $f ]] && return 2
	[[ ${f:0:1} != '/' ]] && f="$PWD/$f"
	local session="$(tmux display-message -p '#S')"
	[[ -n $2 ]] && session="$2"
	editwindow "$f" "$argument" "$session"
	[[ $? == 1 ]] && return 1
	if [[ -f $f ]]
	then
		filename="$f"
		tmux select-pane -T "$filename"
		cd "$(dirname $filename)"
		fileline=1
		syntax=
		editsyntax "$filename"
		[[ -n $argument ]] && editarg "$argument" || editshow $
	fi
}

function editclose {
	[[ -n $filename ]] && filename=
	[[ -n $fileline ]] && fileline=
	[[ -n $filesize ]] && filesize=
	[[ -n $syntax ]] && syntax=
	[[ -n $fileresult ]] && fileresult=
	[[ -n $fileresultindex ]] && fileresultindex=
	tmux select-pane -T "$(hostname)"
}

function editfind {
	[[ -z $1 ]] && return 1
	local result="$(edit "$1")"
	if [[ -n $result ]]
	then
		fileresult=()
		fileresultindex=-1
		local IFS=$'\n'
		local counter=0
		for i in $result
		do
			fileresult+=("${i/$'\t'*/}")
			printf "$counter:"
			if [[ -n $syntax ]] && [[ $editsyntax == y ]]
			then
				echo "${i/$'\t'/ }" | highlight \
					--syntax $syntax -s $hitheme -O $himode
			else
				echo "${i/$'\t'/ }"
			fi

			counter=$((counter+1))
		done
	fi
}

function editlocate {
	[[ -z $1 ]] && return 1
	[[ -n $2 ]] && local fileline="$2"
	local to="$(editsyntax=n \
		ef "${fileline},${filesize}g/$1/n" | head -n1)"
	to="${to/\ */}"
	to="${to/*:/}"
	echo "$to"
}

function editshow {
	[[ -n $2 ]] && local filename="$2"
	[[ -z $filename ]] && return 1
	[[ ${filename:0:1} != '/' ]] && filename="$PWD/$filename"
	filesize="$(wc -l "$filename" | cut -d ' ' -f1)"
	[[ -z $filesize ]] && return 2
	[[ -z $pagesize ]] && pagesize=20
	[[ -z $fileline ]] && fileline=1
	! [[ $fileline =~ [0-9]+ ]] && fileline="$filesize"
	local arg="$1"
	[[ -z $1 ]] && arg="+"
	local show=
	if [[ -n $fileresult ]] && [[ $fileresultindex ]]
	then
		if [[ $arg =~ f([0-9]+) ]]
		then
			local n=${arg//f/}
			if [[ $n -ge 0 ]] && [[ $n -le $((${#fileresult[@]}-1)) ]]
			then
				fileresultindex=$n
				fileline="${fileresult[$fileresultindex]}"
				printf "$fileresultindex:"
				editshow ${fileline}
			else
				echo "?"
			fi

			return
		elif [[ $arg == "u" ]]
		then
			if [[ $fileresultindex -eq 0 ]] || [[ $fileresultindex -eq -1 ]]
			then
				fileresultindex=$((${#fileresult[@]}-1))
			elif [[ $fileresultindex -gt 0 ]]
			then
				fileresultindex=$((fileresultindex-1))
			fi

			fileline="${fileresult[$fileresultindex]}"
			printf "$fileresultindex:"
			editshow $fileline
			return
		elif [[ $arg == "d" ]]
		then
			if [[ $fileresultindex -eq $((${#fileresult[@]}-1)) ]]
			then
				fileresultindex=0
			elif [[ $fileresultindex -lt $((${#fileresult[@]}-1)) ]]
			then
				fileresultindex=$((fileresultindex+1))
			fi

			fileline="${fileresult[$fileresultindex]}"
			printf "$fileresultindex:"
			editshow $fileline
			return
		elif [[ $arg == "s" ]]
		then
			local counter=0
			for i in "${fileresult[@]}"
			do
				local line="$(edit ${i}n)"
				line="${line/$'\t'/ }"
				printf "$counter:"
				if [[ -n $syntax ]] && [[ $editsyntax == y ]]
				then
					echo "$line" | highlight \
						--syntax $syntax -s $hitheme -O $himode
				else
					echo "$line"
				fi

				counter=$((counter+1))
			done

			return
		elif [[ $arg == "m" ]]
		then
			local asize=${#fileresult[@]}
			if [[ $fileresultindex -lt $((asize - 1)) ]]
			then
				local start="${fileresult[$fileresultindex]}"
				local end="$((${fileresult[$((fileresultindex + 1))]} - 1))"
				fileline="$end"
				editshow ${start},${end}
			else
				editshow c
			fi

			return
		fi
	fi

	if [[ $arg == "r" ]]
	then
		if [[ -n $eslast ]] && [[ ${eslast:0-1} != $edcmd ]]
		then
			[[ ${eslast:0-1} == "p" ]] \
				&& eslast="${eslast/%p/n}" \
				|| eslast="${eslast/%n/p}"
		fi

		show="$eslast"
	elif [[ $arg == "$" ]] || [[ $arg == "G" ]]
	then
		fileline="$filesize"
		show="edit ${fileline}$edcmd"
	elif [[ $arg == "g" ]]
	then
		fileline="1"
		show="edit ${fileline}$edcmd"
	elif [[ $arg =~ ^([.+-]?([0-9]+)?)(,[$+]?([0-9]+)?)?$ ]] \
		&& [[ $arg != "." ]]
	then
		[[ $arg == "+" ]] && arg="$((fileline + 1))"
		[[ $arg == "-" ]] && arg="$((fileline - 1))"
		if [[ $arg =~ , ]]
		then
			local head="${arg/,*/}"
			local tail="${arg/*,/}"
			[[ $head == "." ]] && head="$fileline"
			[[ $head =~ ^\-[0-9]+ ]] && head="${head/-/}" \
				&& head="$((fileline - head))"
			[[ $head =~ ^\+[0-9]+ ]] && head="${head/+/}" \
				&& head="$((fileline + head))"
			[[ $head -lt 1 ]] && head="1"
			[[ $tail == "$" ]] && tail="$filesize"
			[[ $tail =~ ^\+[0-9]+ ]] && tail="${tail/+/}" \
				&& tail="$((fileline + tail))"
			[[ $tail -gt $filesize ]] && tail="$filesize"
			show="edit ${head},${tail}$edcmd"
			fileline="$tail"
		else
			[[ $arg =~ ^\+[0-9]+ ]] && arg="${arg/+/}" \
				&& arg="$((fileline + arg))"
			[[ $arg =~ ^\-[0-9]+ ]] && arg="${arg/-/}" \
				&& arg="$((fileline - arg))"
			[[ $arg -lt 1 ]] && arg="1"
			[[ $arg -gt $filesize ]] && arg="$filesize"
			show="edit ${arg}$edcmd"
			fileline="$arg"
		fi
	elif [[ $arg =~ ^\/.*(,\/.*)? ]] && [[ -z $show ]]
	then
		if [[ $arg =~ , ]]
		then
			local head="${arg/,*/}"
			local tail="${arg/*,/}"
			head="$(editlocate "${head/\//}")"
			tail="$(editlocate "${tail/\//}" "$((fileline + 1))")"
			[[ -n $head ]] && [[ -n $tail ]] \
				&& show="edit ${head},${tail}$edcmd" \
				&& fileline="$tail"
		else
			local line="$(editlocate "${arg/\//}")"
			[[ $line =~ ^[0-9]+$ ]] && show="edit ${line}$edcmd" \
				&& fileline="$line"
		fi
	elif [[ $arg == "l" ]] || [[ $arg == "." ]]
	then
		show="edit ${fileline}$edcmd"
	elif [[ $pagesize -ge $filesize ]]
	then
		show="edit "1,${filesize}$edcmd""
	elif [[ $arg == "n" ]]
	then
		[[ $eslastarg == "p" ]] \
			&& fileline="$((fileline + pagesize + 2))"
		if [[ $fileline -ge $((filesize - pagesize)) ]]
		then
			show="edit "$((filesize - pagesize)),${filesize}$edcmd""
			fileline="$filesize"
		else
			show="edit "${fileline},$((fileline + pagesize))$edcmd""
			fileline="$((fileline + pagesize + 1))"
		fi
	elif [[ $arg == "p" ]]
	then
		[[ $eslastarg == "n" ]] \
			&& [[ $fileline -ne $filesize ]] \
			&& fileline="$((fileline - pagesize - 2))"
		[[ $eslastarg == "n" ]] \
			&& [[ $fileline == $filesize ]] \
			&& fileline="$((fileline - pagesize - 1))"
		if [[ $fileline -le $pagesize ]]
		then
			show="edit "1,${pagesize}$edcmd""
			fileline=$pagesize
		else
			show="edit "$((fileline - pagesize)),${fileline}$edcmd""
			fileline=$((fileline - pagesize - 1))
		fi
	elif [[ $arg == "b" ]]
	then
		show="edit "1,${pagesize}$edcmd""
		fileline=$((pagesize + 1))
	elif [[ $arg == "e" ]]
	then
		show="edit "$((filesize - pagesize)),${filesize}$edcmd""
		fileline=$((filesize - pagesize - 1))
	elif [[ $arg == "a" ]]
	then
		show="edit ,$edcmd"
	elif [[ $arg == "c" ]]
	then
		local head="$((fileline - (pagesize / 2)))"
		local tail="$((fileline + (pagesize / 2)))"
		[[ $head -lt 1 ]] && head="1" \
			&& tail="$((tail + (pagesize / 2)))"
		[[ $tail -gt $filesize ]] && tail="$filesize"
		show="edit ${head},${tail}$edcmd"
	fi

	if [[ -n $show ]]
	then
		if [[ -n $syntax ]] && [[ $editsyntax == y ]]
		then
			$show | highlight --syntax $syntax -s $hitheme -O $himode
		else
			$show
		fi

		eslastarg="$arg"
		eslast="$show"
	fi
}

function editappend {
	edit "${fileline}a\n$1\n.\nw"
	[[ -n $2 ]] && editshow "+$2" \
		|| editshow "+$(echo -e "$1" | grep -c "^")"
}

function editinsert {
	fileline="$((fileline - 1))"
	editappend "$1" "$2"
}

function editdelete {
	[[ -n $1 ]] && local to="$1"
	[[ $1 =~ ^\+[0-9]+ ]] && to="${1/\+/}" && to="$((fileline + to))"
	[[ $to -gt $filesize ]] && return 1
	[[ -z $to ]] && edit "${fileline}d\nw" || edit "${fileline},${to}d\nw"
	filesize="$(wc -l "$filename" | cut -d ' ' -f1)"
	[[ $fileline -gt $filesize ]] && fileline="$filesize"
}

function editchange {
	if [[ -n $1 ]]
	then
		[[ -n $2 ]] && local to="$2"
		[[ $2 =~ ^\+[0-9]+ ]] && to="${2/\+/}" && to="$((fileline + to))"
		[[ $to -gt $filesize ]] && return 1
		[[ -z $to ]] && edit "${fileline}c\n$1\n.\nw" \
			|| edit "${fileline},${to}c\n$1\n.\nw"
		[[ -z $to ]] && editshow l || editshow ${fileline},$to
	else
		return 2
	fi
}

function editsub {
	if [[ -n $1 ]]
	then
		[[ -n $3 ]] && local to="$3"
		[[ $to =~ ^\+[0-9]+ ]] && to="${to/\+/}" && to="$((fileline + to))"
		[[ $to == '%' ]] && to="$filesize"
		[[ $to -gt $filesize ]] && return 1
		if [[ -z $to ]] || [[ $to == " " ]]
		then
			local pattern="s/$1/$2/"
			[[ $1 =~ $'\\'$ ]] && pattern="s/$1\/$2/"
			[[ $2 =~ $'\\'$ ]] && pattern="s/$1/$2\/"
			[[ $4 == "g" ]] && pattern="${pattern}g"
			edit "$fileline$pattern\nw"
		else
			local pattern="s/$1/$2/"
			local lines="${fileline},${to}"
			[[ $1 =~ $'\\'$ ]] && pattern="s/$1\/$2/"
			[[ $2 =~ $'\\'$ ]] && pattern="s/$1/$2\/"
			[[ $3 == "%" ]] && lines="1,${filesize}"
			[[ $4 == "g" ]] && pattern="${pattern}g"
			edit "$lines$pattern\nw"
		fi

		editshow l
	else
		return 2
	fi
}

function editjoin {
	local l=
	[[ -z $1 ]] && l="$((fileline + 1))"
	[[ $1 =~ ^\+[0-9]+ ]] && l="${1/\+/}" && l="$((fileline + l))"
	[[ $l -gt $filesize ]] && return 1
	[[ -n $l ]] && edit "${fileline},${l}j\nw" && editshow ${fileline}
}

function editmove {
	local dest="$1"
	[[ -z $1 ]] && dest="$((fileline + 1))"
	[[ $dest =~ ^\+[0-9]+ ]] && dest="${1/\+/}" && dest="$((fileline + dest))"
	[[ $dest =~ ^\-[0-9]+ ]] && dest="${1/\-/}" && dest="$((fileline - dest))"
	[[ $dest -gt $filesize ]] && return 1
	[[ $dest -lt 1 ]] && return 1
	local to="$2"
	[[ $to =~ ^\+[0-9]+ ]] && to="${dest/\+/}" && to="$((fileline + l))"
	[[ -n $to ]] && edit "${fileline},${to}m$dest\nw" \
			|| edit "${fileline}m$dest\nw"
}

function edittransfer {
	yank=
	local line="$1"
	[[ $1 == "." ]] && line="$fileline"
	[[ -n $2 ]] && local n="$2" \
		&& [[ $n =~ ^\+ ]] && n="${n/\+/}" && n="$((fileline + n))"
	if [[ $line -gt 0 ]]
	then
		[[ -n $n ]] && edit "${fileline},${n}t$line\nw" \
			|| edit "${fileline}t$line\nw"
	elif [[ $1 -eq 0 ]] && [[ -n $n ]]
	then
		yank="$(edcmd=p editsyntax=n editshow ${fileline},$n)"
	else
		yank="$(edcmd=p editsyntax=n editshow l)"
	fi

	[[ $3 == "x" ]] && [[ -n $yank ]] && echo "$yank" | xclip -i
}

function editlevel {
	local line=
	[[ -n $1 ]] \
		&& line="$(editsyntax=n edcmd=p es $1)" \
		|| line="$(editsyntax=n edcmd=p es l)"
	[[ -n $line ]] && echo "$line" | awk -F '\t' '{ print NF-1 }' || return 1
}

function editspaces {
	local n=0
	local line=
	[[ -n $1 ]] \
		&& line="$(editsyntax=n edcmd=p es $1)" \
		|| line="$(editsyntax=n edcmd=p es l)"
	[[ -z $line ]] && return 1
	while true
	do
		if [[ $line =~ ^\  ]]
		then
			n="$((n + 1))"
			line="${line/ /}"
		else
			break	
		fi
	done

	echo "$n"
}

function ea { editappend "$@"; }
function ech { editchange "$@"; }
function ec { editcmd "$@"; }
function edel { editdelete "$@"; }
function efl { editlocate "$@"; }
function ef { editfind "$@"; }
function ei { editinsert "$@"; }
function ej { editjoin "$@"; }
function ek { editclose "$@"; }
function els { editspaces "$@"; }
function el { editlevel "$@"; }
function em { editmove "$@"; }
function eo { editopen "$@"; }
function er { editread "$@"; }
function esu { editsub "$@"; }
function es { editshow "$@"; }
function et { editstore "$@"; }
function eu { editundo "$@"; }
function ey { edittransfer "$@"; }
function e { edit "$@"; }
