#!/usr/bin/env bash

enetdir="$editdir/net"
! [[ -d $editdir/net ]] && mkdir -p "$enetdir"

enet_dillo="dillo %arg%"
enet_falkon="falkon %arg%"
enet_falkon_firejail="firejail --private=~/firejail falkon %arg%"
enet_firefox="firefox %arg%"
enet_firefox_firejail="firejail --private=~/firejail firefox %arg%"
enet_firefox_firejail_private="firejail --private=~/firejail firefox --private-window %arg%"
enet_lagrange="lagrange %arg%"
enet_links="links -g -html-g-background-color 0x7eacc8 %arg%"
enet_lynx="lynx -lss=~/.lynx.lss %arg%"
enet_netsurf="netsurf --window_height 700 %arg%"
enet_seamonkey="seamonkey %arg%"
enet_seamonkey_firejail="firejail --private=~/firejail seamonkey %arg%"

enet_browser=(
	"dillo:::enet_dillo"
	"falkon:::enet_falkon"
	"falkon-firejail:::enet_falkon_firejail"
	"firefox:::enet_firefox"
	"firefox-firejail:::enet_firefox_firejail"
	"firefox-firejail-private:::enet_firefox_firejail_private"
	"lagrange:::enet_lagrange"
	"links:::enet_links"
	"lynx:::enet_lynx"
	"netsurf:::enet_netsurf"
	"seamonkey:::enet_seamonkey"
	"seamonkey-firejail:::enet_seamonkey_firejail"
)

enet_default_browser="links -g -html-g-background-color 0x7eacc8 %arg%"

enet_searchengine=(
	"archwiki:::https://wiki.archlinux.org/index.php?search=%arg%"
	"bing:::http://www.bing.com/search?q=%arg%"
	"brave:::https://search.brave.com/search?q=%arg%&source=web&="
	"duckduckgo:::https://duckduckgo.com/?q=%arg%&kp=-2\&ia=news"
	"google:::https://www.google.com/search?q=%arg%"
	"yandex:::https://yandex.com/search/?text=%arg%"
)

enet_xine_webm="xine -l %arg%"
enet_xine="xine %arg%"
enet_feh="feh --scale-down -B DarkSlateGray %arg%"
enet_sxiv_gif="wget %arg% -O $enetdir/image.gif; sxiv -a $enetdir/image.gif"

enet_pattern=(
	".*:\/\/invidious\.snopyta\.org\/watch:::enet_video"
	".*:\/\/m\.youtube\.com\/watch:::enet_video"
	".*:\/\/www\.youtube\.com\/watch:::enet_video"
	".*:\/\/youtu\.be\/watch:::enet_video"
	".*:\/\/youtu\.be\/watch:::enet_video"
	".*:\/\/youtube\.com\/watch:::enet_video"
	".*:\/\/youtube\.com\.br\/watch:::enet_video"
	"\.gif$:::enet_sxiv_gif"
	"^(gopher|gemini):::enet_lagrange"
	"\.jpg$:::enet_feh"
	"\.jpeg$:::enet_feh"
	"\.tiff$:::enet_feh"
	"\.png$:::enet_feh"
	"\.mp4$:::enet_xine"
	"\.webm$:::enet_xine_webm"
)

enet_bookmark=(
	"%slackware%:::http://www.slackware.com/"
)

enet_videolog="$editdir/net/video.log"
enet_download_dir="$HOME/Downloads"
enet_video_quality="18/480p/720p/best"
enet_video_player="$enet_xine"

function enet_get_url {
	local url="$1"
	if [[ $url == . ]] || [[ -z $url ]]
	then
		url="$(edcmd=p e "${fl}p" "$fn")"
	fi

	[[ -z $url ]] && return 1 || echo "$url"
}

function enet_exec {
	[[ -z $1 ]] && return 1
	[[ -z $2 ]] && return 2
	local str="$1"
	shift
	local IFS=$'\n\t '
	local cmd=($@)
	for ((i=0; i < "${#cmd[@]}"; ++i))
	do
		if [[ ${cmd[$i]} =~ %arg% ]]
		then
			local arg="${cmd[$i]}"
			arg="${arg//%arg%/$str}"
			cmd[$i]="$arg"
		fi
	done
	
	"${cmd[@]}"
}

function enet_video_download {
	local url="$(enet_get_url "$1")"
	[[ -z $url ]] && return 2
	local title="%(title)s.%(ext)s"
	local video_name="$(enet_exec "$url" \
		"yt-dlp -f "$enet_video_quality" --print "$title" %arg%")"
	date >> "$enet_videolog"
        printf -- "%s\n" "$video_name" >> "$enet_videolog"
        printf -- "%s\n\n" "$url" >> "$enet_videolog"
        notify-send "Downloading video $video_name"
	enet_exec "$url" "yt-dlp -i -o "$enet_download_dir/$title" \
		-f "$enet_video_quality" %arg%"
	[[ $? == 0 ]] \
		&& touch "$enet_download_dir/$video_name" \
		|| return 1
}

