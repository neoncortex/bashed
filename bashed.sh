#!/usr/bin/env bash

# highlight
himode="xterm256"
hitheme="bluegreen"

# edit
editreadlines="$HOME/.edit/readlines"
edcmd="n"
edsyntax=1
edimg=1
edtmux=1
edesc=1
edesch=0
edecesch=1
edinclude=1
edty=0
edtysleep="0.2"
edhidden=1

# diff
diffarg="--color -c"

# table
edtable_top_left="╔"
edtable_top_right="╗"
edtable_middle_left="╠"
edtable_middle_right="╣"
edtable_middle_top="╦"
edtable_middle_middle="╬"
edtable_bottom_left="╚"
edtable_bottom_right="╝"
edtable_bottom_middle="╩"
edtable_horizontal="═"
edtable_vertical="║"

# table ascii
edtable_top_left_a="+"
edtable_top_right_a="+"
edtable_middle_left_a="+"
edtable_middle_right_a="+"
edtable_middle_top_a="+"
edtable_middle_middle_a="+"
edtable_bottom_left_a="+"
edtable_bottom_right_a="+"
edtable_bottom_middle_a="+"
edtable_horizontal_a="-"
edtable_vertical_a="|"

edtables=1
edtable_ascii=0

function editwindow {
	if [[ $edty -eq 1 ]]
	then
		for i in $(xdotool search --name "." getwindowname "%@")
		do
			if [[ $i == $1 ]]
			then
				if [[ $terminologynew -eq 1 ]]
				then
					local dir="$1"
					[[ $dir =~ ^% ]] \
						&& dir="$(cortex-db -q "$dir")"
					dir="$(dirname "$dir")"
					[[ -z $dir ]] && dir="$PWD"
					local cmd="fn="$1""
					cmd="$cmd;edtmux="$edtmux""
					cmd="$cmd;edty="$edty""
					cmd="$cmd;edtysleep="$edtysleep""
					cmd="$cmd;edimg="$edimg""
					cmd="$cmd;edsyntax="$edsyntax""
					cmd="$cmd;edinclude="$edinclude""
					cmd="$cmd;edtables="$edtables""
					cmd="$cmd;edhidden="$edhidden""
					cmd="$cmd;edesc="$edesc""
					cmd="$cmd;edesch="$edesch""
					cmd="$cmd;edecesch="$edecesch""
					cmd="$cmd;cd "$dir""
					cmd="$cmd;editsyntax "$1""
					cmd="$cmd;[[ -f .bashed ]] && source .bashed"
					cmd="$cmd;clear"
					cmd="$cmd;es 0"
					echo "$cmd" | xclip -i 
					xdotool key Shift+Insert
					sleep $edtysleep
					xdotool key Return
					terminologynew=0
				fi

				if [[ -n $2 ]]
				then
					echo "editarg "$2"" | xclip -i
					xdotool key Shift+Insert
					sleep $edtysleep
					xdotool key Return
				fi

				return 1
			fi
		done

		terminologynew=1
		terminology -T "$1" >& /dev/null &
		sleep $edtysleep
		local gotfocus=0
		for ((j=0; j < 5; ++j))
		do
			wmctrl -a "$1"
			local wname="$(xdotool getactivewindow getwindowname)"
			if [[ "$wname" == "$1" ]]
			then
				gotfocus=1
				break
			else
				sleep 0.5
			fi
		done

		[[ $gotfocus -eq 0 ]] && return 2
		editwindow "$1" "$2"
		return
	fi

	local window=
	local pane=
	[[ $edtmux -eq 0 ]] && [[ -n $2 ]] && editarg "$2"
	[[ $edtmux -eq 0 ]] && return
	[[ $edmutx -eq 1 ]] \
		&& local session="$(tmux display-message -p '#S')"
	for i in $(tmux lsp -s -t "$session:0" -F '#I::#D #T')
	do
		if [[ $i == $1 ]] && [[ -n $window ]] && [[ -n $pane ]]
		then
			if [[ $3 == 'n' ]]
			then
				tmux select-window -t "$session:$window"
				tmux select-pane -t "$pane"
				tmux send-keys -t "$pane" \
					"fn=\"$1\"" Enter
				tmux send-keys -t "$pane" \
					"cd \"\$(dirname \"\$fn\")\"" Enter
				tmux send-keys -t "$pane" "fl=1" Enter
				tmux send-keys -t "$pane" "edimg=$edimg" Enter
				tmux send-keys -t "$pane" "edsyntax=$edsyntax" Enter
				tmux send-keys -t "$pane" "edtmux=$edtmux" Enter
				tmux send-keys -t "$pane" "edty=$edty" Enter
				tmux send-keys -t "$pane" "edtysleep=$edtysleep" Enter
				tmux send-keys -t "$pane" "edtinclude=$edinclude" Enter
				tmux send-keys -t "$pane" "edttables=$edtables" Enter
				tmux send-keys -t "$pane" "edthidden=$edhidden" Enter
				tmux send-keys -t "$pane" "edesc=$edesc" Enter
				tmux send-keys -t "$pane" "edesch=$edesch" Enter
				tmux send-keys -t "$pane" "edecesch=$edesch" Enter
				tmux send-keys -t "$pane" "syntax=" Enter
				tmux send-keys -t "$pane" \
					"editsyntax \"\$fn\"" Enter
				tmux send-keys -t "$pane" \
					"[[ -f \$PWD/.bashed ]] " \
					"&& source \$PWD/.bashed" Enter
				tmux send-keys -t "$pane" "clear" Enter
				[[ -n $2 ]] \
					&& tmux send-keys \
					"editarg \"$2\" \"$pane\"" Enter \
					|| tmux send-keys "editshow 1" Enter
				return
			else
				tmux select-window -t "$session:$window"
				tmux select-pane -t "$pane"
				[[ -n $2 ]] && editarg "$2" "$pane"
				return 1
			fi
		fi

		window="${i/::*/}"
		pane="${i/*::/}"
	done
}

