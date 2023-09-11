#!/usr/bin/env bash

# files and directories
editdir="$HOME/.edit"
editreadlines="$editdir/readlines"

# edit
edcmd="n"

# color
edcolor=0

# bind key for editwords
editwordkey="o"

#fzf
edfzfsize="80%"

mkdir -p "$editdir"

function _editwindow {
	local IFS=$' \t\n'
	local window=
	local pane=
	local session="$(tmux display-message -p '#S')"
	for i in $(tmux lsp -s -t "$session:0" -F '#I::#D #T')
	do
		if [[ $i == $1 ]] && [[ -n $window ]] && [[ -n $pane ]]
		then
			if [[ $3 == 'n' ]]
			then
				tmux select-window -t "$session:$window"
				tmux select-pane -t "$pane"
				tmux send-keys -t "$pane" "fn=\"$1\"" Enter
				tmux send-keys -t "$pane" \
					"cd \"\$(dirname \"\$fn\")\"" Enter
				tmux send-keys -t "$pane" "fl=1" Enter
				tmux send-keys -t "$pane" \
					"[[ -f \$PWD/.bashed ]] " \
					"&& source \$PWD/.bashed" Enter
				tmux send-keys -t "$pane" "clear" Enter
				[[ -n $2 ]] \
					&& tmux send-keys \
					"_editarg \"$2\" \"$pane\"" Enter \
					|| tmux send-keys "editshow 1" Enter
				return
			else
				tmux select-window -t "$session:$window"
				tmux select-pane -t "$pane"
				[[ -n $2 ]] && _editarg "$2" "$pane"
				return 1
			fi
		fi

		window="${i/::*/}"
		pane="${i/*::/}"
	done
}

function edit {
	[[ -n $2 ]] && local fn="$2" && fn="$(readlink -f "$fn")"
	[[ -z $fn ]] && return 1
	[[ -z $1 ]] && return 2
	[[ ${fn:0:1} != '/' ]] && fn="$PWD/$fn"
	result="$(echo -e "$1" | ed -s "$fn")"
	echo "$result"
	fs="$(wc -l "$fn" | cut -d ' ' -f1)"
}

function _editread {
	if [[ $1 != 0 ]] && [[ $2 != 0 ]] && [[ $3 != 0 ]]
	then
		[[ -n $3 ]] && local fn="$3" && fn="$(readlink -f "$fn")"
		[[ -z $fn ]] && return 1
		[[ ${fn:0:1} != '/' ]] && fn="$PWD/$fn"
		local lines=
		edit "${1},${2}p" "$fn" > "$editreadlines"
	fi

	if [[ -n $4 ]] && [[ -f $editreadlines ]]
	then
		local res=
		if [[ -n $5 ]]
		then
			local f="$5" && f="$(readlink -f "$f")"
			[[ -z $f ]] && return 1
			[[ ${f:0:1} != '/' ]] && f="$PWD/$f"
			res="$(edit "${4}r $editreadlines\nw" "$f")"
		else
			res="$(edit "${4}r $editreadlines\nw")"
		fi

		[[ -n $res ]] && echo "$res"
	fi
}

function _editline {
	local l="${1:-$fl}"
	[[ -z $l ]] && return 1
	if [[ -n $fl ]]
	then
		[[ $l == "." ]] && l="$fl"
		[[ $l =~ ^\+ ]] && l="${l/+/}" && l="$((fl + l))"
		[[ $l =~ ^\- ]] && l="${l/-/}" && l="$((fl - l))"
		[[ $l =~ ^\-[0-9]+ ]] && l="${l/-/}" && l="$((fl - l))"
		[[ $l =~ ^\+[0-9]+ ]] && l="${l/+/}" && l="$((fl + l))"
	fi

	if [[ -n $fs ]]
	then
		[[ $l == "$" ]] && l="$fs"
		[[ $l -gt $fs ]] && l=$fs
	fi

	[[ $l -lt 1 ]] && l=1
	echo "$l"
}

