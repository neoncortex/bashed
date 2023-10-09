#!/usr/bin/env bash

# files and directories
editdir="$HOME/.edit"
editsearchdir="$editdir/search"
edittempdir="$editdir/temp"
#editreadlines="$editdir/readlines"
editreadlines=
eddatacmd="xdg-open"

# edit
edcmd="n"

# color
edcolor=0

# bind key for editwords
editwordkey="o"

#fzf
edfzfsize="80%"
edfzfpsize="30%"

#tmux
edtmuxpsize="80%"

#sound
edsound=1

#notify send
ednotifysend=0

mkdir -p "$editdir"
mkdir -p "$editdir/dict"
mkdir -p "$editsearchdir"
mkdir -p "$edittempdir"

function _editwindow {
	local IFS=$'\t\n'
	local session="$(tmux display-message -p '#S')"
	for i in $(tmux lsp -s -t "$session:0" -F '#I::#D #T')
	do
		local location="${i/\ */}"
		if [[ "${i#$location\ }" == "$1" ]]
		then
			local window="${location/::*/}"
			local pane="${location/*::/}"
			if [[ $3 == 'n' ]]
			then
				tmux select-window -t "$session:$window"
				tmux select-pane -t "$pane"
				tmux send-keys -t "$pane" "fn=\"$1\"" Enter
				tmux send-keys -t "$pane" \
					"cd \"\$(dirname \"\$fn\")\"" Enter
				tmux send-keys -t "$pane" "fl=1" Enter
				tmux send-keys -t "$pane" "clear" Enter
				tmux send-keys -t "$pane" \
					"[[ -f \$PWD/.bashed ]] " \
					"&& source \$PWD/.bashed" \
					"&& clear " \
					"&& _editalert \"loaded " \
					"\$PWD/.bashed\" \"\$edalertsound\" " \
					Enter
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
	done
}

function _editalert {
	if [[ $ednotifysend == 1 ]]
	then
		[[ -n $1 ]] \
			&& >&2 printf -- '%s\n' "$1" \
			&& notify-send -a bashed "$1"
	else
		[[ -n $1 ]] && >&2 printf -- '%s\n' "$1"
	fi

	local sound="${2:-$ederrorsound}"
	local player=
	if [[ -n $(type -P paplay) ]]
	then
		player="paplay"
	elif [[ -n $(type -P ffplay) ]]
	then
		player="ffplay -nodisp -autoexit"
	fi

	[[ $edsound == 1 ]] \
		&& [[ -n $sound ]] \
		&& [[ -f $sound ]] \
		&& [[ -n $player ]] \
		&& $($player "$sound" >/dev/null 2>&1 &)
	return 0
}

function edit {
	[[ -n $2 ]] && local fn="$2" && fn="$(readlink -f "$fn")"
	[[ -z $fn ]] \
		&& _editalert "edit: no file" \
		&& return 1
	[[ -z $1 ]] \
		&& _editalert "edit: no command" \
		&& return 2
	result="$(printf -- '%b\n' "$1" | ed -s "$fn")"
	printf -- '%s\n' "$result"
	fs="$(wc -l "$fn" | cut -d ' ' -f1)"
}

function _editline {
	local l="${1:-$fl}"
	[[ -z $l ]] \
		&& _editalert "_editline: no line" \
		&& return 1
	! [[ $l == . ]] \
		&& ! [[ $l == $ ]] \
		&& ! [[ $l =~ ^\+$ ]] \
		&& ! [[ $l =~ ^\-$ ]] \
		&& ! [[ $l =~ ^(\-|\+)?[0-9]+$ ]] \
		&& _editalert "_editline: cant parse line" \
		&& return 2
	[[ -n $2 ]] && local fs="$(wc -l "$2" | cut -d ' ' -f1)"
	[[ -z $fs ]] \
		&& _editalert "_editline: file size is 0" \
		&& return 3
	if [[ -n $fl ]]
	then
		[[ $l == "." ]] && l="$fl"
		[[ $l =~ ^\+ ]] && l="${l/+/}" && l="$((fl + l))"
		[[ $l =~ ^\- ]] && l="${l/-/}" && l="$((fl - l))"
		[[ $l =~ ^\-[0-9]+ ]] && l="${l/-/}" && l="$((fl - l))"
		[[ $l =~ ^\+[0-9]+ ]] && l="${l/+/}" && l="$((fl + l))"
		[[ $l == "$" ]] && l="$fs"
		[[ $l -gt $fs ]] && l=$fs
	fi

	[[ $l -lt 1 ]] && l=1
	printf -- '%s\n' "$l"
	return 0
}