function enet_yt_thumbnail {
	local url="$(enet_get_url "$1")"
	[[ -z $url ]] && return 2
	[[ -n $2 ]] && output="$2"
	local video_id="$(enet_exec "$url" "yt-dlp --print "%\(id\)s" %arg%")"
	[[ -n $output ]] \
		&& wget "https://i.ytimg.com/vi/$video_id/sddefault.jpg" -O "$output" \
		|| wget "https://i.ytimg.com/vi/$video_id/sddefault.jpg" -O "$video_id.jpg"
}

function enet_thumbnail {
	local url="$(enet_get_url "$1")"
	[[ -z $url ]] && return 2
	[[ -n $2 ]] && output="$2"
	local result_json="$(enet_exec "$url" "yt-dlp --flat-playlist -j %arg%")"
	local IFS=$'\n'
	local video_id="$(echo "$result_json" | jq -r '.id')"
	local thumb="$(echo "$result_json" | jq -r '[.thumbnails[].url][-1]')"
	if [[ -n $thumb ]]
	then
		[[ -n $output ]] \
			&& enet_exec "$thumb" "wget %arg% -O $output.jpg" \
			|| enet_exec "$thumb" "wget %arg% -O $video_id.jpg"
	fi
}

function enet_video_watch {
	local url="$(enet_get_url "$1")"
	[[ -z $url ]] && return 2
	enet_video_download "$url"
	if [[ $? == 0 ]]
	then
		local IFS=
		local video=
		for i in $enet_download_dir/*
		do
			[[ $i -nt $video ]] && video="$i"
		done

		enet_exec "$video" "$enet_video_player"
	fi
}

enet_video="enet_video_watch %arg%"
enet_audio_format="mp3"

function enet_video_extract_audio {
	local url="$(enet_get_url "$1")"
	[[ -z $url ]] && return 2
	local title="%(title)s"
	local video_name="$(enet_exec "$url" "yt-dlp --print "$title" %arg%")"
	notify-send "Extracting audio from $video_name"
	local title="%(title)s.%(ext)s"
	enet_exec "$url" "yt-dlp --extract-audio --audio-format \
		"$enet_audio_format" -o "$enet_download_dir/$title" %arg%"
	notify-send "Extracting audio from $video_name finished"
}

function enet_video_assemble_playlist {
	local url="$(enet_get_url "$1")"
	[[ -z $url ]] && return 2
	[[ -n $2 ]] \
		&& local filename="$2" \
		&& { [[ -f $filename ]] && rm "$filename"; }
	local result_json="$(enet_exec "$url" "yt-dlp --flat-playlist -j %arg%")"
	local IFS=$'\n'
	local keys=($(echo "$result_json" | jq -r '.ie_key'))
	local ids=($(echo "$result_json" | jq -r '.id'))
	local urls=($(echo "$result_json" | jq -r '.url'))
	local titles=($(echo "$result_json" | jq -r '.title'))
	local thumbs=($(echo "$result_json" | jq -r '[.thumbnails[].url][-1]'))
	for ((i=0; i < ${#urls[@]}; ++i))
	do
		local video_url="${urls[$i]}"
		local video_title="${titles[$i]}"
		if [[ -z $filename ]]
		then
			printf -- '- %s\n%s\n\n' "$video_title:" \
				"$video_url"
		else
			local video_key="${keys[$i]}"
			local video_id="${ids[$i]}"
			echo "- $video_title:" >> "$filename"
			mkdir -p img
			if [[ $video_key ==  Youtube ]]
			then
				enet_yt_thumbnail "$video_url" \
					"img/${video_id}.jpg"
				echo "$PWD/img/${video_id}.jpg" >> "$filename"
			else
				local thumb="${thumbs[$i]}"
				[[ -n $thumb ]] \
					&& enet_exec "$thumb" "wget %arg% \
						-O img/$video_id.jpg"
				echo "$PWD/img/$video_id.jpg" >> "$filename"
			fi

			echo "$video_url" >> "$filename"
			echo >> "$filename"
		fi
	done

	[[ -f $filename ]] && (es a "$filename")
}

function eurl_encode {
	for ((i=0; i < ${#1}; ++i))
	do
		local char="${1:i:1}"
	        [[ "$char" == [a-zA-Z0-9.~_-] ]] \
			&& printf "$char" \
			|| printf '%%%02X' "'$char"
	done
}

function editnet_browser {
	[[ -z $1 ]] && return 1
	local browser="$ednet_default_browser"
	for i in ${enet_browser[@]}
	do
		local name="${i/:::*/}"
		local command="${i/*:::/}"
		[[ $name == $1 ]] \
			&& browser="$command" \
			&& browser="${!browser}" \
			&& break
	done

	echo "$browser"
}