function editcopy {
	local s=${1:-$fl}
	local e=${2:-$fl}
	local f="${5:-$fn}"
	[[ -z $s ]] && return 2
	[[ -z $e ]] && return 3
	f="$(readlink -f "$f")"
	[[ -z $f ]] && return 1
	[[ ${fn:0:1} != '/' ]] && fn="$PWD/$fn"
	s="$(_editline "$s")"
	e="$(_editline "$e")"
	_editread $s $e "$fn"
	[[ $3 == x ]] && cat "$editreadlines" | xclip -r -i
	[[ $3 == w ]] && cat "$editreadlines" | wl-copy
	[[ $4 == cut ]] && editdelete $e "$f"
	[[ $f == $fn ]] && es l || es l $f
}

function editpaste {
	local s=${1:-$fl}
	[[ -z $s ]] && return 2
	local f="${3:-$fn}"
	f="$(readlink -f "$f")"
	[[ -z $f ]] && return 1
	s="$(_editline "$s")"
	[[ $2 == x ]] && xclip -r -o > "$editreadlines"
	[[ $2 == w ]] && wl-paste > "$editreadlines"
	[[ $2 != x ]] && [[ $2 != w ]] && _editread 0 0 0 $s "$f"
	[[ $f == $fn ]] && es "$((s+1))" || es l $f
}

function editcmd {
	[[ -n $4 ]] && local fn="$4" && fn="$(readlink -f "$fn")"
	[[ -z $fn ]] && return 1
	[[ -z $3 ]] && return 2
	[[ -z $1 ]] && return 3
	[[ -z $2 ]] && return 4
	local begin="$(_editline "$1")"
	local end="$(_editline "$2")"
	local region="$(editcopy $begin $end "$fn")"
	[[ $? -ne 0 ]] && return $?
	local tempfile="$editdir/temp"
	cat "$editreadlines" | $3 > "$tempfile"
	mv "$tempfile" "$editreadlines"
	local res="$(edit "$begin,${end}d\nw" "$fn")"
	[[ -n $res ]] && echo "$res"
	editpaste $(($begin - 1)) "$fn"
}

function _editarg {
	[[ -z $1 ]] && return 1
	argument="$1"
	local session="$(tmux display-message -p '#S')" \
	local pane="$2"
	pane="$session"
	if [[ $argument =~ ^[0-9]+$ ]]
	then
		tmux send-keys -t "$pane" "es $argument" Enter
	else
		tmux send-keys -t "$pane" \
			"es \$(e \"/${argument}/n\" | cut -f1)" Enter
	fi
}

function editopen {
	if [[ -n $1 ]]
	then
		local argument="${1#*:}"
		local f="${1/:*/}"
		[[ $f == $argument ]] && argument=
	fi

	[[ -z $f ]] && return 1
	[[ ${f:0:1} != '/' ]] && f="$PWD/$f"
	f="$(readlink -f "$f")"
	! [[ -f $f ]] && return 2
	_editwindow "$f" "$argument"
	[[ $? -eq 1 ]] && return 3
	if tmux run 2>/dev/null
	then
		tmux bind-key $editwordkey run -b \
			"bash -ic \"fn=\"$f\" editwords\""
	else
		return 4
	fi

	[[ $2 == 'u' ]] && tmux splitw -b -c "$f"
	[[ $2 == 'd' ]] && tmux splitw -c "$f"
	[[ $2 == 'l' ]] && tmux splitw -b -c "$f" -h
	[[ $2 == 'r' ]] && tmux splitw -c "$f" -h
	[[ $2 == 'n' ]] && tmux neww -c "$f"
	[[ $2 == 'ul' ]] && tmux select-pane -U && tmux splitw -b -c "$f" -h
	[[ $2 == 'ur' ]] && tmux select-pane -U && tmux splitw -c "$f" -h
	[[ $2 == 'dl' ]] && tmux select-pane -U && tmux splitw -b -c "$f" -h
	[[ $2 == 'dr' ]] && tmux select-pane -U && tmux splitw -c "$f" -h
	[[ $2 == 'ld' ]] && tmux select-pane -L && tmux splitw -c "$f"
	[[ $2 == 'lu' ]] && tmux select-pane -L && tmux splitw -b -c "$f"
	[[ $2 == 'rd' ]] && tmux select-pane -R && tmux splitw -c "$f"
	[[ $2 == 'ru' ]] && tmux select-pane -L && tmux splitw -b -c "$f"
	tmux select-pane -T "$f"
	if [[ -z $2 ]]
	then
		fn="$f"
		cd "$(dirname "$fn")"
		fl=1
		[[ -f $PWD/.bashed ]] && source "$PWD/.bashed"
		[[ -n $argument ]] \
			&& _editarg "$argument" \
			|| editshow 1
		tmux select-pane -T "$f"
	else
		_editwindow "$f" "$argument" n
	fi
}