function edittemp {
	[[ -z $1 ]] \
		&& _editalert "editttemp: no argument" \
		&& return 1
	if [[ $1 == create ]]
	then
		local file="$(mktemp $edittempdir/temp.XXXXXX)"
		if [[ -f $file ]]
		then
			printf -- '%s\n' "$file"
		else
			_editalert "edittemp: cant create temporary file"
			return 2
		fi
	elif [[ $1 == clean ]]
	then
		if [[ -d $edittempdir ]]
		then
			for i in $edittempdir/*
			do
				[[ -f $i ]] && rm "$i"
			done
		else
			_editalert "edittemp: edittempdir does not exist"
		fi
	fi

	return 0
}

function editcopy {
	local s=${1:-$fl}
	local e=${2:-$fl}
	local f="${5:-$fn}"
	[[ -z $s ]] \
		&& _editalert "editcopy: no start line" \
		&& return 2
	[[ -z $e ]] \
		&& _editalert "editcopy: no end line" \
		&& return 3
	f="$(readlink -f "$f")"
	[[ -z $f ]] \
		&& _editalert "editcopy: no file" \
		&& return 1
	s="$(_editline "$s" "$f")"
	[[ $? -ne 0 ]] \
		&& _editalert "editcopy: start line not recognized" \
		&& return 4
	e="$(_editline "$e" "$f")"
	[[ $? -ne 0 ]] \
		&& _editalert "editcopy: end line not recognized" \
		&& return 5
	[[ -f $editreadlines ]] && rm "$editreadlines"
	editreadlines="$(edittemp create)"
	! [[ -f $editreadlines ]] \
		&& _editalert "editcopy: cant create temporary file" \
		&& return 6
	local res="$(edit "${s},${e}p" "$f" > "$editreadlines")"
	[[ $3 == x ]] && cat "$editreadlines" | xclip -r -i
	[[ $3 == w ]] && cat "$editreadlines" | wl-copy
	[[ $4 == cut ]] && editdelete $s $e "$f"
	[[ $f == $fn ]] && es l
}

function editpaste {
	local s=${1:-$fl}
	[[ -z $s ]] \
		&& _editalert "editpaste: no start line" \
		&& return 2
	local f="${3:-$fn}"
	f="$(readlink -f "$f")"
	[[ -z $f ]] \
		&& _editalert "editpaste: no file" \
		&& return 1
	! [[ -f $f ]] && touch "$f"
	if [[ $s != 0 ]]
	then
		s="$(_editline "$s" "$f")"
		[[ $? -ne 0 ]] \
			&& _editalert "editpaste: start line not recognized" \
			&& return 3
	fi

	[[ $fs == 0 ]] && s=0
	if [[ $2 == x ]] || [[ $2 == w ]]
	then
		[[ -f $editreadlines ]] && rm "$editreadlines"
		editreadlines="$(edittemp create)"
		! [[ -f $editreadlines ]] \
			&& _editalert "editpaste: cant create temporary file" \
			&& return 4
		[[ $2 == x ]] && xclip -r -o > "$editreadlines"
		[[ $2 == w ]] && wl-paste > "$editreadlines"
	fi

	local res="$(edit "${s}r $editreadlines\nw" "$f")"
	[[ -n $res ]] && printf -- '%s\n' "$res"
	[[ $f == $fn ]] && es "$((s+1))"
}

function editcmd {
	[[ -n $4 ]] && local fn="$4" && fn="$(readlink -f "$fn")"
	[[ -z $fn ]] \
		&& _editalert "editcmd: no file" \
		&& return 1
	[[ -z $3 ]] \
		&& _editalert "editcmd: no command" \
		&& return 2
	[[ -z $1 ]] \
		&& _editalert "editcmd: no start line" \
		&& return 3
	[[ -z $2 ]] \
		&& _editalert "editcmd: no end line" \
		&& return 4
	local begin="$(_editline "$1")"
	[[ $? -ne 0 ]] \
		&& _editalert "editcmd: start line not recognized" \
		&& return 5
	local end="$(_editline "$2")"
	[[ $? -ne 0 ]] \
		&& _editalert "editcmd: end line not recognized" \
		&& return 6
	editcopy $begin $end '' '' "$fn"
	[[ $? -ne 0 ]] && return $?
	[[ -z $editdir ]] \
		&& _editalert "editcmd: editdir is not set" \
		&& return 7
	! [[ -d $editdir ]] \
		&& _editalert "editcmd: editdir does not exist" \
		&& return 8
	local tempfile="$(edittemp create)"
	! [[ -f $tempfile ]] \
		&& _editalert "editcmd: cant create temporary file" \
		&& return 9
	! [[ -f $editreadlines ]] \
		&& _editalert "editcmd: editreadlines does not exist" \
		&& return 10
	cat "$editreadlines" | $3 > "$tempfile"
	if [[ $? == 0 ]]
	then
		[[ -z $tempfile ]] \
			&& _editalert "editcmd: tempfile does not exist" \
			&& return 11
		mv -- "$tempfile" "$editreadlines"
		local res="$(edit "$begin,${end}d\nw" "$fn")"
		[[ -n $res ]] && printf -- '%s\n' "$res"
		editpaste $(($begin - 1)) '' "$fn"
		fs="$(wc -l "$fn" | cut -d ' ' -f1)"
	else
		rm "$tempfile"
	fi
}

function _editarg {
	[[ -z $1 ]] \
		&& _editalert "_editarg: no argument" \
		&& return 1
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
		[[ -n $3 ]] && argument="$3"
	fi

	[[ -z $f ]] \
		&& _editalert "editopen: no file" \
		&& return 1
	[[ ${f:0:1} != '/' ]] \
		&& [[ ${f:0:1} != '~' ]] \
		&& [[ $f =~ '\$HOME' ]] \
		&& f="$PWD/$f"
	f="$(readlink -f "$f")"
	! [[ -f $f ]] && touch "$f"
	_editwindow "$f" "$argument"
	[[ $? -eq 1 ]] \
		&& _editalert '' "$edalertsound" \
		&& return 2
	if tmux run 2>/dev/null
	then
		local wordkey="${editwordkey:-o}"
		tmux bind-key $wordkey run -b \
			"bash -ic \"fn=\"$f\" editwords\""
	else
		_editalert "editopen: tmux session not found"
		return 3
	fi

	local location="$2"
	[[ $location == 0 ]] && location=
	[[ $location == 'u' ]] && tmux splitw -b -c "$f"
	[[ $location == 'd' ]] && tmux splitw -c "$f"
	[[ $location == 'l' ]] && tmux splitw -b -c "$f" -h
	[[ $location == 'r' ]] && tmux splitw -c "$f" -h
	[[ $location == 'n' ]] && tmux neww -c "$f"
	[[ $location == 'ul' ]] && tmux select-pane -U && tmux splitw -b -c "$f" -h
	[[ $location == 'ur' ]] && tmux select-pane -U && tmux splitw -c "$f" -h
	[[ $location == 'dl' ]] && tmux select-pane -U && tmux splitw -b -c "$f" -h
	[[ $location == 'dr' ]] && tmux select-pane -U && tmux splitw -c "$f" -h
	[[ $location == 'ld' ]] && tmux select-pane -L && tmux splitw -c "$f"
	[[ $location == 'lu' ]] && tmux select-pane -L && tmux splitw -b -c "$f"
	[[ $location == 'rd' ]] && tmux select-pane -R && tmux splitw -c "$f"
	[[ $location == 'ru' ]] && tmux select-pane -L && tmux splitw -b -c "$f"
	tmux select-pane -T "$f"
	if [[ -z $location ]]
	then
		fn="$f"
		cd "$(dirname "$fn")"
		fl=1
		[[ -f $PWD/.bashed ]] \
			&& _editalert "loaded $PWD/.bashed" "$edalertsound" \
			&& source "$PWD/.bashed"
		[[ -n $argument ]] \
			&& _editarg "$argument" \
			|| editshow 1
		tmux select-pane -T "$f"
	else
		_editwindow "$f" "$argument" n
	fi
}

function editclose {
	[[ $1 == delete ]] && rm "$fn"
	[[ -n $fn ]] && fn=
	[[ -n $fl ]] && fl=
	[[ -n $fs ]] && fs=
	[[ -n $fileresult ]] && fileresult=
	[[ -n $fileresultindex ]] && fileresultindex=
	[[ -n $fileresult_a ]] && fileresult_a=
	tmux select-pane -T "$(hostname)"
}

function editfind {
	[[ -z $1 ]] \
		&& _editalert "editfind: no argument" \
		&& return 1
	[[ -z $fn ]] \
		&& _editalert "editfind: no file" \
		&& return 2
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
			&& fileresult="$data" \
			|| fileresult="$fileresult
$data"
		counter=$((counter+1))
	done

	if [[ -n "$fileresult" ]]
	then
		if [[ $2 == fz ]]
		then
			local zres="$(_editfzf '' 'echo' 0 1 "$fileresult")"
			if [[ -n $zres ]]
			then
				fileresultindex="${zres/:*/}"
				fl="${fileresult_a[$fileresultindex]}"
				printf -- '%s' "$fileresultindex:"
				editshow ${fl}
			fi
		else
			printf -- '%s\n' "$fileresult"
		fi
	fi
}

