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
edsyntax="y"
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
	[[ -n $2 ]] && local fn="$2"
	[[ -z $fn ]] && return 0
	[[ ${fn:0:1} != '/' ]] && fn="$PWD/$fn"
	if [[ -n $1 ]]
	then
		result="$(echo -e "$1" | ed -s "$fn")"
		echo "$result"
		fs="$(wc -l "$fn" | cut -d ' ' -f1)"
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
	[[ -n $4 ]] && local fn="$4"
	[[ -z $fn ]] && return 1
	[[ ${fn:0:1} != '/' ]] && fn="$PWD/$fn"
	[[ -z $1 ]] && return 2
	[[ -z $2 ]] && return 3
	[[ -z $3 ]] && return 4
 	local begin="$1"
	local end="$2"
	[[ $begin == "." ]] && begin="$fl"
	[[ $end == "." ]] && end="$fl"
	[[ $begin == "$" ]] && begin="$fs"
	[[ $end == "$" ]] && end="$fs"
	[[ $begin =~ ^\+ ]] && begin="${begin/+/}" && begin="$((fl + begin))"
	[[ $end =~ ^\+ ]] && end="${end/+/}" && end="$((fl + end))"
	[[ $begin =~ ^\- ]] && begin="${begin/-/}" && begin="$((fl - begin))"
	[[ $end =~ ^\- ]] && end="${end/-/}" && end="$((fl - end))"
	editread $begin $end "$fn"
	cat "$editreadlines" | $3 > "$HOME/.edit/temp"
	mv "$HOME/.edit/temp" "$editreadlines"
	edit "${begin},${end}d\nw"
	editread 0 0 0 $(($begin - 1))		
	editshow ${begin},$end
}

function editstore {
	[[ -n $1  ]] && local fn="$1"
	[[ -z $fn ]] && return 1
	[[ ${fn:0:1} != '/' ]] && fn="$PWD/$fn"
	local date="$(date +'%Y-%m-%d_%H-%M-%S')"
	local dir="$HOME/.edit/$(dirname "$fn")"
	mkdir -p "$dir"
	cp "$fn" "$dir"
	mv "$HOME/.edit/$fn" "$HOME/.edit/${fn}_${date}"
}

function editundo {
	[[ -n $4  ]] && local fn="$4"
	[[ -z $fn ]] && return 1
	[[ ${fn:0:1} != '/' ]] && fn="$PWD/$fn"
	local dir="$HOME/.edit/$(dirname "$fn")"
	local files=()
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
			local f="${version:0:${#fn}}"
			if  [[ -f $i ]] && [[ "$fn" == "$f" ]]
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
			&& edsyntax=n edcmd=p editshow a "${files[$2]}"
	elif [[ $1 =~ [0-9]+ ]]
	then
		[[ -f ${files[$1]} ]] \
			&& cp "${files[$1]}" "$fn" \
			|| echo "?"
		fs="$(wc -l "$fn" | cut -d ' ' -f1)"
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
		fn="$f"
		tmux select-pane -T "$fn"
		cd "$(dirname $fn)"
		fl=1
		syntax=
		editsyntax "$fn"
		[[ -n $argument ]] && editarg "$argument" || editshow $
	fi
}

function editclose {
	[[ -n $fn ]] && fn=
	[[ -n $fl ]] && fl=
	[[ -n $fs ]] && fs=
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
			if [[ -n $syntax ]] && [[ $edsyntax == y ]]
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
	[[ -n $2 ]] && local fl="$2"
	local pattern="$1"
	[[ $1 =~ ^\/ ]] && pattern="${pattern/\//}"
	local to="$(edsyntax=n \
		ef "${fl},${fs}g/$pattern/n" | head -n1)"
	to="${to/\ */}"
	to="${to/*:/}"
	echo "$to"
}