function editclose {
	[[ -n $fn ]] && fn=
	[[ -n $fl ]] && fl=
	[[ -n $fs ]] && fs=
	[[ -n $fileresult ]] && fileresult=
	[[ -n $fileresultindex ]] && fileresultindex=
	[[ -n $fileresult_a ]] && fileresult_a=
	tmux select-pane -T "$(hostname)"
}

function editfind {
	[[ -z $1 ]] && return 1
	[[ -z $fn ]] && return 2
	local result="$(edit "$1" "$fn")"
	[[ -z $result ]] && return
	fileresult_a=()
	fileresultindex=-1
	fileresult=
	local IFS=$'\n'
	local counter=0
	local color=1
	for i in $result
	do
		fileresult_a+=("${i/$'\t'*/}")
		local data="$counter:${i/$'\t'/ }"
		[[ -z $fileresult ]] \
			&& fileresult="$counter:$data" \
			|| fileresult="$fileresult
$data"
		counter=$((counter+1))
	done

	if [[ -n "$fileresult" ]]
	then
		if [[ $2 == fz ]]
		then
			local zres="$(echo "$fileresult" \
				| fzf-tmux -p $edfzfsize,$edfzfsize)"
			if [[ $zres ]]
			then
				fileresultindex="${zres/:*/}"
				fl="${fileresult_a[$fileresultindex]}"
				printf -- '%s' "$fileresultindex:"
				editshow ${fl}
			fi
		else
			echo "$fileresult"
		fi
	fi
}

function editlocate {
	[[ -n $3 ]] && local fn="$3" && fn="$(readlink -f "$fn")"
	[[ -z $fn ]] && return 1
	[[ -z $1 ]] && return 2
	[[ -n $2 ]] && local fl="$2"
	local pattern="$1"
	[[ $1 =~ ^\/ ]] && pattern="${pattern/\//}"
	local to="$(edsyntax=0 \
		ef "${fl},${fs}g/$pattern/n" | head -n1)"
	to="${to/\ */}"
	to="${to/*:/}"
	echo "$to"
}

