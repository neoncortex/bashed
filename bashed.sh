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

function _editline {
	local l="${1:-$fl}"
	[[ -n $2 ]] && local fs="$(wc -l "$2" | cut -d ' ' -f1)"
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
	s="$(_editline "$s" "$f")"
	e="$(_editline "$e" "$f")"
	local res="$(edit "${s},${e}p" "$f" > "$editreadlines")"
	[[ $3 == x ]] && cat "$editreadlines" | xclip -r -i
	[[ $3 == w ]] && cat "$editreadlines" | wl-copy
	[[ $4 == cut ]] && editdelete $s $e "$f"
	[[ $f == $fn ]] && es l
}

function editpaste {
	local s=${1:-$fl}
	[[ -z $s ]] && return 2
	local f="${3:-$fn}"
	f="$(readlink -f "$f")"
	[[ -z $f ]] && return 1
	s="$(_editline "$s" "$f")"
	[[ $2 == x ]] && xclip -r -o > "$editreadlines"
	[[ $2 == w ]] && wl-paste > "$editreadlines"
	[[ $2 != x ]] && local res="$(edit "${s}r $editreadlines\nw" "$f")"
	[[ $f == $fn ]] && es "$((s+1))"
}

function editcmd {
	[[ -n $4 ]] && local fn="$4" && fn="$(readlink -f "$fn")"
	[[ -z $fn ]] && return 1
	[[ -z $3 ]] && return 2
	[[ -z $1 ]] && return 3
	[[ -z $2 ]] && return 4
	local begin="$(_editline "$1")"
	local end="$(_editline "$2")"
	local region="$(editcopy $begin $end '' '' "$fn")"
	[[ $? -ne 0 ]] && return $?
	local tempfile="$editdir/temp"
	cat "$editreadlines" | $3 > "$tempfile"
	mv "$tempfile" "$editreadlines"
	local res="$(edit "$begin,${end}d\nw" "$fn")"
	[[ -n $res ]] && echo "$res"
	editpaste $(($begin - 1)) '' "$fn"
}