function editnet {
	[[ -z $1 ]] && return 1
	if [[ $1 == url ]] || [[ $1 == u ]]
	then
		local url="$(enet_get_url "$2")"
		[[ -z $url ]] && return 2
		local browser="$enet_default_browser"
		[[ -n $3 ]] && browser="$(editnet_browser "$3")"
		local IFS=
		for i in ${enet_pattern[@]}
		do
			local pattern="${i/:::*/}"
			local action="${i/*:::/}"
			if [[ $url =~ $pattern ]]
			then
				local command="${!action}"
				enet_exec "$url" "$command"
				return
			fi
		done

		for i in ${enet_bookmark[@]}
		do
			local name="${i/:::*/}"
			local address="${i/*:::/}"
			if [[ $url =~ $name ]]
			then
				enet_exec "$address" "$browser"
				return
			fi
		done

		browser="${browser//%arg%/$url}"
		enet_exec "$url" "$browser"
	elif [[ $1 == search ]] || [[ $1 == s ]]
	then
		[[ -z $2 ]] && return 3
		local engine="$2"
		local engine_url=
		[[ -z $3 ]] && return 4 || local text="$3"
		local browser="$enet_default_browser"
		[[ -n $4 ]] && browser="$(editnet_browser "$4")"
		for i in ${enet_searchengine[@]}
		do
			local name="${i/:::*/}"
			local address="${i/*:::/}"
			[[ $name == $engine ]] && engine_url="$address" && break
		done

		[[ -z $engine_url ]] && return 5
		local encoded_text="$(eurl_encode "$text")"
		engine_url="${engine_url//%arg%/$encoded_text}"
		enet_exec "$engine_url" "$browser"
	elif [[ $1 == download ]] || [[ $1 == d ]]
	then
		local url="$(enet_get_url "$2")"
		[[ -z $url ]] && return 2
		wget -c "$url"
	elif [[ $1 == download-video ]] || [[ $1 == dv ]]
	then
		local url="$(enet_get_url "$2")"
		[[ -z $url ]] && return 2
		enet_video_download "$url"
	elif [[ $1 == download-audio ]] || [[ $1 == da ]]
	then
		local url="$(enet_get_url "$2")"
		[[ -z $url ]] && return 2
		enet_video_extract_audio "$url"
	elif [[ $1 == playlist ]] || [[ $1 == pl ]]
	then
		local url="$(enet_get_url "$2")"
		[[ -z $url ]] && return 2
		enet_video_assemble_playlist "$url" "$3"
	elif [[ $1 == thumb ]]
	then
		local url="$(enet_get_url "$2")"
		[[ -z $url ]] && return 2
		enet_thumbnail "$url" "$3"
	elif [[ $1 == ythumb ]]
	then
		local url="$(enet_get_url "$2")"
		[[ -z $url ]] && return 2
		enet_yt_thumbnail "$url" "$3"
	fi
}

function enet { editnet "$@"; }

function _editnet_completion {
	local completion=()
	local entries=("$*")
	for i in ${entries[@]}
	do
		completion+=("${i/:::*/}")
	done

	echo "${completion[@]}"
}

function _editnet {
	local cur=${COMP_WORDS[COMP_CWORD]}
	case "$COMP_CWORD" in
		1)
			COMPREPLY=($(compgen -W \
				"url u search s download d download-video dv \
				download-audio da playlist pl thumb ythumb" \
				-- $cur))
			;;
		2)
			local prev=${COMP_WORDS[COMP_CWORD-1]}
			if [[ $prev == search ]] || [[ $prev == s ]]
			then
				COMPREPLY=($(compgen -W \
					"$(_editnet_completion "${enet_searchengine[@]}")" \
					-- $cur))
			elif [[ $prev == url ]] || [[ $prev == u ]]
			then
				COMPREPLY=($(compgen -W \
					"$(_editnet_completion "${enet_bookmark[@]}")" \
					-- $cur))
			fi
			;;
		3)
			local prev=${COMP_WORDS[COMP_CWORD-2]}
			if [[ $prev == url ]] || [[ $prev == u ]]
			then
				COMPREPLY=($(compgen -W \
					"$(_editnet_completion "${enet_browser[@]}")" \
					-- $cur))
			fi
			;;
		4)
			local prev=${COMP_WORDS[COMP_CWORD-3]}
			if [[ $prev == search ]] || [[ $prev == s ]]
			then
				COMPREPLY=($(compgen -W \
					"$(_editnet_completion "${enet_browser[@]}")" \
					-- $cur))
			fi
			;;
		*)
			COMPREPLY=($(compgen -o default -- $cur))
			;;
	esac
}

complete -F _editnet editnet
complete -F _editnet enet