function editshow {
	if [[ -n $2 ]]
	then
		local fn="$2"
		fn="$(readlink -f "$fn")"
		local fl="$fl"
		local fs=
	fi

	[[ -z $fn ]] && return 1
	[[ ${fn:0:1} != '/' ]] && fn="$PWD/$fn"
	[[ -d $fn ]] && return 2
	if tmux run 2>/dev/null
	then
		tmux bind-key $editwordkey run -b \
			"bash -ic \"fn=\"$fn\"; editwords\""
	else
		return 3
	fi

	fs="$(wc -l "$fn" | cut -d ' ' -f1)"
	[[ -z $fs ]] && return 3
	[[ -z $pagesize ]] && pagesize=20
	[[ -z $fl ]] && fl=1
	! [[ $fl =~ [0-9]+ ]] && fl="$fs"
	local arg="$1"
	[[ -z $1 ]] && arg="+"
	local IFS=$' \t\n'
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
				printf -- '%s' "$fileresultindex:"
				editshow ${fl}
			else
				echo "?"
			fi

			return
		elif [[ $arg == u ]]
		then
			if [[ $fileresultindex -eq 0 ]] || [[ $fileresultindex -eq -1 ]]
			then
				fileresultindex="$((${#fileresult_a[@]} - 1))"
			elif [[ $fileresultindex -gt 0 ]]
			then
				fileresultindex="$((fileresultindex - 1))"
			fi

			fl="${fileresult_a[$fileresultindex]}"
			printf "$fileresultindex:"
			editshow $fl
			return
		elif [[ $arg == d ]]
		then
			if [[ $fileresultindex -eq $((${#fileresult_a[@]} - 1)) ]]
			then
				fileresultindex=0
			elif [[ $fileresultindex -lt $((${#fileresult_a[@]} - 1)) ]]
			then
				fileresultindex="$((fileresultindex + 1))"
			fi

			fl="${fileresult_a[$fileresultindex]}"
			printf "$fileresultindex:"
			editshow $fl
			return
		elif [[ $arg == s ]]
		then
			[[ -n "$fileresult" ]] && echo "$fileresult"
			return
		elif [[ $arg == m ]]
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
		elif [[ $arg == fz ]]
		then
			[[ -n "$fileresult" ]] \
				&& local zres="$(echo "$fileresult" \
					| fzf-tmux -p $edfzfsize,$edfzfsize)"
			if [[ -n $zres ]]
			then
				fileresultindex="${zres/:*/}"
				fl="${fileresult_a[$fileresultindex]}"
				printf -- '%s' "$fileresultindex:"
				editshow ${fl}
			fi

			return
		fi
	fi

	if [[ $arg == r ]]
	then
		if [[ -n $eslast ]] && [[ ${eslast:0-1} != $edcmd ]]
		then
			[[ ${eslast:0-1} == "p" ]] \
				&& eslast="${eslast/%p/n}" \
				|| eslast="${eslast/%n/p}"
		fi

		show="$eslast"
	elif [[ $arg == $ ]] || [[ $arg == "G" ]]
	then
		fl="$fs"
		show="edit ${fl}$edcmd"
	elif [[ $arg == g ]]
	then
		fl="1"
		show="edit ${fl}$edcmd"
	elif [[ $arg =~ ^([.+-]?([0-9]+)?)(,[$+]?([0-9]+)?)?$ ]] \
		&& [[ $arg != . ]]
	then
		[[ $arg == + ]] && arg="$((fl + 1))"
		[[ $arg == - ]] && arg="$((fl - 1))"
		if [[ $arg =~ , ]]
		then
			local head="${arg/,*/}"
			local tail="${arg/*,/}"
			head="$(_editline "$head")"
			tail="$(_editline "$tail")"
			show="edit ${head},${tail}$edcmd"
			fl="$tail"
		else
			arg="$(_editline "$arg")"
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
	elif [[ $arg == l ]] || [[ $arg == . ]]
	then
		show="edit ${fl}$edcmd"
	elif [[ $pagesize -ge $fs ]]
	then
		show="edit "1,${fs}$edcmd""
	elif [[ $arg == n ]]
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
	elif [[ $arg == p ]]
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
	elif [[ $arg == b ]]
	then
		show="edit "1,${pagesize}$edcmd""
		fl="$((pagesize + 1))"
	elif [[ $arg == e ]]
	then
		show="edit "$((fs - pagesize)),${fs}$edcmd""
		fl="$((fs - pagesize - 1))"
	elif [[ $arg == a ]]
	then
		show="edit ,$edcmd"
	elif [[ $arg == c ]]
	then
		local head="$((fl - (pagesize / 2)))"
		local tail="$((fl + (pagesize / 2)))"
		[[ $head -lt 1 ]] && head="1" \
			&& tail="$((tail + (pagesize / 2)))"
		[[ $tail -gt $fs ]] && tail="$fs"
		show="edit ${head},${tail}$edcmd"
	elif [[ $arg == v ]]
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
		if [[ $edcolor -ne 0 ]]
		then
			printf -- '%b' "\033[${edcolor}m"
			$show
			printf -- '%b' "\033[0m"
		else
			$show
		fi
	fi

	return 0
}

function editappend {
	[[ -z $fn ]] && return 1
	[[ -z $fl ]] && return 2
	local data="$@"
	local line=$fl
	[[ $fs -eq 0 ]] && line=$((line - 1))
	local res="$(edit "${line}a\n$data\n.\nw" "$fn")"
	[[ -n $res ]] && echo "$res"
	editshow "+$(echo -e "$data" | grep -c "^")"
}

function editinsert {
	[[ -z $fl ]] && return 1
	fl="$((fl - 1))"
	editappend "$@"
}

function editdelete {
	[[ -n $2 ]] && local fn="$2" && fn="$(readlink -f "$fn")"
	[[ -z $fn ]] && return 1
	[[ -z $fl ]] && return 2
	[[ -n $1 ]] && local to="$(_editline "$1")"
	local res=
	[[ -z $to ]] && res="$(edit "${fl}d\nw" "$fn")" \
		|| res="$(edit "${fl},${to}d\nw" "$fn")"
	[[ -n $res ]] && echo "$res"
	fs="$(wc -l "$fn" | cut -d ' ' -f1)"
	[[ $fl -gt $fs ]] && fl="$fs"
}

function editchange {
	[[ -n $3 ]] && local fn="$3" && fn="$(readlink -f "$fn")"
	[[ -z $fn ]] && return 1
	[[ -z $1 ]] && return 2
	[[ -z $fl ]] && return 3
	local data="$1"
	[[ -n $2 ]] && local to="$(_editline "$2")"
	local res=
	[[ -z $to ]] && res="$(edit "${fl}c\n$data\n.\nw" "$fn")" \
		|| res="$(edit "${fl},${to}c\n$data\n.\nw" "$fn")"
	[[ -n $res ]] && echo "$res"
	[[ -z $to ]] && editshow l || editshow ${fl},$to
}

function editchangeline {
	[[ -z $fn ]] && return 1
	[[ -z $1 ]] && return 2
	[[ -z $fl ]] && return 3
	local data="$@"
	res="$(edit "${fl}c\n$data\n.\nw" "$fn")"
	[[ -n $res ]] && echo "$res"
	editshow l
}

function editsub {
	[[ -n $5 ]] && local fn="$4" && fn="$(readlink -f "$fn")"
	[[ -z $fn ]] && return 1
	[[ -z $1 ]] && return 2
	[[ -n $3 ]] && local to="$(_editline "$3")"
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
		res="$(edit "$fl$pattern\nw" "$fn")"
	else
		local lines="${fl},${to}"
		[[ $3 == "%" ]] && lines="1,${fs}"
		res="$(edit "$lines$pattern\nw" "$fn")"
	fi

	[[ -n $res ]] && echo "$res"
	editshow l
}

function editjoin {
	[[ -n $2 ]] && local fn="$2" && fn="$(readlink -f "$fn")"
	[[ -z $fn ]] && return 1
	[[ -z $fl ]] && return 2
	local l=
	[[ -z $1 ]] && l="$((fl + 1))"
	l="$(_editline "$l")"
	local res=
	[[ -n $l ]] && res="$(edit "${fl},${l}j\nw" "$fn")" && editshow ${fl}
	[[ -n $res ]] && echo "$res"
}

function editmove {
	[[ -n $3 ]] && local fn="$3" && fn="$(readlink -f "$fn")"
	[[ -z $fn ]] && return 1
	[[ -z $fl ]] && return 2
	local dest="$1"
	[[ -z $1 ]] && dest="$((fl + 1))"
	dest="$(_editline "$dest")"
	[[ $dest -gt $fs ]] && return 3
	[[ $dest -lt 1 ]] && return 4
	[[ -n $2 ]] && local to="$(_editline "$2")"
	local res=
	[[ -n $to ]] && res="$(edit "${fl},${to}m$dest\nw" "$fn")" \
		|| res="$(edit "${fl}m$dest\nw" "$fn")"
	[[ -n $res ]] && echo "$res"
}

function edittransfer {
	[[ -n $3 ]] && local fn="$3" && fn="$(readlink -f "$fn")"
	[[ -z $fn ]] && return 1
	[[ -z $1 ]] && return 2
	yank=
	local line="$(_editline "$1")"
	local n=
	[[ -n $2 ]] && n="$(_editline "$2")"
	if [[ $line -gt 0 ]]
	then
		local res=
		[[ -n $n ]] && res="$(edcmd=p edit "${fl},${n}t$line\nw" "$fn")" \
			|| res="$(edcmd=p edit "${fl}t$line\nw" "$fn")"
		[[ -n $res ]] && echo "$res"
		es $n
	elif [[ $1 -eq 0 ]] && [[ -n $n ]]
	then
		yank="$(edcmd=p editshow ${fl},$n)"
	else
		yank="$(edcmd=p editshow l)"
	fi
}

function editlevel {
	[[ -n $2 ]] && local fn="$2" && fn="$(readlink -f "$fn")"
	[[ -z $fn ]] && return 1
	[[ -z $1 ]] && return 2
	local line=
	[[ -n $1 ]] \
		&& line="$(es $1)" \
		|| line="$(es l)"
	[[ -n $line ]] && echo "$line" | awk -F '\t' '{ print NF-1 }' || return 1
}

function editspaces {
	[[ -n $2 ]] && local fn="$2" && fn="$(readlink -f "$fn")"
	[[ -z $fn ]] && return 1
	[[ -z $1 ]] && return 2
	local n=0
	local line=
	[[ -n $1 ]] \
		&& line="$(es $1)" \
		|| line="$(es l)"
	[[ -z $line ]] && return 3
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

function editexternal {
	[[ -n $3 ]] && local fn="$3" && fn="$(readlink -f "$fn")"
	[[ -z $fn ]] && return 1
	[[ -z $1 ]] && return 2
	[[ -z $2 ]] && return 3
	local begin="$(_editline "$1")"
	local end="$(_editline "$2")"
	local region="$(editcopy $begin $end "$fn")"
	[[ -z $begin ]] || [[ -z $end ]] && return 2
	$EDITOR "$editreadlines"
	local res="$(edit "${begin},${end}d\nw" "$fn")"
	[[ -n $res ]] && echo "$res"
	_editread 0 0 "$fn" $(($begin - 1))
}

function etermbin {
	[[ -z $1 ]] && return 1
	[[ -n $2 ]] && local fn="$2" && fn="$(readlink -f "$fn")"
	[[ -z $fn ]] && return 2
	edcmd=p edcolor=0 es $1 | nc termbin.com 9999
}

function _editfzf {
	local multiple="$1"
	shift
	local fzf="fzf-tmux -p ${edfzfsize},${edfzfsize}"
	[[ $multiple -eq 1 ]] \
		&& e_uresult=($(echo "$*" | sed 's/\ /\n/g' | sort | uniq | \
			$fzf --layout=reverse-list --cycle -m)) \
		|| e_uresult="$(echo "$*" | sed 's/\ /\n/g' | sort | uniq | \
			$fzf --layout=reverse-list --cycle)"
	return 0
}

function editwords {
	local f="${1:-$fn}"
	[[ -z $f ]] && return 1
	if tmux run 2>/dev/null
	then
		local words=($(edcolor=0 edcmd=p es a "$f"))
		local extension="${f/*l/}"
		local dict_words="$editdir/dict/words"
		local ext_words="$editdir/dict/$extension"
		local local_words="$(dirname $f)/.bashed-words"
		[[ -f $dict_words ]] \
			&& local dict="$(cat "$dict_words" | sed 's/\n/ /g')" \
			&& words=(${words[@]} $dict)
		[[ -f $ext_words ]] \
			&& local dict="$(cat "$ext_words" | sed 's/\n/ /g')" \
			&& words=(${words[@]} $dict)
		[[ -f $local_words ]] \
			&& local dict="$(cat "$local_words" | sed 's/\n/ /g')" \
			&& words=(${words[@]} $dict)
		_editfzf 0 0 "${words[@]}"
	else
		return 2
	fi

	[[ -n $e_uresult ]] && tmux send-keys -l "$e_uresult"
	return 0
}

function editwordsrc {
	local f="${1:-$fn}"
	[[ -z $f ]] && return 1
	if tmux run 2>/dev/null
	then
		tmux bind-key $editwordkey run -b \
			"bash -ic \"fn=\"$f\"; editwords\""
	else
		return 2
	fi
}

function ea { editappend "$@"; }
function ech { editchange "$@"; }
function echl { editchangeline "$@"; }
function ec { editcmd "$@"; }
function ecopy { editcopy "$@"; }
function edel { editdelete "$@"; }
function ee { editexternal "$@"; }
function efl { editlocate "$@"; }
function ef { editfind "$@"; }
function ei { editinsert "$@"; }
function ej { editjoin "$@"; }
function els { editspaces "$@"; }
function el { editlevel "$@"; }
function em { editmove "$@"; }
function eo { editopen "$@"; }
function epaste { editpaste "$@"; }
function eq { editclose "$@"; }
function esu { editsub "$@"; }
function es { editshow "$@"; }
function ew { editwords "$@"; }
function ews { editwordsrc "$@"; }
function ey { edittransfer "$@"; }
function e { edit "$@"; }

function _editappend {
	local cur=${COMP_WORDS[COMP_CWORD]}
	COMPREPLY=($(compgen -f -c -- $cur))
}

complete -o nospace -o filenames -o nosort -F _editappend editappend
complete -o nospace -o filenames -o nosort -F _editappend ea
complete -o nospace -o filenames -o nosort -F _editappend editinsert
complete -o nospace -o filenames -o nosort -F _editappend ei

function _editchangeline {
	local cur=${COMP_WORDS[COMP_CWORD]}
	local words=($(edcolor=0 edcmd=n es l))
	local word="${words[COMP_CWORD]}"
	[[ -n $word ]] \
		&& COMPREPLY=($(compgen -W "$word" -- $cur)) \
		|| COMPREPLY=($(compgen -f -- $cur))
}

complete -o nospace -o filenames -o nosort -F _editchangeline editchangeline
complete -o nospace -o filenames -o nosort -F _editchangeline echl

function _edcmd {
	local cur=${COMP_WORDS[COMP_CWORD]}
	case "$COMP_CWORD" in
		1)
			COMPREPLY=($(compgen -o nosort -W "{1..$fs} $ + ." -- $cur))
			;;
		2)
			COMPREPLY=($(compgen -o nosort -W "{1..$fs} $ + ." -- $cur))
			;;
		3)
			COMPREPLY=($(compgen -c))
			;;
		*)
			COMPREPLY=($(compgen -f -- $cur))
			;;
	esac
}

complete -o nospace -o filenames -F _edcmd edcmd
complete -o nospace -o filenames -F _edcmd ec

function _editcopy {
	local cur=${COMP_WORDS[COMP_CWORD]}
	case "$COMP_CWORD" in
		1)
			COMPREPLY=($(compgen -o nosort -W "{1..$fs} $ + ." -- $cur))
			;;
		2)
			COMPREPLY=($(compgen -o nosort -W "{1..$fs} $ + ." -- $cur))
			;;
		3)
			COMPREPLY=($(compgen -W "w x" -- $cur))
			;;
		4)
			COMPREPLY=($(compgen -W "cut" -- $cur))
			;;
		*)
			COMPREPLY=($(compgen -f -- $cur))
			;;
	esac
}

complete -o nospace -o filenames -F _editcopy editcopy
complete -o nospace -o filenames -F _editcopy ecopy

function _editdelete {
	local cur=${COMP_WORDS[COMP_CWORD]}
	case "$COMP_CWORD" in
		1)
			COMPREPLY=($(compgen -o nosort -W "{1..$fs} $ +" -- $cur))
			;;
		*)
			COMPREPLY=($(compgen -f -- $cur))
			;;
	esac
}