function editshow {
	[[ -n $2 ]] && local fn="$2"
	[[ -z $fn ]] && return 1
	[[ ${fn:0:1} != '/' ]] && fn="$PWD/$fn"
	fs="$(wc -l "$fn" | cut -d ' ' -f1)"
	[[ -z $fs ]] && return 2
	[[ -z $pagesize ]] && pagesize=20
	[[ -z $fl ]] && fl=1
	! [[ $fl =~ [0-9]+ ]] && fl="$fs"
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
				fl="${fileresult[$fileresultindex]}"
				printf "$fileresultindex:"
				editshow ${fl}
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

			fl="${fileresult[$fileresultindex]}"
			printf "$fileresultindex:"
			editshow $fl
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

			fl="${fileresult[$fileresultindex]}"
			printf "$fileresultindex:"
			editshow $fl
			return
		elif [[ $arg == "s" ]]
		then
			local counter=0
			for i in "${fileresult[@]}"
			do
				local line="$(edit ${i}n)"
				line="${line/$'\t'/ }"
				printf "$counter:"
				if [[ -n $syntax ]] && [[ $edsyntax == y ]]
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
				fl="$end"
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
		fl="$fs"
		show="edit ${fl}$edcmd"
	elif [[ $arg == "g" ]]
	then
		fl="1"
		show="edit ${fl}$edcmd"
	elif [[ $arg =~ ^([.+-]?([0-9]+)?)(,[$+]?([0-9]+)?)?$ ]] \
		&& [[ $arg != "." ]]
	then
		[[ $arg == "+" ]] && arg="$((fl + 1))"
		[[ $arg == "-" ]] && arg="$((fl - 1))"
		if [[ $arg =~ , ]]
		then
			local head="${arg/,*/}"
			local tail="${arg/*,/}"
			[[ $head == "." ]] && head="$fl"
			[[ $head =~ ^\-[0-9]+ ]] && head="${head/-/}" \
				&& head="$((fl - head))"
			[[ $head =~ ^\+[0-9]+ ]] && head="${head/+/}" \
				&& head="$((fl + head))"
			[[ $head -lt 1 ]] && head="1"
			[[ $tail == "$" ]] && tail="$fs"
			[[ $tail =~ ^\+[0-9]+ ]] && tail="${tail/+/}" \
				&& tail="$((fl + tail))"
			[[ $tail -gt $fs ]] && tail="$fs"
			show="edit ${head},${tail}$edcmd"
			fl="$tail"
		else
			[[ $arg =~ ^\+[0-9]+ ]] && arg="${arg/+/}" \
				&& arg="$((fl + arg))"
			[[ $arg =~ ^\-[0-9]+ ]] && arg="${arg/-/}" \
				&& arg="$((fl - arg))"
			[[ $arg -lt 1 ]] && arg="1"
			[[ $arg -gt $fs ]] && arg="$fs"
			show="edit ${arg}$edcmd"
			fl="$arg"
		fi
	elif [[ $arg =~ ^\/.*(,\/.*)? ]] && [[ -z $show ]]
	then
		if [[ $arg =~ , ]]
		then
			local head="${arg/,*/}"
			local tail="${arg/*,/}"
			head="$(editlocate "${head/\//}")"
			tail="$(editlocate "${tail/\//}" $((fl + 1)))"
			[[ -n $head ]] && [[ -n $tail ]] \
				&& show="edit ${head},${tail}$edcmd" \
				&& fl="$tail"
		else
			local line="$(editlocate "${arg/\//}")"
			[[ $line =~ ^[0-9]+$ ]] && show="edit ${line}$edcmd" \
				&& fl="$line"
		fi
	elif [[ $arg == "l" ]] || [[ $arg == "." ]]
	then
		show="edit ${fl}$edcmd"
	elif [[ $pagesize -ge $fs ]]
	then
		show="edit "1,${fs}$edcmd""
	elif [[ $arg == "n" ]]
	then
		[[ $eslastarg == "p" ]] \
			&& fl="$((fl + pagesize + 2))"
		if [[ $fl -ge $((fs - pagesize)) ]]
		then
			show="edit "$((fs - pagesize)),${fs}$edcmd""
			fl="$fs"
		else
			show="edit "${fl},$((fl + pagesize))$edcmd""
			fl="$((fl + pagesize + 1))"
		fi
	elif [[ $arg == "p" ]]
	then
		[[ $eslastarg == "n" ]] \
			&& [[ $fl -ne $fs ]] \
			&& fl="$((fl - pagesize - 2))"
		[[ $eslastarg == "n" ]] \
			&& [[ $fl == $fs ]] \
			&& fl="$((fl - pagesize - 1))"
		if [[ $fl -le $pagesize ]]
		then
			show="edit "1,${pagesize}$edcmd""
			fl=$pagesize
		else
			show="edit "$((fl - pagesize)),${fl}$edcmd""
			fl=$((fl - pagesize - 1))
		fi
	elif [[ $arg == "b" ]]
	then
		show="edit "1,${pagesize}$edcmd""
		fl=$((pagesize + 1))
	elif [[ $arg == "e" ]]
	then
		show="edit "$((fs - pagesize)),${fs}$edcmd""
		fl=$((fs - pagesize - 1))
	elif [[ $arg == "a" ]]
	then
		show="edit ,$edcmd"
	elif [[ $arg == "c" ]]
	then
		local head="$((fl - (pagesize / 2)))"
		local tail="$((fl + (pagesize / 2)))"
		[[ $head -lt 1 ]] && head="1" \
			&& tail="$((tail + (pagesize / 2)))"
		[[ $tail -gt $fs ]] && tail="$fs"
		show="edit ${head},${tail}$edcmd"
	fi

	if [[ -n $show ]]
	then
		if [[ -n $syntax ]] && [[ $edsyntax == y ]]
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
	local data="$1"
	edit "${fl}a\n$data\n.\nw"
	[[ -n $2 ]] && editshow "+$2" \
		|| editshow "+$(echo -e "$data" | grep -c "^")"
}

function editinsert {
	fl="$((fl - 1))"
	editappend "$1" "$2"
}

function editdelete {
	[[ -n $1 ]] && local to="$1"
	[[ $1 =~ ^\+[0-9]+ ]] && to="${1/\+/}" && to="$((fl + to))"
	[[ $to -gt $fs ]] && return 1
	[[ -z $to ]] && edit "${fl}d\nw" || edit "${fl},${to}d\nw"
	fs="$(wc -l "$fn" | cut -d ' ' -f1)"
	[[ $fl -gt $fs ]] && fl="$fs"
}

function editchange {
	if [[ -n $1 ]]
	then
		local data="$1"
		[[ -n $2 ]] && local to="$2"
		[[ $2 =~ ^\+[0-9]+ ]] && to="${2/\+/}" && to="$((fl + to))"
		[[ $to -gt $fs ]] && return 1
		[[ -z $to ]] && edit "${fl}c\n$data\n.\nw" \
			|| edit "${fl},${to}c\n$data\n.\nw"
		[[ -z $to ]] && editshow l || editshow ${fl},$to
	else
		return 2
	fi
}

function editsub {
	if [[ -n $1 ]]
	then
		[[ -n $3 ]] && local to="$3"
		[[ $to =~ ^\+[0-9]+ ]] && to="${to/\+/}" && to="$((fl + to))"
		[[ $to == '%' ]] && to="$fs"
		[[ $to -gt $fs ]] && return 1
		local in="$1"
		local out="$2"
		in="${in//\\\\/\\\\\\\\}"
		out="${out//\\\\/\\\\\\\\}"
		local pattern="s/$in/$out/"
		[[ $4 == "g" ]] && pattern="${pattern}g"
		if [[ -z $to ]] || [[ $to == " " ]]
		then
			edit "$fl$pattern\nw"
		else
			local lines="${fl},${to}"
			[[ $3 == "%" ]] && lines="1,${fs}"
			edit "$lines$pattern\nw"
		fi

		editshow l
	else
		return 2
	fi
}

function editjoin {
	local l=
	[[ -z $1 ]] && l="$((fl + 1))"
	[[ $1 =~ ^\+[0-9]+ ]] && l="${1/\+/}" && l="$((fl + l))"
	[[ $l -gt $fs ]] && return 1
	[[ -n $l ]] && edit "${fl},${l}j\nw" && editshow ${fl}
}

function editmove {
	local dest="$1"
	[[ -z $1 ]] && dest="$((fl + 1))"
	[[ $dest =~ ^\+[0-9]+ ]] && dest="${1/\+/}" && dest="$((fl + dest))"
	[[ $dest =~ ^\-[0-9]+ ]] && dest="${1/\-/}" && dest="$((fl - dest))"
	[[ $dest -gt $fs ]] && return 1
	[[ $dest -lt 1 ]] && return 1
	local to="$2"
	[[ $to =~ ^\+[0-9]+ ]] && to="${dest/\+/}" && to="$((fl + l))"
	[[ -n $to ]] && edit "${fl},${to}m$dest\nw" \
			|| edit "${fl}m$dest\nw"
}

function edittransfer {
	yank=
	local line="$1"
	[[ $1 == "." ]] && line="$fl"
	[[ -n $2 ]] && local n="$2" \
		&& [[ $n =~ ^\+ ]] && n="${n/\+/}" && n="$((fl + n))"
	if [[ $line -gt 0 ]]
	then
		[[ -n $n ]] && edit "${fl},${n}t$line\nw" \
			|| edit "${fl}t$line\nw"
	elif [[ $1 -eq 0 ]] && [[ -n $n ]]
	then
		yank="$(edcmd=p edsyntax=n editshow ${fl},$n)"
	else
		yank="$(edcmd=p edsyntax=n editshow l)"
	fi

	[[ $3 == "x" ]] && [[ -n $yank ]] && echo "$yank" | xclip -i
}

function editlevel {
	local line=
	[[ -n $1 ]] \
		&& line="$(edsyntax=n edcmd=p es $1)" \
		|| line="$(edsyntax=n edcmd=p es l)"
	[[ -n $line ]] && echo "$line" | awk -F '\t' '{ print NF-1 }' || return 1
}

function editspaces {
	local n=0
	local line=
	[[ -n $1 ]] \
		&& line="$(edsyntax=n edcmd=p es $1)" \
		|| line="$(edsyntax=n edcmd=p es l)"
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
function els { editspaces "$@"; }
function el { editlevel "$@"; }
function emore { [[ -n $fn ]] && editshow $fl,$fs | more -lf; }
function em { editmove "$@"; }
function eo { editopen "$@"; }
function eq { editclose "$@"; }
function er { editread "$@"; }
function esu { editsub "$@"; }
function es { editshow "$@"; }
function et { editstore "$@"; }
function eu { editundo "$@"; }
function ey { edittransfer "$@"; }
function e { edit "$@"; }