function editfindg {
	[[ -z $1 ]] \
		&& _editalert "editfindg: no argument" "$ederrorsound" \
		&& return 1
	local arg="g/$1/n"
	shift
	editfind "$arg" "$@"
}

function editfilefind {
	[[ -z $1 ]] \
		&& _editalert "editfilefind: no argument" \
		&& return 1
	[[ -z $editsearchdir ]] \
		&& _editalert "editfilefind: editsearchdir is not set" \
		&& return 2
	local dir="$editsearchdir/$PWD"
	local date="$(date +'%Y-%m-%d_%H-%M-%S')"
	local cache="$dir/$date"
	local cache_file=
	local data=
	local IFS=$'\n\t '
	for i in $dir/*.search
	do
		[[ -f $i ]] \
			&& local word="$(cat $i)" \
			|| continue
		[[ "$word" == "$1" ]] && cache_file="$i"
	done

	[[ -f $cache_file ]] \
		&& data="${cache_file/.search/.res}"
	if [[ $4 == new ]] || ! [[ -f $cache_file ]]
	then
		[[ -f $cache_file ]] && rm "$cache_file"
		[[ -f $data ]] && rm "$data"
		[[ $2 == r ]] \
			&& local files="$(grep -HinRIs "$1" ".")" \
			|| local files="$(grep -HinIs "$1" ./*)"
		[[ -z $files ]] && return 3
		mkdir -p "$dir"
		! [[ -d $dir ]] \
			&& _editalert "editfindfile: directory not found" \
			&& return 4
		printf -- '%s\n' "$1" > "$cache.search"
		printf -- '%s\n'  "$files" > "$cache.res"
		local res="$(_editfzf '' 'echo' 0 1 "$files")"
	else
		if [[ -f $data ]]
		then
			_editalert "editfindfile: using cache: $data" \
				"$edalertsound"
			local res="$(_editfzf '' 'echo' 0 1 "$(cat "$data")")"
		else
			_editalert "editfindfile: cache file not found"
			return 5
		fi
	fi

	[[ -z $res ]] && return 6
	local name="${res/:*/}"
	local line="${res#*:}"
	line="${line/:*/}"
	[[ -n $name ]] && [[ -n $line ]] && editopen "$name:$line" $3
}

function editlocate {
	[[ -n $3 ]] && local fn="$3" && fn="$(readlink -f "$fn")"
	[[ -z $fn ]] \
		&& _editalert "editlocate: no file" \
		&& return 1
	[[ -z $1 ]] \
		&& _editalert "editlocate: no argument" \
		&& return 2
	[[ -n $2 ]] && local fl="$2"
	local pattern="$1"
	[[ $1 =~ ^\/ ]] && pattern="${pattern/\//}"
	local to="$(edsyntax=0 \
		ef "${fl},${fs}g/$pattern/n" | head -n1)"
	to="${to/\ */}"
	to="${to/*:/}"
	printf '%s\n' "$to"
}