complete -o nospace -o filenames -F _editdelete editdelete
complete -o nospace -o filenames -F _editdelete edel

function _editexternal {
	local cur=${COMP_WORDS[COMP_CWORD]}
	case "$COMP_CWORD" in
		1)
			COMPREPLY=($(compgen -o nosort -W "{1..$fs} $ +" -- $cur))
			;;
		2)
			COMPREPLY=($(compgen -o nosort -W "{1..$fs} $ +" -- $cur))
			;;
		*)
			COMPREPLY=($(compgen -f -- $cur))
			;;
	esac
}

complete -o nospace -o filenames -F _editexternal editexternal
complete -o nospace -o filenames -F _editexternal ee

function _editfind {
	local cur=${COMP_WORDS[COMP_CWORD]}
	case "$COMP_CWORD" in
		2)
			COMPREPLY=($(compgen -o nosort -W "fz" -- $cur))
			;;
		*)
			COMPREPLY=($(compgen -f -- $cur))
			;;
	esac
}

complete -o nospace -o filenames -F _editfind editfind
complete -o nospace -o filenames -F _editfind ef

function _editjoin {
	local cur=${COMP_WORDS[COMP_CWORD]}
	case "$COMP_CWORD" in
		1)
			COMPREPLY=($(compgen -o nosort -W "{$fl..$fs} $ +" -- $cur))
			;;
		*)
			COMPREPLY=($(compgen -f -- $cur))
			;;
	esac
}