function _editarg {
	[[ -z $1 ]] && return 1
	argument="$1"
	local session="$(tmux display-message -p '#S')"
	local pane="$2"
	[[ $argument =~ ^[0-9]+$ ]] \
		&& tmux send-keys -t "$pane" "es $argument" Enter \
		|| tmux send-keys -t "$pane" \
			"es \$(e \"/${argument}/n\" | cut -f1)" Enter
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

function editfilefind {
	[[ -z $1 ]] && return 1
	[[ $2 == r ]] \
		&& local files="$(grep -HinRIs "$1" ".")" \
		|| local files="$(grep -HinIs "$1" ./*)"
	[[ -z $files ]] && return 2
	local res="$(echo "$files" | fzf-tmux -p $edfzfsize,$edfzfsize)"
	local name="${res/:*/}"
	local line="${res#*:}"
	line="${line/:*/}"
	[[ -n $name ]] && [[ -n $line ]] && editopen "$name:$line" $3
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

function editprint {
	edcmd=p edcolor=0 editshow "$@"
}

function editappend {
	[[ -z $fn ]] && return 1
	[[ -z $fl ]] && return 2
	local data="$@"
	[[ -z $data ]] && data="$(cat /dev/stdin)"
	[[ -z $data ]] && return 3
	local line=$fl
	[[ $fs -eq 0 ]] && fs="$(wc -l "$fn" | cut -d ' ' -f1)"
	[[ $fs -eq 0 ]] && [[ $line -eq 1 ]] && line=$((line - 1))
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
	local f="${3:-$fn}"
	[[ -n $3 ]] && f="$(readlink -f "$f")"
	[[ -z $f ]] && return 1
	local from="${1:-$fl}"
	[[ -z $from ]] && return 2
	from="$(_editline "$from" "$f")"
	[[ -n $2 ]] && local to="$(_editline "$2" "$f")"
	[[ -z $to ]] \
		&& local res="$(edit "${from}d\nw" "$f")" \
		|| local res="$(edit "${from},${to}d\nw" "$f")"
	[[ -n $res ]] && echo "$res"
	if [[ $f == $fn ]]
	then
		fs="$(wc -l "$fn" | cut -d ' ' -f1)"
		[[ $fl -gt $fs ]] && fl="$fs"
	fi

	return 0
}

function editchange {
	local f="${4:-$fn}"
	[[ -n $4 ]] && f="$(readlink -f "$f")"
	[[ -z $f ]] && return 1
	local from="${1:-$fl}"
	[[ -z $from ]] && return 2
	from="$(_editline "$from" "$f")"
	local data="$3"
	[[ -z $data ]] && data="$(cat /dev/stdin)"
	[[ -z $data ]] && return 3
	[[ -n $2 ]] && local to="$(_editline "$2" "$f")"
	[[ -z $to ]] \
		&& local res="$(edit "${from}c\n$data\n.\nw" "$f")" \
		|| local res="$(edit "${from},${to}c\n$data\n.\nw" "$f")"
	[[ -n $res ]] && echo "$res"
	if [[ $f == $fn ]]
	then
		[[ -z $to ]] && editshow l || editshow $from,$to
	fi

	return 0
}

function editchangeline {
	[[ -z $fn ]] && return 1
	[[ -z $1 ]] && return 2
	[[ -z $fl ]] && return 3
	local data="$@"
	[[ -z $data ]] && data="$(cat /dev/stdin)"
	[[ -z $data ]] && return 4
	res="$(edit "${fl}c\n$data\n.\nw" "$fn")"
	[[ -n $res ]] && echo "$res"
	editshow l
}

function editsub {
	local f="${6:-$fn}"
	[[ -n $6 ]] && f="$(readlink -f "$f")"
	[[ -z $f ]] && return 1
	local from="${1:-$fl}"
	[[ -z $from ]] && return 2
	from="$(_editline "$from" "$f")"
	[[ -n $2 ]] && local to="$(_editline "$2" "$f")"
	local in="$3"
	local out="$4"
	in="${in//\\\\/\\\\\\\\}"
	in="${in//\\N/\\\\\\n}"
	out="${out//\\\\/\\\\\\\\}"
	out="${out//\\N/\\\\\\n}"
	local pattern="s/$in/$out/"
	[[ $5 == "g" ]] && pattern="${pattern}g"
	local res=
	if [[ -z $to ]] || [[ $to == " " ]]
	then
		res="$(edit "$from$pattern\nw" "$f")"
	else
		res="$(edit "$from,$to$pattern\nw" "$f")"
	fi

	[[ -n $res ]] && echo "$res"
	[[ $f == $fn ]] && editshow l
	return 0
}

function editjoin {
	local f="${3:-$fn}"
	[[ -n $3 ]] && local f="$(readlink -f "$f")"
	[[ -z $f ]] && return 1
	local from="${1:-$fl}"
	[[ -z $from ]] && return 2
	[[ -z $1 ]] && from="$((from + 1))"
	from="$(_editline "$from" "$f")"
	[[ -n $2 ]] && local to="$(_editline "$2" "$f")"
	local res="$(edit "$from,${to}j\nw" "$f")"
	[[ -n $res ]] && echo "$res"
	[[ $f == $fn ]] \
		&& fs="$(wc -l "$fn" | cut -d ' ' -f1)" \
		&& [[ $fl -gt $fs ]] && fl="$fs"
	return 0
}

function editmove {
	local f="${4:-$fn}"
	[[ -n $4 ]] && local f="$(readlink -f "$f")"
	[[ -z $f ]] && return 1
	local from="${1:-$fl}"
	[[ -z $from ]] && return 2
	[[ -z $1 ]] && from="$((from + 1))"
	from="$(_editline "$from" "$f")"
	[[ -n $2 ]] && local to="$(_editline "$2" "$f")"
	local dest="$3"
	[[ $dest -ne 0 ]] && dest="$(_editline "$3" "$f")"
	[[ -z $dest ]] && return 3
	[[ -n $to ]] \
		&& local res="$(edit "$from,${to}m$dest\nw" "$f")" \
		|| local res="$(edit "${from}m$dest\nw" "$f")"
	[[ -n $res ]] && echo "$res"
	[[ $f == $fn ]] \
		&& fs="$(wc -l "$fn" | cut -d ' ' -f1)" \
		&& [[ $fl -gt $fs ]] && fl="$fs"
	return 0
}

function edittransfer {
	local f="${4:-$fn}"
	[[ -n $4 ]] && f="$(readlink -f "$f")"
	[[ -z $f ]] && return 1
	local from="${1:-$fl}"
	from="$(_editline "$from" "$f")"
	[[ -z $from ]] && return 2
	[[ -n $2 ]] && local to="$(_editline "$2" "$f")"
	local dest="$3"
	[[ $dest -ne 0 ]] && dest="$(_editline "$3" "$f")"
	if [[ $dest -ge 0 ]]
	then
		[[ -n $to ]] \
			&& local res="$(edcmd=p edit "$from,${to}t$dest\nw" "$f")" \
			|| local res="$(edcmd=p edit "${from}t$dest\nw" "$f")"
		[[ -n $res ]] && echo "$res"
		[[ $f == $fn ]] \
			&& fs="$(wc -l "$fn" | cut -d ' ' -f1)" \
			&& [[ $fl -gt $fs ]] && fl="$fs"
	elif [[ -z $dest ]] && [[ -n $to ]]
	then
		yank="$(editprint $from,$to "$f")"
	else
		yank="$(editprint $from "$f")"
	fi

	return 0
}

function _editindent {
	[[ -z $3 ]] && return 3
	local f="${2:-$fn}"
	[[ -n $2 ]] && f="$(readlink -f "$f")"
	[[ -z $f ]] && return 1
	local from="${1:-$fl}"
	from="$(_editline "$from" "$f")"
	[[ -z $from ]] && return 2
	local line="$(ep $from "$f")"
	if [[ -n $line ]]
	then
		[[ $3 -eq 1 ]] \
			&& printf -- '%s' "$line" | awk -F '[ ]' '{ print NF-1 }' \
			|| printf -- '%s' "$line" | awk -F '\t' '{ print NF-1 }'
	else
		return 4
	fi

	return 0
}

function editlevel {
	_editindent "${1:-$fl}" "${2:-$fn}" 0
}

function editspaces {
	_editindent "${1:-$fl}" "${2:-$fn}" 1
}

function editexternal {
	local f="${3:-$fn}"
	[[ -n $3 ]] && f="$(readlink -f "$f")"
	[[ -z $f ]] && return 1
	local from="${1:-$fl}"
	from="$(_editline "$from" "$f")"
	[[ -z $from ]] && return 2
	local to="${2:-$fl}"
	to="$(_editline "$to" "$f")"
	[[ -z $to ]] && return 3
	editcopy $from $to '' '' "$f"
	$EDITOR "$editreadlines"
	local res="$(edit "$from,${to}d\nw" "$f")"
	[[ -n $res ]] && echo "$res"
	editpaste $(($from - 1)) '' "$f"
	[[ $f == $fn ]] \
		&& fs="$(wc -l "$fn" | cut -d ' ' -f1)" \
		&& [[ $fl -gt $fs ]] && fl="$fs"
	return 0
}

function etermbin {
	[[ -z $1 ]] && return 1
	[[ -n $2 ]] && local fn="$2" && fn="$(readlink -f "$fn")"
	[[ -z $fn ]] && return 2
	editprint $1 | nc termbin.com 9999
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
		local words=($(editprint a "$f"))
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
		if [[ $(type -t _edithiextract) == function ]]
		then
			local hiwords="$(_edithiextract "$f")"
			[[ -n $hiwords ]] && words=(${words[@]} $hiwords)
		fi

		_editfzf 0 "${words[@]}"
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
function eff { editfilefind "$@"; }
function ei { editinsert "$@"; }
function ej { editjoin "$@"; }
function els { editspaces "$@"; }
function el { editlevel "$@"; }
function em { editmove "$@"; }
function eo { editopen "$@"; }
function epaste { editpaste "$@"; }
function ep { editprint "$@"; }
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
	local words=($(editprint l))
	local word="${words[COMP_CWORD]}"
	[[ -n $word ]] \
		&& COMPREPLY=($(compgen -W "$word" -- $cur)) \
		|| COMPREPLY=($(compgen -f -- $cur))
}

complete -o nospace -o filenames -o nosort -F _editchangeline editchangeline
complete -o nospace -o filenames -o nosort -F _editchangeline echl

function _editchange {
	local cur=${COMP_WORDS[COMP_CWORD]}
	case "$COMP_CWORD" in
		1)
			COMPREPLY=($(compgen -o nosort -W "$ + - ." -- $cur))
			;;
		2)
			COMPREPLY=($(compgen -o nosort -W "$ + - ." -- $cur))
			;;
		*)
			COMPREPLY=($(compgen -f -- $cur))
			;;
	esac
}