function edit {
	[[ -n $2 ]] && local fn="$2"
	[[ -z $fn ]] && return 1
	[[ -z $1 ]] && return 2
	[[ ${fn:0:1} != '/' ]] && fn="$PWD/$fn"
	result="$(echo -e "$1" | ed -s "$fn")"
	echo "$result"
	fs="$(wc -l "$fn" | cut -d ' ' -f1)"
}

function editread {
	if [[ $1 != 0 ]] && [[ $2 != 0 ]] && [[ $3 != 0 ]]
	then
		[[ -n $3 ]] && local fn="$3"
		[[ ${fn:0:1} != '/' ]] && fn="$PWD/$fn"
		local lines=
		if [[ $edecesch -eq 0 ]]
		then
			lines="$(e "${1},${2}p" "$fn")"
		else
			lines="$(edesch=$edecesch edsyntax=0 edcmd=p \
				es "${1},${2}" "$fn")"
		fi

		mkdir -p "$HOME/.edit"
		echo "$lines" > "$editreadlines"
	fi

	if [[ -n $4 ]] && [[ -f $editreadlines ]]
	then
		local res=
		if [[ -n $5 ]]
		then
			local f="$5"
			[[ ${f:0:1} != '/' ]] && f="$PWD/$f"
			res="$(edit "${4}r $editreadlines\nw" "$f")"
		else
			res="$(edit "${4}r $editreadlines\nw")"
		fi

		[[ -n $res ]] && echo "$res"
	fi
}

function editregion {
	[[ -n $3 ]] && local fn="$3"
	[[ -z $fn ]] && return 1
	[[ ${fn:0:1} != '/' ]] && fn="$PWD/$fn"
	[[ -z $1 ]] && return 2
	[[ -z $2 ]] && return 3
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
	echo "$begin,$end"
}

function editcmd {
	[[ -n $4 ]] && local fn="$4"
	[[ -z $fn ]] && return 1
	[[ -z $3 ]] && return 1
	local region="$(editregion "$1" "$2" "$fn")"
	[[ $? -ne 0 ]] && return $?
	local begin="${region/,*/}"
	local end="${region/*,/}"
	[[ -z $begin ]] || [[ -z $end ]] && return 2
	local tempfile="$HOME/.edit/temp"
	cat "$editreadlines" | $3 > "$tempfile"
	mv "$tempfile" "$editreadlines"
	local res="$(edit "${begin},${end}d\nw")"
	[[ -n $res ]] && echo "$res"
	editread 0 0 "$fn" $(($begin - 1))
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
				n="$((n + 1))"
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
				n="$((n + 1))"
			fi
		done
	elif [[ $1 == "-" ]] || [[ $2 == "delete" ]] || [[ $2 == "rm" ]]
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
	elif [[ $1 == "es" ]] || [[ $1 == "show" ]]
	then
		[[ -z $2 ]] && return 3
		[[ -f ${files[$2]} ]] && editshow a "${files[$2]}"
	elif [[ $1 == "p" ]] || [[ $1 == "print" ]]
	then
		[[ -z $2 ]] && return 3
		[[ -f ${files[$2]} ]] \
			&& edsyntax=0 edcmd=p edinclude=0 edesc=0 edimg=0 \
				editshow a "${files[$2]}"
	elif [[ $1 == "copy" ]] || [[ $1 == "cp" ]]
	then
		[[ -z $2 ]] && [[ -z $3 ]] && return 3
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
	elif [[ $1 =~ [0-9]+ ]]
	then
		[[ -f ${files[$1]} ]] \
			&& cp "${files[$1]}" "$fn" \
			|| echo "?"
		fs="$(wc -l "$fn" | cut -d ' ' -f1)"
		es 1
	else
		echo "?"
		return 4
	fi
}

function editarg {
	[[ -z $1 ]] && return 1
	argument="$1"
	[[ $edtmux -eq 1 ]] \
		&& local session="$(tmux display-message -p '#S')" \
		&& local pane="$2"
	[[ $edtmux -eq 1 ]] && [[ -z $pane ]] && pane="$session"
	if [[ $argument =~ ^[0-9]+$ ]]
	then
		[[ $edty -eq 1 ]] \
			&& echo "es "$argument"" | xclip -i \
			&& xdotool key Shift+Insert \
			&& sleep $edtysleep \
			&& xdotool key Return \
			&& return
		[[ $edtmux -eq 1 ]] \
			&& tmux send-keys -t "$pane" "es $argument" Enter \
			|| es "$argument"
	else
		argument="${argument//\//\\/}"
		argument="${argument//\*/\\*}"
		[[ $edty -eq 1 ]] \
			&& echo "es "$(e "/${argument}/n" | cut -f1)"" | xclip -i \
			&& xdotool key Shift+Insert \
			&& sleep $edtysleep \
			&& xdotool key Return \
			&& return
		[[ $edtmux -eq 1 ]] \
			&& tmux send-keys -t "$pane" \
				"es \$(e \"/${argument}/n\" | cut -f1)" Enter \
			|| es $(e "/${argument}/n" | cut -f1)
	fi
}