complete -o nospace -o filenames -F _editjoin editjoin
complete -o nospace -o filenames -F _editjoin ej

function _editmove {
	local cur=${COMP_WORDS[COMP_CWORD]}
	case "$COMP_CWORD" in
		1)
			COMPREPLY=($(compgen -o nosort -W "{1..$fs} $ +" -- $cur))
			;;
		2)
			COMPREPLY=($(compgen -o nosort -W "{$fl..$fs} $ +" -- $cur))
			;;
		*)
			COMPREPLY=($(compgen -f -- $cur))
			;;
	esac
}

complete -o nospace -o filenames -F _editmove editmove
complete -o nospace -o filenames -F _editmove em

function _editopen {
	local cur=${COMP_WORDS[COMP_CWORD]}
	case "$COMP_CWORD" in
		2)
			COMPREPLY=($(compgen -W "u d l r ul ur dl dr ru rd \
				lu ld" -- $cur))
			;;
		*)
			COMPREPLY=($(compgen -f -- $cur))
			;;
	esac
}

complete -o nospace -o filenames -F _editopen editopen
complete -o nospace -o filenames -F _editopen eo

function _editshow {
	local cur=${COMP_WORDS[COMP_CWORD]}
	case "$COMP_CWORD" in
		1)
			COMPREPLY=($(compgen -W "a b c d e f g G l m n p u v / \
				. $ + - {1..$fs} fz" -- $cur))
			;;
		*)
			COMPREPLY=($(compgen -f -- $cur))
			;;
	esac
}