complete -o nospace -o filenames -F _editchange editchange
complete -o nospace -o filenames -F _editchange ech

function _edcmd {
	local cur=${COMP_WORDS[COMP_CWORD]}
	case "$COMP_CWORD" in
		1)
			COMPREPLY=($(compgen -o nosort -W "$ + - ." -- $cur))
			;;
		2)
			COMPREPLY=($(compgen -o nosort -W "$ + - ." -- $cur))
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
			COMPREPLY=($(compgen -o nosort -W "$ + ." -- $cur))
			;;
		2)
			COMPREPLY=($(compgen -o nosort -W "$ + ." -- $cur))
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
			COMPREPLY=($(compgen -o nosort -W "$ +" -- $cur))
			;;
		2)
			COMPREPLY=($(compgen -o nosort -W "$ +" -- $cur))
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
			COMPREPLY=($(compgen -o nosort -W "$ +" -- $cur))
			;;
		2)
			COMPREPLY=($(compgen -o nosort -W "$ +" -- $cur))
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

function _editfilefind {
	local cur=${COMP_WORDS[COMP_CWORD]}
	case "$COMP_CWORD" in
		2)
			COMPREPLY=($(compgen -o nosort -W "r" -- $cur))
			;;
		3)
			COMPREPLY=($(compgen -W "u d l r ul ur dl dr ru rd \
				lu ld" -- $cur))
			;;
		*)
			COMPREPLY=($(compgen -f -- $cur))
			;;
	esac
}