function editshow {
	if [[ -n $2 ]]
	then
		local fn="$2"
		fn="$(readlink -f "$fn")"
		local fl="$fl"
		local fs=
	fi

	[[ -z $fn ]] \
		&& _editalert "editshow: no file" \
		&& return 1
	[[ -d $fn ]] \
		&& _editalert "editshow: is a directory" \
		&& return 2
	if tmux run 2>/dev/null
	then
		local wordkey="${editwordkey:-o}"
		tmux bind-key $wordkey run -b \
			"bash -ic \"fn=\"$fn\"; editwords\""
	else
		_editalert "editshow: tmux session not found"
		return 3
	fi

	fs="$(wc -l "$fn" | cut -d ' ' -f1)"
	[[ -z $fs ]] && return 3
	[[ $fs == 0 ]] \
		&& fl=0 \
		&& return 0
	[[ -z $pagesize ]] && pagesize=20
	fl="$(_editline "${fl:-1}")"
	local arg="$1"
	[[ -z $1 ]] && arg="+"
	local IFS=$' \t\n'
	local show=
	local cmd="${edcmd:-n}"
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
				_editalert "?"
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
			printf -- '$s\n' "$fileresultindex:"
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
			printf -- '%s\n' "$fileresultindex:"
			editshow $fl
			return
		elif [[ $arg == s ]]
		then
			[[ -n "$fileresult" ]] && printf -- '%s\n' "$fileresult"
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
		elif [[ $arg == mf ]]
		then
			local res="$(_editfzf '' 'echo' 0 1 "$(edcolor=0 editshow m)")"
			if [[ -n $res ]]
			then
				local line="${res/$'\t'*/}"
				[[ -n $line ]] && editshow $line
			fi
		elif [[ $arg == fz ]]
		then
			[[ -n "$fileresult" ]] \
				&& local res="$(_editfzf '' 'echo' 0 1 "$fileresult")"
			if [[ -n $res ]]
			then
				fileresultindex="${res/:*/}"
				fl="${fileresult_a[$fileresultindex]}"
				printf -- '%s' "$fileresultindex:"
				editshow ${fl}
			fi

			return
		fi
	fi

	if [[ $arg == r ]]
	then
		if [[ -n $eslast ]] && [[ ${eslast:0-1} != $cmd ]]
		then
			[[ ${eslast:0-1} == "p" ]] \
				&& eslast="${eslast/%p/n}" \
				|| eslast="${eslast/%n/p}"
		fi

		show="$eslast"
	elif [[ $arg == $ ]] || [[ $arg == "G" ]]
	then
		fl="$fs"
		show="edit ${fl}$cmd"
	elif [[ $arg == g ]]
	then
		fl="1"
		show="edit ${fl}$cmd"
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
			[[ $? -ne 0 ]] \
				&& _editalert "editshow: start line not recognized" \
				&& return 4
			tail="$(_editline "$tail")"
			[[ $? -ne 0 ]] \
				&& _editalert "editshow: end line not recognized" \
				&& return 5
			show="edit ${head},${tail}$cmd"
			fl="$tail"
		else
			arg="$(_editline "$arg")"
			[[ $? -ne 0 ]] \
				&& _editalert "editshow: line not recognized" \
				&& return 6
			show="edit ${arg}$cmd"
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
				&& show="edit ${head},${tail}$cmd" \
				&& fl="$tail"
		else
			local line="$(editlocate "${arg/\//}")"
			[[ $line =~ ^[0-9]+$ ]] && show="edit ${line}$cmd" \
				&& fl="$line"
		fi
	elif [[ $arg == l ]] || [[ $arg == . ]]
	then
		show="edit ${fl}$cmd"
	elif [[ $pagesize -ge $fs ]]
	then
		show="edit "1,${fs}$cmd""
	elif [[ $arg == n ]]
	then
		[[ $eslastarg == "p" ]] \
			&& fl="$((fl + pagesize + 2))"
		if [[ $fl -ge $((fs - pagesize)) ]]
		then
			show="edit "$((fs - pagesize)),${fs}$cmd""
			fl="$fs"
		else
			show="edit "${fl},$((fl + pagesize))$cmd""
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
			show="edit "1,${pagesize}$cmd""
			fl="$pagesize"
		else
			show="edit "$((fl - pagesize)),${fl}$cmd""
			fl="$((fl - pagesize - 1))"
		fi
	elif [[ $arg == b ]]
	then
		show="edit "1,${pagesize}$cmd""
		fl="$((pagesize + 1))"
	elif [[ $arg == e ]]
	then
		show="edit "$((fs - pagesize)),${fs}$cmd""
		fl="$((fs - pagesize - 1))"
	elif [[ $arg == a ]]
	then
		show="edit ,$cmd"
	elif [[ $arg == c ]]
	then
		local head="$((fl - (pagesize / 2)))"
		local tail="$((fl + (pagesize / 2)))"
		[[ $head -lt 1 ]] && head="1" \
			&& tail="$((tail + (pagesize / 2)))"
		[[ $tail -gt $fs ]] && tail="$fs"
		show="edit ${head},${tail}$cmd"
	elif [[ $arg == v ]]
	then
		local rows=
		local cols=
		read -r rows cols < <(stty size)
		[[ -z $rows ]] && return 3
		[[ -z $cols ]] && return 3
		local head="$((fl + 1))"
		local head="$fl"
		[[ $head -gt $fs ]] && head="$fs"
		local tail="$((fl + rows - 2))"
		if [[ $tail -ge $fs ]]
		then
			show="edit $fl,\$$cmd"
			fl="$fs"
		else
			show="edit $head,$tail$cmd"
			fl="$((tail + 1))"
		fi
	fi

	if [[ -n $show ]]
	then
		eslastarg="$arg"
		eslast="$show"
		if [[ $edcolor != 0 ]]
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

function editshowfzf {
	local arg="$1"
	local f="${2:-$fn}"
	f="$(readlink -f "$f")"
	[[ -z $f ]] \
		&& _editalert "editshowfzf: no file" \
		&& return 1
	! [[ -f $f ]] \
		&& _editalert "editshowfzf: file not found" \
		&& return 2
	[[ -z $arg ]] && arg="a"
	local l="${fl:-1}"
	local res="$(_editfzf '' 'echo' 0 $l "$(edcolor=0 edcmd=n editshow \
		"$arg" "$f")")"
	[[ -z $res ]] && return 0
	local line="${res/$'\t'*/}"
	[[ -z $line ]] \
		&& _editalert "editshowfzf: cant find line" \
		&& return 3
	[[ $f == $fn ]] \
		&& editshow $line \
		|| editshow $line "$f"
	return 0
}

function editprint {
	edcmd=p edcolor=0 editshow "$@"
}

function editappend {
	[[ -z $fn ]] \
		&& _editalert "editappend: no file" \
		&& return 1
	[[ -z $fl ]] \
		&& _editalert "editappend: no line" \
		&& return 2
	local data="$@"
	[[ -z $data ]] && data="$(cat /dev/stdin)"
	[[ $data =~ ^(\\n)+$ ]] && data="${data/\\n/}"
	local line=$fl
	[[ $fs -eq 0 ]] && fs="$(wc -l "$fn" | cut -d ' ' -f1)"
	[[ $fs -eq 0 ]] && [[ $line -eq 1 ]] && line=$((line - 1))
	local res="$(edit "${line}a\n$data\n.\nw" "$fn")"
	[[ -n $res ]] \
		&& >&2 printf -- '%s\n' "$res" \
		&& return 3
	editshow "+$(printf -- '%b\n' "$data" | grep -c "^")"
}

function editinsert {
	[[ -z $fl ]] \
		&& _editalert "editinsert: no line" \
		&& return 1
	fl="$((fl - 1))"
	editappend "$@"
}

function editdelete {
	local f="${3:-$fn}"
	[[ -n $3 ]] && f="$(readlink -f "$f")"
	[[ -z $f ]] \
		&& _editalert "editdelete: no file" \
		&& return 1
	local from="${1:-$fl}"
	[[ -z $from ]] \
		&& _editalert "editdelete: no start line" \
		&& return 2
	from="$(_editline "$from" "$f")"
	[[ $? -ne 0 ]] \
		&& _editalert "editdelete: start line not recognized" \
		&& return 3
	[[ -n $2 ]] \
		&& local to="$(_editline "$2" "$f")" \
		&& [[ -z $to ]] \
		&& _editalert "editdelete: end line not recognized" \
		&& return 4
	[[ -z $to ]] \
		&& local res="$(edit "${from}d\nw" "$f")" \
		|| local res="$(edit "${from},${to}d\nw" "$f")"
	[[ -n $res ]] && printf -- '%s\n' "$res"
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
	[[ -z $f ]] \
		&& _editalert "editchange: no file" \
		&& return 1
	local from="${1:-$fl}"
	[[ -z $from ]] \
		&& _editalert "editchange: no start line" \
		&& return 2
	from="$(_editline "$from" "$f")"
	[[ $? -ne 0 ]] \
		&& _editalert "editchange: start line not recognized" \
		&& return 3
	local data="$3"
	[[ -z $data ]] && data="$(cat /dev/stdin)"
	[[ -n $2 ]] \
		&& local to="$(_editline "$2" "$f")" \
		&& [[ -z $to ]] \
		&& _editalert "editchange: end line not recognized" \
		&& return 4
	[[ -z $to ]] \
		&& local res="$(edit "${from}c\n$data\n.\nw" "$f")" \
		|| local res="$(edit "${from},${to}c\n$data\n.\nw" "$f")"
	[[ -n $res ]] && printf -- '%s\n' "$res"
	if [[ $f == $fn ]]
	then
		[[ -z $to ]] && editshow l || editshow $from,$to
	fi

	return 0
}

function editchangeline {
	[[ -z $fn ]] \
		&& _editalert "editchangeline: no file" \
		&& return 1
	[[ -z $1 ]] \
		&& _editalert "editchangeline: no data" \
		&& return 2
	[[ -z $fl ]] \
		&& _editalert "editchangeline: no line" \
		&& return 3
	local data="$@"
	[[ -z $data ]] && data="$(cat /dev/stdin)"
	res="$(edit "${fl}c\n$data\n.\nw" "$fn")"
	[[ -n $res ]] && printf -- '%s\n' "$res"
	editshow l
}

function editsub {
	local f="${6:-$fn}"
	[[ -n $6 ]] && f="$(readlink -f "$f")"
	[[ -z $f ]] \
		&& _editalert "editsub: no file" \
		&& return 1
	local from="${1:-$fl}"
	[[ -z $from ]] \
		&& _editalert "editsub: no start line" \
		&& return 2
	from="$(_editline "$from" "$f")"
	[[ $? -ne 0 ]] \
		&& _editalert "editsub: start line not recognized" \
		&& return 3
	[[ -n $2 ]] \
		&& local to="$(_editline "$2" "$f")" \
		&& [[ -z $to ]] \
		&& _editalert "editsub: end line not recognized" \
		&& return 4
	local in="$3"
	[[ -z $in ]] \
		&& _editalert "editsub: missing regex" \
		&& return 5
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

	[[ -n $res ]] && printf -- '%s\n' "$res"
	[[ $f == $fn ]] && editshow l
	return 0
}

function editjoin {
	local f="${3:-$fn}"
	[[ -n $3 ]] && local f="$(readlink -f "$f")"
	[[ -z $f ]] \
		&& _editalert "editjoin: no file" \
		&& return 1
	local from="${1:-$fl}"
	[[ -z $from ]] \
		&& _editalert "editjoin: no start line" \
		&& return 2
	from="$(_editline "$from" "$f")"
	[[ $? -ne 0 ]] \
		&& _editalert "editjoin: start line not recognized" \
		&& return 3
	[[ -n $2 ]] \
		&& local to="$(_editline "$2" "$f")" \
		&& [[ -z $to ]] \
		&& _editalert "editjoin: end line not recognized" \
		&& return 4
	[[ -z $to ]] && local to="$((from + 1))"
	local res="$(edit "$from,${to}j\nw" "$f")"
	[[ -n $res ]] && printf -- '%s\n' "$res"
	[[ $f == $fn ]] \
		&& fs="$(wc -l "$fn" | cut -d ' ' -f1)" \
		&& [[ $fl -gt $fs ]] && fl="$fs"
	return 0
}

function editmove {
	local f="${4:-$fn}"
	[[ -n $4 ]] && local f="$(readlink -f "$f")"
	[[ -z $f ]] \
		&& _editalert "editmove: no file" \
		&& return 1
	local from="${1:-$fl}"
	[[ -z $from ]] \
		&& _editalert "editmove: no start line" \
		&& return 2
	[[ -z $1 ]] && from="$((from + 1))"
	from="$(_editline "$from" "$f")"
	[[ $? -ne 0 ]] \
		&& _editalert "editmove: start line not recognized" \
		&& return 3
	[[ -n $2 ]] \
		&& local to="$(_editline "$2" "$f")" \
		&& [[ -z $to ]] \
		&& _editalert "editmove: end line not recognized" \
		&& return 4
	local dest="$3"
	[[ $dest != 0 ]] && dest="$(_editline "$3" "$f")"
	[[ -z $dest ]] \
		&& _editalert "editmove: no destiny" \
		&& return 5
	[[ -n $to ]] \
		&& local res="$(edit "$from,${to}m$dest\nw" "$f")" \
		|| local res="$(edit "${from}m$dest\nw" "$f")"
	[[ -n $res ]] && printf -- '%s\n' "$res"
	[[ $f == $fn ]] \
		&& fs="$(wc -l "$fn" | cut -d ' ' -f1)" \
		&& [[ $fl -gt $fs ]] && fl="$fs"
	return 0
}

function edittransfer {
	local f="${4:-$fn}"
	[[ -n $4 ]] && f="$(readlink -f "$f")"
	[[ -z $f ]] \
		&& _editalert "edittransfer: no file" \
		&& return 1
	local from="${1:-$fl}"
	from="$(_editline "$from" "$f")"
	[[ $? -ne 0 ]] \
		&& _editalert "edittransfer: start line not recognized" \
		&& return 2
	[[ -n $2 ]] \
		&& local to="$(_editline "$2" "$f")" \
		&& [[ -z $o ]] \
		&& _editalert "edittransfer: end line not recognized" \
		&& return 3
	local dest="$3"
	[[ $dest != 0 ]] \
		&& dest="$(_editline "$3" "$f")" \
		&& [[ -z $dest ]] \
		&& _editalert "edittransfer: destiny line not recognized" \
		&& return 4
	if [[ $dest -ge 0 ]]
	then
		[[ -n $to ]] \
			&& local res="$(editprint "$from,${to}t$dest\nw" "$f")" \
			|| local res="$(editprint "${from}t$dest\nw" "$f")"
		[[ -n $res ]] && printf -- '%s\n' "$res"
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

function editlevel {
	local f="${2:-$fn}"
	[[ -n $2 ]] && f="$(readlink -f "$f")"
	[[ -z $f ]] \
		&& _editalert "editlevel: no file" \
		&& return 1
	local from="${1:-$fl}"
	from="$(_editline "$from" "$f")"
	[[ -z $from ]] \
		&& _editalert "editlevel: no line" \
		&& return 2
	local line="$(ep $from "$f")"
	if [[ -n $line ]]
	then
		local spaces=0
		local tabs=0
		local res=
		ind=
		local IFS=$'\t\n '
		while true
		do
			[[ ${line:0:1} == $' ' ]] \
				&& spaces=$((spaces + 1)) \
				&& res="${res}[space]" \
				&& ind="$ind " \
				&& line="${line/ /}"
			[[ ${line:0:1} == $'\t' ]] \
				&& tabs=$((tabs + 1)) \
				&& res="${res}[tab]" \
				&& ind="$ind\t" \
				&& line="${line/$'\t'/}"
			[[ ${line:0:1} != $' ' ]] \
				&& [[ ${line:0:1} != $'\t' ]] \
				&& break
		done

		>&2 printf -- "spaces: %s, tabs: %s\n" "$spaces" "$tabs"
		[[ -n $res ]] && >&2 printf -- '%s\n' "$res"
		[[ -n $ind ]] && >&2 printf -- '%s\n' "\$ind="$ind""
	else
		return 4
	fi

	return 0
}

function editexternal {
	local f="${3:-$fn}"
	[[ -n $3 ]] && f="$(readlink -f "$f")"
	[[ -z $f ]] \
		&& _editalert "editexternal: no file" \
		&& return 1
	local from="${1:-$fl}"
	from="$(_editline "$from" "$f")"
	[[ -z $from ]] \
		&& _editalert "editexternal: no start line" \
		&& return 2
	local to="${2:-$fl}"
	to="$(_editline "$to" "$f")"
	[[ -z $to ]] \
		&& _editalert "editexternal: no end line" \
		&& return 3
	if tmux run 2>/dev/null
	then
		editcopy $from $to '' '' "$f"
		! [[ -f $editreadlines ]] \
			&& _editalert "editexternal: editreadlines does not exist" \
			&& return 4
		local size="${edtmuxpsize:-80%}"
		tmux display-popup -h $size -w $size -E "$EDITOR "$editreadlines""
		local res="$(edit "$from,${to}d\nw" "$f")"
		[[ -n $res ]] && printf -- '%s\n' "$res"
		editpaste $(($from - 1)) '' "$f"
		[[ $f == $fn ]] \
			&& fs="$(wc -l "$fn" | cut -d ' ' -f1)" \
			&& [[ $fl -gt $fs ]] && fl="$fs"
	else
		_editalert "editexternal: tmux session not found"
		return 5
	fi

	[[ -f $editreadlines ]] && rm "$editreadlines"
	return 0
}

function etermbin {
	[[ -z $1 ]] \
		&& _editalert "etermbin: no argument" \
		&& return 2
	[[ -n $2 ]] && local fn="$2" && fn="$(readlink -f "$fn")"
	[[ -z $fn ]] \
		&& _editalert "etermbin: no file" \
		&& return 1
	editprint $1 | nc termbin.com 9999
}

function _editfzf {
	local multiple="$1"
	shift
	local preview="$1"
	shift
	local breakwords="$1"
	shift
	local line="$1"
	shift
	[[ -z $* ]] && return 1
	[[ $breakwords -eq 1 ]] \
		&& local data="$(printf -- '%s\n' "$*" | sed 's/\ /\n/g' | \
			sort -n | uniq)" \
		|| local data="$(printf -- '%s\n' "$*" | sort -n | uniq)"
	local size="${edfzfsize:-80%}"
	local psize="${edfzfpsize:-30%}"
	if [[ -n $preview ]]
	then
		if [[ $preview == echo ]]
		then
			printf -- '%s\n' "$data" | fzf-tmux -p ${size},${size} \
				--layout=reverse-list --cycle $multiple \
				--sync --bind "start:pos($line)" \
				--preview-window down,$psize,wrap \
				--preview 'echo {}'
		else
			printf -- '%s\n' "$data" | fzf-tmux -p ${size},${size} \
				--layout=reverse-list --cycle $multiple \
				--sync --bind "start:pos($line)" \
				--preview-window down,$psize,wrap --preview \
				"echo file: {}; echo -----------; cat "$preview/{}""
		fi
	else
		printf -- '%s\n' "$data" | fzf-tmux -p ${size},${size} \
			--layout=reverse-list --cycle $multiple \
			--sync --bind "start:pos($line)"
	fi

	return 0
}

function editwords {
	local f="${1:-$fn}"
	[[ -z $f ]] \
		&& _editalert "editwords: no file" \
		&& return 1
	if tmux run 2>/dev/null
	then
		local words=($(editprint a "$f"))
		local extension="${f/*l/}"
		[[ -z $editdir ]] \
			&& _editalert "editwords: editdir is not set" \
			&& return 2
		! [[ -d $editdir ]] \
			&& _editalert "editwords: editdir does not exist" \
			&& return 3
		! [[ -d $editdir/dict ]] \
			&& _editalert "editwords: dict dir does not exist" \
			&& return 4
		local dict_words="$editdir/dict/words"
		local ext_words="$editdir/dict/$extension"
		local local_words="$(dirname "$f")/.bashed-words"
		[[ -f $dict_words ]] \
			&& local dict="$(cat "$dict_words" | sed 's/\n/ /g')" \
			&& words=(${words[@]} $dict)
		[[ -f $ext_words ]] \
			&& local dict="$(cat "$ext_words" | sed 's/\n/ /g')" \
			&& words=(${words[@]} $dict)
		[[ -f $local_words ]] \
			&& local dict="$(cat "$local_words" | sed 's/\n/ /g')" \
			&& edsound=0 _editalert "loaded $local_words" \
			&& words=(${words[@]} $dict)
		if [[ $(type -t _edithiextract) == function ]]
		then
			local hiwords="$(_edithiextract "$f")"
			[[ -n $hiwords ]] && words=(${words[@]} $hiwords)
		fi

		local res="$(_editfzf '-m' 'echo' 1 1 "${words[@]}")"
	else
		_editalert "editwords: tmux session not found"
		return 2
	fi

	[[ -n $res ]] && tmux send-keys -l "$res"
	return 0
}

function editwordsrc {
	local f="${1:-$fn}"
	[[ -z $f ]] \
		&& _editalert "editwordsrc: no file" \
		&& return 1
	if tmux run 2>/dev/null
	then
		local wordkey="${editwordkey:-o}"
		tmux bind-key $wordkey run -b \
			"bash -ic \"fn=\"$f\"; editwords\""
	else
		return 2
	fi
}

function editdata {
	local f="${1:-$fn}"
	[[ -z $f ]] \
		&& _editalert "editfiles: no file" \
		&& return 1
	local files=
	while read line
	do
		local path=
		if [[ $line =~ ^[~.\/\$.*\/].*$ ]] \
		|| [[ $line =~ ^[a-zA-Z0-9]+:\/\/.*$ ]]
		then
			path="$line"
		elif [[ $line =~ (\'|\")[~.\/\$].*\/.*(\'|\") ]] \
		|| [[ $line =~ (\'|\")[a-zA-Z0-9]+:\/\/.*(\'|\") ]]
		then
			local data="$line"
			local inside=
			for ((i=0; i <= ${#line}; ++i))
			do
				local char="${data:0:1}"
				if [[ $char =~ (\'|\") ]] && [[ $inside == 1 ]]
				then
					inside=0
				elif [[ $char =~ (\'|\") ]] && [[ -z $inside ]]
				then
					inside=1
				else
					[[ $inside == 1 ]] && path="$path$char"
				fi

				data="${data:1:${#data}}"
			done
		fi

		[[ -n $path ]] \
			&& ! [[ $path =~ ^\$\{ ]] \
			&& ! [[ $path =~ ^\$\( ]] \
			&& ! [[ $path =~ ^\.[\ \*] ]] \
			&& ! [[ $path =~ ^\* ]] \
			&& ! [[ $path =~ ^\$.\  ]] \
			&& files="$files
$path"
	done < "$f"

	if [[ ${#files[@]} -gt 0 ]]
	then
		local res="$(_editfzf '' 'echo' 0 1 "${files[@]}")"
		[[ -n $res ]] && $eddatacmd "$res" &
	fi

	return 0
}

function ea { editappend "$@"; }
function ech { editchange "$@"; }
function echl { editchangeline "$@"; }
function ec { editcmd "$@"; }
function ecopy { editcopy "$@"; }
function edata { editdata "$@"; }
function edel { editdelete "$@"; }
function ee { editexternal "$@"; }
function efl { editlocate "$@"; }
function ef { editfind "$@"; }
function eff { editfilefind "$@"; }
function efg { editfindg "$@"; }
function ei { editinsert "$@"; }
function ej { editjoin "$@"; }
function el { editlevel "$@"; }
function em { editmove "$@"; }
function eo { editopen "$@"; }
function epaste { editpaste "$@"; }
function ep { editprint "$@"; }
function eq { editclose "$@"; }
function esu { editsub "$@"; }
function es { editshow "$@"; }
function esf { editshowfzf "$@"; }
function etemp { edittemp "$@"; }
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
	local words=($(edcolor=0 editshow l))
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
			local IFS=$'\n'
			COMPREPLY=($(compgen -f -- $cur))
			;;
	esac
}

complete -o nospace -o filenames -F _editchange editchange
complete -o nospace -o filenames -F _editchange ech

function _editclose {
	local cur=${COMP_WORDS[COMP_CWORD]}
	case "$COMP_CWORD" in
		1)
			COMPREPLY=($(compgen -o nosort -W "delete" -- $cur))
			;;
	esac
}

complete -o nospace -o filenames -F _editclose editclose
complete -o nospace -o filenames -F _editclose eq

function _editcmd {
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
			local IFS=$'\n'
			COMPREPLY=($(compgen -f -- $cur))
			;;
	esac
}

complete -o nospace -o filenames -F _editcmd editcmd
complete -o nospace -o filenames -F _editcmd ec

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
			local IFS=$'\n'
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
			local IFS=$'\n'
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
			local IFS=$'\n'
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
			local IFS=$'\n'
			COMPREPLY=($(compgen -f -- $cur))
			;;
	esac
}

complete -o nospace -o filenames -F _editfind editfind
complete -o nospace -o filenames -F _editfind ef
complete -o nospace -o filenames -F _editfind editfindg
complete -o nospace -o filenames -F _editfind efg

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
		4)
			COMPREPLY=($(compgen -o nosort -W "cache new" -- $cur))
			;;
		*)
			local IFS=$'\n'
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
			local IFS=$'\n'
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
			local IFS=$'\n'
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
			local IFS=$'\n'
			COMPREPLY=($(compgen -f -- $cur))
			;;
	esac
}

complete -o filenames -F _editopen editopen
complete -o filenames -F _editopen eo

function _editshow {
	local cur=${COMP_WORDS[COMP_CWORD]}
	case "$COMP_CWORD" in
		1)
			COMPREPLY=($(compgen -W "a b c d e f fz g G l m mf n p u \
				v / . $ + -" -- $cur))
			;;
		*)
			local IFS=$'\n'
			COMPREPLY=($(compgen -f -- $cur))
			;;
	esac
}

complete -o nospace -o filenames -F _editshow editshow
complete -o nospace -o filenames -F _editshow es
complete -o nospace -o filenames -F _editshow etermbin
complete -o nospace -o filenames -F _editshow editprint
complete -o nospace -o filenames -F _editshow ep
complete -o nospace -o filenames -F _editshow editshowfzf
complete -o nospace -o filenames -F _editshow esf

function _editpaste {
	local cur=${COMP_WORDS[COMP_CWORD]}
	case "$COMP_CWORD" in
		1)
			COMPREPLY=($(compgen -o nosort -W "$ + ." -- $cur))
			;;
		2)
			COMPREPLY=($(compgen -W "w x" -- $cur))
			;;
		*)
			local IFS=$'\n'
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
			local IFS=$'\n'
			COMPREPLY=($(compgen -f -- $cur))
			;;
	esac
}

complete -o nospace -o filenames -F _editsub editsub
complete -o nospace -o filenames -F _editsub esu

function _edittemp {
	local cur=${COMP_WORDS[COMP_CWORD]}
	case "$COMP_CWORD" in
		1)
			COMPREPLY=($(compgen -o nosort -W "create clean" -- $cur))
			;;
	esac
}

complete -o nospace -o filenames -F _edittemp edittemp
complete -o nospace -o filenames -F _edittemp etemp

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
			local IFS=$'\n'
			COMPREPLY=($(compgen -f -- $cur))
			;;
	esac
}

complete -o nospace -o filenames -F _edittransfer edittransfer
complete -o nospace -o filenames -F _edittransfer ey