complete -o nospace -o filenames -F _editshow editshow
complete -o nospace -o filenames -F _editshow es
complete -o nospace -o filenames -F _editshow etermbin

function _editpaste {
	local cur=${COMP_WORDS[COMP_CWORD]}
	case "$COMP_CWORD" in
		1)
			COMPREPLY=($(compgen -o nosort -W "{1..$fs} $ + ." -- $cur))
			;;
		2)
			COMPREPLY=($(compgen -o nosort -W "{1..$fs} $ + ." -- $cur))
			;;
		3)
			COMPREPLY=($(compgen -W "w x" -- $cur))
			;;
		*)
			COMPREPLY=($(compgen -f -- $cur))
			;;
	esac
}

complete -o nospace -o filenames -F _editpaste editpaste
complete -o nospace -o filenames -F _editpaste epaste

function _editsub {
	local cur=${COMP_WORDS[COMP_CWORD]}
	case "$COMP_CWORD" in
		3)
			COMPREPLY=($(compgen -W "% \'\'"))
			;;
		4)
			COMPREPLY=($(compgen -W "g \'\'"))
			;;
		*)
			COMPREPLY=($(compgen -f -- $cur))
			;;
	esac
}

complete -o nospace -o filenames -F _editsub editsub
complete -o nospace -o filenames -F _editsub esu

function _edittransfer {
	local cur=${COMP_WORDS[COMP_CWORD]}
	case "$COMP_CWORD" in
		1)
			COMPREPLY=($(compgen -o nosort -W "{1..$fs} . $" -- $cur))
			;;
		2)
			COMPREPLY=($(compgen -o nosort -W "{1..$fs} +" -- $cur))
			;;
		*)
			COMPREPLY=($(compgen -f -- $cur))
			;;
	esac
}

complete -o nospace -o filenames -F _edittransfer edittransfer
complete -o nospace -o filenames -F _edittransfer ey