complete -o nospace -o filenames -F _editfilefind editfilefind
complete -o nospace -o filenames -F _editfilefind eff

function _editjoin {
	local cur=${COMP_WORDS[COMP_CWORD]}
	case "$COMP_CWORD" in
		1)
			COMPREPLY=($(compgen -o nosort -W "$ +" -- $cur))
			;;
		2)
			COMPREPLY=($(compgen -o nosort -W "$ +" -- $cur))
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
			COMPREPLY=($(compgen -o nosort -W "$ + -" -- $cur))
			;;
		2)
			COMPREPLY=($(compgen -o nosort -W "$ +" -- $cur))
			;;
		3)
			COMPREPLY=($(compgen -o nosort -W "$ +" -- $cur))
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
			COMPREPLY=($(compgen -W "a b c d e f fz g G l m n p u \
				v / . $ + -" -- $cur))
			;;
		*)
			COMPREPLY=($(compgen -f -- $cur))
			;;
	esac
}

complete -o nospace -o filenames -F _editshow editshow
complete -o nospace -o filenames -F _editshow es
complete -o nospace -o filenames -F _editshow etermbin
complete -o nospace -o filenames -F _editshow editprint
complete -o nospace -o filenames -F _editshow ep

function _editpaste {
	local cur=${COMP_WORDS[COMP_CWORD]}
	case "$COMP_CWORD" in
		1)
			COMPREPLY=($(compgen -o nosort -W "$ + ." -- $cur))
			;;
		2)
			COMPREPLY=($(compgen -o nosort -W "$ + ." -- $cur))
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
		1)
			COMPREPLY=($(compgen -o nosort -W "$ + ." -- $cur))
			;;
		2)
			COMPREPLY=($(compgen -o nosort -W "$ + ." -- $cur))
			;;
		5)
			COMPREPLY=($(compgen -W "g"))
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
			COMPREPLY=($(compgen -o nosort -W ". $" -- $cur))
			;;
		2)
			COMPREPLY=($(compgen -o nosort -W "+" -- $cur))
			;;
		*)
			COMPREPLY=($(compgen -f -- $cur))
			;;
	esac
}

complete -o nospace -o filenames -F _edittransfer edittransfer
complete -o nospace -o filenames -F _edittransfer ey