function editsyntax {
	local shebang="$(edit 1p "$1")"
	[[ $shebang =~ \#\!.*\ ?(bash|sh) ]] && syntax="bash"
	[[ $shebang =~ \#\!.*\ ?lua ]] && syntax="lua"
	[[ $shebang =~ \#\!.*\ ?perl ]] && syntax="perl"
	[[ $shebang =~ \#\!.*\ ?ruby ]] && syntax="ruby"
	[[ $shebang =~ \#\!.*\ ?python ]] && syntax="python"
	[[ -n $syntax ]] && return
	[[ $1 == $HOME/.bashrc ]] && syntax="bash"
	[[ $1 =~ \.awk$ ]] && syntax="awk"
	[[ $1 =~ \.build$ ]] && syntax="meson"
	[[ $1 =~ \.conf$ ]] && syntax="conf"
	[[ $1 =~ \.cmake$ ]] && syntax="cmake"
	[[ $1 =~ \.css$ ]] && syntax="css"
	[[ $1 =~ \.(c|cpp)$ ]] && syntax="c"
	[[ $1 =~ \.diff$ ]] && syntax="diff"
	[[ $1 == /etc/fstab ]] && syntax="fstab"
	[[ $1 =~ \.(el|elisp|lisp)$ ]] && syntax="lisp"
	[[ $1 =~ \.gdb$ ]] && syntax="gdb"
	[[ $1 =~ \/(GNUmakefile|makefile|Makefile)$ ]] && syntax="makefile"
	[[ $1 =~ \.html$ ]] && syntax="html"
	[[ $1 =~ \.(ini|INI)$ ]] && syntax="ini"
	[[ $1 =~ \.java$ ]] && syntax="java"
	[[ $1 =~ \.(json|lang)$ ]] && syntax="json"
	[[ $1 =~ \.js$ ]]  && syntax="javascript"
	[[ $1 =~ \.lua$ ]] && syntax="lua"
	[[ $1 =~ \.latex$ ]] && syntax="latex"
	[[ $1 =~ \.less$ ]] && syntax="less"
	[[ $1 =~ \.md$ ]] && syntax="markdown"
	[[ $1 =~ \.objc$ ]] && syntax="objc"
	if [[ $1 =~ \.org$ ]]
	then
		local f="$HOME/.highlight/org-simple.lang"
		[[ -f $f ]] \
			&& syntax="$HOME/.highlight/org-simple.lang" \
			|| syntax="org"
	fi

	[[ $1 =~ \.php$ ]] && syntax="php"
	[[ $1 =~ \.(pl|perl)$ ]] && syntax="perl"
	[[ $1 =~ \.py$ ]] && syntax="python"
	[[ $1 =~ \.qmake$ ]] && syntax="qmake"
	[[ $1 =~ \.ruby$ ]] && syntax="ruby"
	[[ $1 =~ \.sh$ ]] && syntax="bash"
	[[ $1 =~ \.s$ ]] && syntax="assembler"
	[[ $1 =~ \.tex$ ]] && syntax="latex"
}

function editopen {
	if [[ -n $1 ]]
	then
		local argument="${1#*:}"
		local f="${1/:*/}"
		[[ $f == $argument ]] && argument=
		[[ $f =~ ^% ]] && f="$(cortex-db -q "$f")"
	fi

	[[ -z $f ]] && return 1
	[[ ${f:0:1} != '/' ]] && f="$PWD/$f"
	editwindow "$f" "$argument"
	[[ $? -eq 1 ]] && return 2
	[[ $? -eq 2 ]] && return 4
	if [[ -f $f ]]
	then
		if [[ $edtmux -eq 1 ]]
		then
			[[ $2 == 'u' ]] && tmux splitw -b -c "$f"
			[[ $2 == 'd' ]] && tmux splitw -c "$f"
			[[ $2 == 'l' ]] && tmux splitw -b -c "$f" -h
			[[ $2 == 'r' ]] && tmux splitw -c "$f" -h
			[[ $2 == 'n' ]] && tmux neww -c "$f"
			tmux select-pane -T "$f"
		fi

		if [[ -z $2 ]] || [[ $edtmux -eq 0 ]]
		then
			fn="$f"
			cd "$(dirname "$fn")"
			fl=1
			syntax=
			editsyntax "$fn"
			[[ -f $PWD/.bashed ]] && source "$PWD/.bashed"
			[[ -n $argument ]] \
				&& editarg "$argument" \
				|| editshow 1
			[[ $edtmux -eq 1 ]] && tmux select-pane -T "$f"
		else
			editwindow "$f" "$argument" n
		fi
	else
		return 3
	fi
}

function editclose {
	[[ -n $fn ]] && fn=
	[[ -n $fl ]] && fl=
	[[ -n $fs ]] && fs=
	[[ -n $syntax ]] && syntax=
	[[ -n $block_syntax ]] && syntax=
	[[ -n $fileresult ]] && fileresult=
	[[ -n $fileresultindex ]] && fileresultindex=
	[[ -n $fileresult_a ]] && fileresult_a=
	[[ $edtmux -eq 1 ]] && tmux select-pane -T "$(hostname)"
}

function editfind {
	[[ -z $1 ]] && return 1
	local result="$(edit "$1")"
	[[ -z $result ]] && return
	fileresult_a=()
	fileresultindex=-1
	fileresult=
	local IFS=$'\n'
	local counter=0
	for i in $result
	do
		fileresult_a+=("${i/$'\t'*/}")
		[[ -z $fileresult ]] \
			&& fileresult="$counter:${i/$'\t'/ }" \
			|| fileresult="$fileresult
$counter:${i/$'\t'/ }"
		counter=$((counter+1))
	done

	[[ -n "$fileresult" ]] && edithi "$fileresult"
}

function editlocate {
	[[ -z $1 ]] && return 1
	[[ -n $2 ]] && local fl="$2"
	local pattern="$1"
	[[ $1 =~ ^\/ ]] && pattern="${pattern/\//}"
	local to="$(edsyntax=0 \
		ef "${fl},${fs}g/$pattern/n" | head -n1)"
	to="${to/\ */}"
	to="${to/*:/}"
	echo "$to"
}

function editimg {
	[[ -z $1 ]] && return 1
	local f="$1"
	[[ $f =~ ^% ]] && f="$(cortex-db -q "$f")"
	[[ -z $f ]] && edithi "$f" && return 2
	[[ $TERMINOLOGY -eq 1 ]] && [[ $edtmux -eq 0 ]] && tycat "$f" && return
	[[ $edty -eq 1 ]] && tycat "$f" || chafa --animate=off "$f"
}

function edithi {
	[[ -z $1 ]] && return 1
	local s="$syntax"
	[[ -n $block_syntax ]] && s="$block_syntax"
	[[ -n $s ]] && [[ $edsyntax == 1 ]] \
		&& echo "$1" | highlight --syntax $s -s $hitheme -O $himode \
		|| echo "$1"
}

function editescape {
	[[ -z "$1" ]] && return 1
	local i="$1"
	local first=1
	local escaped=0
	local IFS=$' '
	local n="${i/	*/}"
	local line="$i"
	local nospace=0
	[[ $edcmd == 'n' ]] \
		&& printf "%s\t" "$(edithi "$n")"  \
		&& line="$(e ${n}p)"
	for j in $line
	do
		[[ -z $j ]] && break
		if [[ $j =~ ^\[\[\\[0-9][0-9][0-9] ]]
		then
			escaped=1
			[[ $edesch -eq 0 ]] \
				&& printf "%b" "${j/\[\[/}"
		elif [[ $j =~ ^\\[0-9][0-9][0-9].*\]\] ]]
		then	
			escaped=0
			[[ $edesch -eq 0 ]] \
				&& printf "%b" "${j/\]\]/}"
			! [[ $j =~ \]$ ]] && j="${j/*]/}" && edithi "$j"
		elif [[ $j == '\E' ]]
		then
			nospace=1
		elif [[ $j == '\S' ]]
		then
			printf ' '
		elif [[ $escaped -eq 1 ]]
		then
			[[ $edesch -eq 0 ]] \
				&& printf "%s" "$j" \
				|| printf "%s" "$(edithi "$j")"
			if [[ $nospace -eq 0 ]]
			then
				[[ $first -eq 0 ]] && printf ' '
				[[ $first -eq 1 ]] \
					&& printf ' ' && first=0
			else
				nospace=0
			fi
		else
			printf "%s" "$(edithi "$j")"
			if [[ $nospace -eq 0 ]]
			then
				[[ $first -eq 0 ]] && printf ' '
				[[ $first -eq 1 ]] \
					&& printf ' ' && first=0
			else
				nospace=0
			fi
		fi
	done

	echo
}

function editpresent {
	[[ -z $fn ]] && return 1
	local lines="$1"
	[[ -z $lines ]] && return 2
	local text=
	local n=1
	local rows=
	local cols=
	local in_table=0
	local is_hidden=0
	local table_content=
	local edcmd_orig="$edcmd"
	read -r rows cols < <(stty size)
	[[ -z $rows ]] && return 3
	[[ -z $cols ]] && return 3
	local old_ifs="$IFS"
	local IFS=$'\n'
	for i in $lines
	do
		if [[ $in_table -eq 1 ]] && ! [[ $i =~ \#\+end_table ]]
		then
			[[ -z $table_content ]] \
				&& table_content="$i" \
				|| table_content="$table_content
$i"
		elif [[ $i =~ \#\+end_hidden ]]
		then
			if [[ $edhidden -eq 1 ]]
			then
				is_hidden=0
			else
				[[ -z $text ]] && text="$i" || text="$text
$i"
			fi
		elif [[ $is_hidden -eq 1 ]]
		then
			continue
		elif [[ $i =~ \.(png|PNG|jpg|JPG|jpeg|JPEG|gif|GIF|tiff|TIFF\
			|xpm|XPM|svg|SVG)$ ]] && [[ $edimg -eq 1 ]]
		then
			edithi "$text"
			[[ $i =~ ^[0-9] ]] && editimg "${i/*$'\t'/}" || editimg "$i"
			text=
		elif [[ ${i/*$'\t'/} =~ ^\#\+begin_src ]] || [[ $i =~ \#\+begin_src ]]
		then
			edithi "$text"
			edithi "$i"
			text=
			block_syntax="${i#*\ }"
			block_syntax="${block_syntax/\ */}"
		elif [[ ${i/*$'\t'/} =~ ^\#\+end_src ]] || [[ $i =~ \#\+end_src ]]
		then
			edithi "$text"
			text=
			block_syntax=
			edithi "$i"
		elif [[ $i =~ \[\[\\[0-9][0-9][0-9]\[.*\ .*\]\] ]] && [[ $edesc -eq 1 ]]
		then
			edithi "$text"
			text=
			editescape "$i"
		elif [[ $i =~ \[\[include:.*\]\] ]]
		then
			edithi "$text"
			text=
			if [[ $edinclude -eq 1 ]]
			then
				local file="${i/*\[\[include:/}"
				file="${file/\]\]*/}"
				local arg="a"
				if [[ $file =~ : ]]
				then
					arg="${file/*:/}"
					file="${file/:*/}"
				fi

				[[ $file =~ ^% ]] && file="$(cortex-db -q "$file")"
				[[ -f $file ]] && [[ -n $arg ]] \
					&& local command="edtmux=$edtmux " \
					&& command="$command edty=$edty " \
					&& command="$command edtysleep=$edtysleep " \
					&& command="$command edimg=$edimg " \
					&& command="$command edsyntax=$edsyntax " \
					&& command="$command edesc=$edesc " \
					&& command="$command edinclude=$edinclude " \
					&& command="$command edtables=$edtables " \
					&& command="$command edhidden=$edtables " \
					&& command="$command edesch=$edesch " \
					&& command="$command edecesch=$edecesch " \
					&& command="$command edcmd=p " \
					&& command="$command editshow \"$arg\" \"$file\"" \
					&& bash -ic "$command"
			else
				edithi "$i"
			fi
		elif [[ $i =~ \#\+table ]]
		then
			edithi "$text"
			text=
			if [[ $edtables -eq 1 ]]
			then
				in_table=1
			else
				[[ -z $text ]] && text="$i" || text="$text
$i"
			fi
		elif [[ $i =~ \#\+end_table ]]
		then
			if [[ $edtables -eq 1 ]]
			then
				in_table=0
				edittable "$table_content"
				table_content=
			else
				[[ -z $text ]] && text="$i" || text="$text
$i"
			fi
		elif [[ $i =~ \#\+hidden ]]
		then
			if [[ $edhidden -eq 1 ]]
			then
				edithi "$text"
				text=
				is_hidden=1
			else
				[[ -z $text ]] && text="$i" || text="$text
$i"
			fi
		else
			[[ -z $text ]] && text="$i" || text="$text
$i"
			if [[ $n -eq $rows ]]
			then
				edithi "$text"
				n=1
				text=
			fi

			n="$((n + 1))"
		fi
	done

	[[ -n $text ]] && edithi "$text"
}

function editshow {
	if [[ -n $2 ]]
	then
		local fn="$2"
		[[ $fn =~ ^% ]] && fn="$(cortex-db -q "$fn")"
		local syntax=
		editsyntax "$fn"
		local fl="$fl"
		local fs=
		local edtmux=0
		local edty=0
	fi

	[[ -z $fn ]] && return 1
	[[ ${fn:0:1} != '/' ]] && fn="$PWD/$fn"
	[[ -d $fn ]] && return 1
	fs="$(wc -l "$fn" | cut -d ' ' -f1)"
	[[ -z $fs ]] && return 2
	[[ -z $pagesize ]] && pagesize=20
	[[ -z $fl ]] && fl=1
	! [[ $fl =~ [0-9]+ ]] && fl="$fs"
	local arg="$1"
	[[ -z $1 ]] && arg="+"
	local show=
	if [[ -n $fileresult_a ]] && [[ -n $fileresultindex ]]
	then
		if [[ $arg =~ f([0-9]+) ]]
		then
			local n=${arg//f/}
			if [[ $n -ge 0 ]] && [[ $n -le $((${#fileresult_a[@]}-1)) ]]
			then
				fileresultindex=$n
				fl="${fileresult_a[$fileresultindex]}"
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
				fileresultindex="$((${#fileresult[@]}-1))"
			elif [[ $fileresultindex -gt 0 ]]
			then
				fileresultindex="$((fileresultindex-1))"
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
				fileresultindex="$((fileresultindex+1))"
			fi

			fl="${fileresult[$fileresultindex]}"
			printf "$fileresultindex:"
			editshow $fl
			return
		elif [[ $arg == "s" ]]
		then
			[[ -n "$fileresult" ]] && edithi "$fileresult"
			return
		elif [[ $arg == "m" ]]
		then
			local asize=${#fileresult_a[@]}
			if [[ $fileresultindex -lt $((asize - 1)) ]]
			then
				local start="${fileresult_a[$fileresultindex]}"
				local end="$((${fileresult_a[$((fileresultindex + 1))]} - 1))"
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
		block_syntax=
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
			[[ $head -eq 1 ]] && block_syntax=
			show="edit ${head},${tail}$edcmd"
			fl="$tail"
		else
			[[ $arg =~ ^\+[0-9]+ ]] && arg="${arg/+/}" \
				&& arg="$((fl + arg))"
			[[ $arg =~ ^\-[0-9]+ ]] && arg="${arg/-/}" \
				&& arg="$((fl - arg))"
			[[ $arg -lt 1 ]] && arg="1"
			[[ $arg -gt $fs ]] && arg="$fs"
			[[ $arg -eq 1 ]] && block_syntax=
			show="edit ${arg}$edcmd"
			fl="$arg"
		fi
	elif [[ $arg =~ ^\/.*(,\/.*)? ]] && [[ -z $show ]]
	then
		if [[ $arg =~ , ]]
		then
			local head="${arg/,*/}"
			local tail="${arg/*,/}"
			[[ $head == "//" ]] \
				&& head="1" \
				|| head="$(editlocate "${head/\//}")"
			[[ $tail == "//" ]] \
				&& tail="$fs" \
				|| tail="$(editlocate "${tail/\//}" $((fl + 1)))"
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
			fl="$pagesize"
		else
			show="edit "$((fl - pagesize)),${fl}$edcmd""
			fl="$((fl - pagesize - 1))"
		fi
	elif [[ $arg == "b" ]]
	then
		block_syntax=
		show="edit "1,${pagesize}$edcmd""
		fl="$((pagesize + 1))"
	elif [[ $arg == "e" ]]
	then
		show="edit "$((fs - pagesize)),${fs}$edcmd""
		fl="$((fs - pagesize - 1))"
	elif [[ $arg == "a" ]]
	then
		block_syntax=
		show="edit ,$edcmd"
	elif [[ $arg == "c" ]]
	then
		local head="$((fl - (pagesize / 2)))"
		local tail="$((fl + (pagesize / 2)))"
		[[ $head -lt 1 ]] && head="1" \
			&& tail="$((tail + (pagesize / 2)))"
		[[ $tail -gt $fs ]] && tail="$fs"
		show="edit ${head},${tail}$edcmd"
	elif [[ $arg == "v" ]]
	then
		local rows=
		local cols=
		read -r rows cols < <(stty size)
		[[ -z $rows ]] && return 3
		[[ -z $cols ]] && return 3
		local head="$((fl + 1))"
		[[ $head -gt $fs ]] && head="$fs"
		local tail="$((fl + rows - 2))"
		if [[ $tail -eq $fs ]] || [[ $tail -gt $fs ]]
		then
			show="edit $fl,\$$edcmd"
			fl="$fs"
		else
			show="edit $head,$tail$edcmd"
			fl="$tail"
		fi
	fi

	if [[ -n $show ]]
	then
		eslastarg="$arg"
		eslast="$show"
		editpresent "$($show)"
	fi
}

function editappend {
	local data="$1"
	local res="$(edit "${fl}a\n$data\n.\nw")"
	[[ -n $res ]] && echo "$res"
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
	[[ $to == "$" ]] && to="$fs"
	[[ $to -gt $fs ]] && return 1
	local res=
	[[ -z $to ]] && res="$(edit "${fl}d\nw")" \
		|| res="$(edit "${fl},${to}d\nw")"
	[[ -n $res ]] && echo "$res"
	fs="$(wc -l "$fn" | cut -d ' ' -f1)"
	[[ $fl -gt $fs ]] && fl="$fs"
}

function editchange {
	[[ -z $1 ]] && return 1
	local data="$1"
	[[ -n $2 ]] && local to="$2"
	[[ $2 =~ ^\+[0-9]+ ]] && to="${2/\+/}" && to="$((fl + to))"
	[[ $to -gt $fs ]] && return 2
	local res=
	[[ -z $to ]] && res="$(edit "${fl}c\n$data\n.\nw")" \
		|| res="$(edit "${fl},${to}c\n$data\n.\nw")"
	[[ -n $res ]] && echo "$res"
	[[ -z $to ]] && editshow l || editshow ${fl},$to
}

function editsub {
	[[ -z $1 ]] && return 1
	[[ -n $3 ]] && local to="$3"
	[[ $to =~ ^\+[0-9]+ ]] && to="${to/\+/}" && to="$((fl + to))"
	[[ $to == '%' ]] && to="$fs"
	[[ $to -gt $fs ]] && return 2
	local in="$1"
	local out="$2"
	in="${in//\\\\/\\\\\\\\}"
	in="${in//\\N/\\\\\\n}"
	out="${out//\\\\/\\\\\\\\}"
	out="${out//\\N/\\\\\\n}"
	local pattern="s/$in/$out/"
	[[ $4 == "g" ]] && pattern="${pattern}g"
	local res=
	if [[ -z $to ]] || [[ $to == " " ]]
	then
		res="$(edit "$fl$pattern\nw")"
	else
		local lines="${fl},${to}"
		[[ $3 == "%" ]] && lines="1,${fs}"
		res="$(edit "$lines$pattern\nw")"
	fi

	[[ -n $res ]] && echo "$res"
	editshow l
}

function editjoin {
	local l=
	[[ -z $1 ]] && l="$((fl + 1))"
	[[ $1 =~ ^\+[0-9]+ ]] && l="${1/\+/}" && l="$((fl + l))"
	[[ $l -gt $fs ]] && return 1
	local res=
	[[ -n $l ]] && res="$(edit "${fl},${l}j\nw")" && editshow ${fl}
	[[ -n $res ]] && echo "$res"
}

function editmove {
	local dest="$1"
	[[ -z $1 ]] && dest="$((fl + 1))"
	[[ $dest =~ ^\+[0-9]+ ]] && dest="${1/\+/}" && dest="$((fl + dest))"
	[[ $dest =~ ^\-[0-9]+ ]] && dest="${1/\-/}" && dest="$((fl - dest))"
	[[ $dest == "$" ]] && dest="$fs"
	[[ $dest -gt $fs ]] && return 1
	[[ $dest -lt 1 ]] && return 1
	local to="$2"
	[[ $to =~ ^\+[0-9]+ ]] && to="${dest/\+/}" && to="$((fl + l))"
	[[ $to == "$" ]] && to="$fs"
	local res=
	[[ -n $to ]] && res="$(edit "${fl},${to}m$dest\nw")" \
		|| res="$(edit "${fl}m$dest\nw")"
	[[ -n $res ]] && echo "$res"
}

function edittransfer {
	yank=
	local line="$1"
	[[ $1 == "." ]] && line="$fl"
	[[ $1 == '$' ]] && line="$fs"
	local n=
	[[ -n $2 ]] && n="$2" \
		&& [[ $n =~ ^\+ ]] && n="${n/\+/}" && n="$((fl + n))"
	if [[ $line -gt 0 ]]
	then
		local res=
		[[ -n $n ]] && res="$(edit "${fl},${n}t$line\nw")" \
			|| res="$(edit "${fl}t$line\nw")"
		[[ -n $res ]] && echo "$res"
		es $n
	elif [[ $1 -eq 0 ]] && [[ -n $n ]]
	then
		yank="$(edcmd=p edsyntax=0 edesch=1 editshow ${fl},$n)"
	else
		yank="$(edcmd=p edsyntax=0 edesch=1 editshow l)"
	fi

	[[ $3 == "x" ]] && [[ -n $yank ]] && echo "$yank" | xclip -i
}

function editlevel {
	local line=
	[[ -n $1 ]] \
		&& line="$(edsyntax=0 edcmd=p es $1)" \
		|| line="$(edsyntax=0 edcmd=p es l)"
	[[ -n $line ]] && echo "$line" | awk -F '\t' '{ print NF-1 }' || return 1
}

function editspaces {
	local n=0
	local line=
	[[ -n $1 ]] \
		&& line="$(edsyntax=0 edcmd=p es $1)" \
		|| line="$(edsyntax=0 edcmd=p es l)"
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

function editmore {
	[[ -z $fn ]] && return 1
	local line="$fl"
	[[ -n $1 ]] && line="$1"
	[[ $1 == "." ]] && line="$fl"
	[[ -n $2 ]] && local fn="$2"
	! [[ -f $fn ]] && return 2
	[[ $line == $fs ]] && line="1"
	[[ $line -gt $fs ]] && line="1"
	[[ $line -lt q ]] && line="1"
	edimg=0 edtmux=0 edty=0 editshow $line,$fs "$fn" | more -lf
}

function editmediaqueue {
	[[ $TERM_PROGRAM != "terminology" ]] && return 1
	if [[ -n $1 ]]
	then
		local fn="$1"
		[[ $fn =~ ^% ]] && fn="$(cortex-db -q "$fn")"
		local syntax=
		editsyntax "$fn"
		local fl="$fl"
		local fs=
		local edtmux=0
		local edty=0
	fi

	[[ -z $fn ]] && return 2
	[[ ${fn:0:1} != '/' ]] && fn="$PWD/$fn"
	[[ -d $fn ]] && return 2
	local media=""
	local old_ifs="$IFS"
	local IFS=$'\n'
	while read -r line
	do
		if [[ $line =~ \.(png|PNG|jpg|JPG|jpeg|JPEG|gif|GIF|tiff|TIFF\
			|xpm|XPM|svg|SVG|mp4|MP4|avi|AVI|webm|WEBM\
			flac|FLAC|mp3|MP3|ogg|OGG)$ ]]
		then
			local item="$line"
			[[ $item =~ ^% ]] && item="$(cortex-db -q "$item")"
			if [[ $item =~ ^\/ ]]
			then
				[[ -z $media ]] && media="$item" \
					|| media="$media $item"
			fi
		fi
	done < "$fn"

	IFS="$old_ifs"
	[[ -n $media ]] && tyq $media
}

function editfmt {
	[[ -n $4 ]] && local fn="$4"
	[[ -z $fn ]] && return 1
	local edecesch=0
	local region="$(editregion "$1" "$2" "$fn")"
	[[ $? -ne 0 ]] && return $?
	local begin="${region/,*/}"
	local end="${region/*,/}"
	[[ -z $begin ]] || [[ -z $end ]] && return 2
	local ln=0
	local size=80
	[[ -n $3 ]] && size="$3"
	local linesize=$size
	local IFS=$' '
	local lines=()
	while read -r line
	do
		for word in $line
		do
			if [[ $word =~ \[\[\\[0-9][0-9][0-9]\[.* ]]
			then
				lines[$ln]="${lines[$ln]} $word"
				linesize="$((linesize + ${#word} + 1))"
			elif [[ $word =~ \\[0-9][0-9][0-9]\[.* ]]
			then
				lines[$ln]="${lines[$ln]} $word"
				linesize="$((linesize + ${#word} + 1))"
			elif [[ $word =~ (\\S|\\E) ]]
			then
				lines[$ln]="${lines[$ln]} $word"
				linesize="$((linesize + ${#word} + 1))"
			elif [[ ${#lines[@]} -eq 0 ]]
			then
				lines[$ln]="$word "
				[[ $word =~ \.$ ]] && lines[$ln]="${lines[$ln]} "
			elif [[ $(echo "${lines[$ln]} $word" | wc -m) -ge $linesize ]]
			then
				lines+=("$word")
				ln="$((ln + 1))"
				linesize=$size
			else
				lines[$ln]="${lines[$ln]} $word"
				[[ $word =~ \.$ ]] && lines[$ln]="${lines[$ln]} "
			fi
		done
	done < "$editreadlines"

	local IFS=$'\n'
	local tempfile="$HOME/.edit/temp"
	for i in ${lines[@]}
	do
		[[ -f "$tempfile" ]] && echo "$i" >> "$tempfile" \
			|| echo "$i" > "$tempfile"
	done

	mv "$tempfile" "$editreadlines"
	local res="$(edit "${begin},${end}d\nw")"
	[[ -n $res ]] && echo "$res"
	editread 0 0 "$fn" $(($begin - 1))
}

function editexternal {
	[[ -n $3 ]] && local fn="$3"
	[[ -z $fn ]] && return 1
	local edecesch=0
	local region="$(editregion "$1" "$2" "$fn")"
	[[ $? -ne 0 ]] && return $?
	local begin="${region/,*/}"
	local end="${region/*,/}"
	[[ -z $begin ]] || [[ -z $end ]] && return 2
	$EDITOR "$editreadlines"
	local res="$(edit "${begin},${end}d\nw")"
	[[ -n $res ]] && echo "$res"
	editread 0 0 "$fn" $(($begin - 1))
}

function edittable_printline {
	local cellsize="$2"
	local columns="$3"
	for ((i=0; i < $columns; ++i))
	do
		local data="${edtablematrix[$1,$i]}"
		printf "%s" "$edtable_vertical"
		printf "%s" "$data"
		for ((j=${#data}; j < $cellsize; j++))
		do
			printf ' '
		done
	done
}

function edittable_printboxline {
	local left_corner="$1"
	local right_corner="$2"
	local middle="$3"
	local horizontal="$4"
	local columns="$6"
	local cellsize="$5"
	printf "%s" "$left_corner"
	for ((i=0; i < $6; ++i))
	do
		for ((j=0; j < $cellsize; ++j))
		do
			printf "%s" "$horizontal"
		done

		[[ $i -ne $(($columns - 1 )) ]] && printf "%s" "$middle"
	done

	printf "%s\n" "$right_corner"
}

function edittable_printbox {
	local location="$1"
	local cellsize="$3"
	local columns="$4"
	local lines="$5"
	if [[ $edtable_ascii -eq 1 ]]
	then
		local edtable_top_left="$edtable_top_left_a"
		local edtable_top_right="$edtable_top_right_a"
		local edtable_middle_left="$edtable_middle_left_a"
		local edtable_middle_right="$edtable_middle_right_a"
		local edtable_middle_top="$edtable_middle_top_a"
		local edtable_middle_middle="$edtable_middle_middle_a"
		local edtable_bottom_left="$edtable_bottom_left_a"
		local edtable_bottom_right="$edtable_bottom_right_a"
		local edtable_bottom_middle="$edtable_bottom_middle_a"
		local edtable_horizontal="$edtable_horizontal_a"
		local edtable_vertical="$edtable_vertical_a"
	fi

	if [[ $location == "top" ]]
	then
		edittable_printboxline "$edtable_top_left" "$edtable_top_right" \
			"$edtable_middle_top" "$edtable_horizontal" "$cellsize" \
			"$columns"
	fi

	edittable_printline "$2" "$3" "$4"
	printf "%s\n" "$edtable_vertical"
	if [[ $location == "top" ]] || [[ $location == "middle" ]] \
		&& [[ $lines -gt 1 ]]
	then
		edittable_printboxline "$edtable_middle_left" \
			"$edtable_middle_right" "$edtable_middle_middle" \
			"$edtable_horizontal" "$cellsize" "$columns"
	fi

	if [[ $location == "bottom" ]] || [[ $lines -eq 1 ]]
	then
		edittable_printboxline "$edtable_bottom_left" \
			"$edtable_bottom_right" "$edtable_bottom_middle" \
			"$edtable_horizontal" "$cellsize" "$columns"
	fi
}

function edittable {
	[[ -z $1 ]] && return 1
	local IFS=$'\n'
	local table=()
	for i in $1
	do
		local l="$i"
		if [[ $edcmd == "n" ]]
		then
			l="${l#*$'\t'}"
		fi

		table+=("$l")
	done

	local cellsize=0
	local columns=0
	local lines=0
	unset edtablematrix
	declare -A edtablematrix
	local IFS=$'\t'
	for ((i=0; i < ${#table[@]}; ++i))
	do
		local n=0
		for j in ${table[$i]}
		do
			[[ ${#j} -gt $cellsize ]] && cellsize="${#j}"
			[[ -n $j ]] && edtablematrix[$i,$n]="$j"
			n=$((n + 1))
			[[ $n -gt $columns ]] && columns=$n
		done

		lines=$((lines + 1))
	done

	local n=0
	while true
	do
		local location="top"
		[[ $n -ge 1 ]] && location="middle"
		[[ $n -eq $((lines - 1)) ]] && [[ ${#table[@]} -gt 1 ]] \
			&& location="bottom"
		edittable_printbox "$location" "$n" "$cellsize" "$columns" \
			"${#table[@]}"
		n=$((n + 1))
		[[ $n -eq $lines ]] && break
	done
}

function ea { editappend "$@"; }
function ech { editchange "$@"; }
function ec { editcmd "$@"; }
function edel { editdelete "$@"; }
function ee { editexternal "$@"; }
function efl { editlocate "$@"; }
function efmt { editfmt "$@"; }
function ef { editfind "$@"; }
function ei { editinsert "$@"; }
function ej { editjoin "$@"; }
function els { editspaces "$@"; }
function el { editlevel "$@"; }
function em { editmove "$@"; }
function emore { editmore "$@"; }
function emq { editmediaqueue "$@"; }
function eo { editopen "$@"; }
function eq { editclose "$@"; }
function er { editread "$@"; }
function esu { editsub "$@"; }
function es { editshow "$@"; }
function et { editstore "$@"; }
function eu { editundo "$@"; }
function ey { edittransfer "$@"; }
function e { edit "$@"; }

