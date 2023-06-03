#!/usr/bin/env bash

! [[ -d $editdir/net ]] && mkdir -p "$editdir/net"

enet_dillo="dillo '%arg%'"
enet_falkon="falkon '%arg%'"
enet_falkon_firejail="firejail --private=~/firejail falkon '%arg%'"
enet_firefox="firefox '%arg%'"
enet_firefox_firejail="firejail --private=~/firejail firefox '%arg%'"
enet_firefox_firejail_private="firejail --private=~/firejail firefox --private-window '%arg%'"
enet_lagrange="lagrange '%arg%'"
enet_links="links -g -html-g-background-color 0x7eacc8 '%arg%'"
enet_lynx="lynx -lss=~/.lynx.lss '%arg%'"
enet_netsurf="netsurf --window_height 700 '%arg%'"
enet_seamonkey="seamonkey '%arg%'"
enet_seamonkey_firejail="firejail --private=~/firejail seamonkey '%arg%'"

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

enet_default_browser="links -g -html-g-background-color 0x7eacc8 '%arg%'"

enet_searchengine=(
	"archwiki:::https://wiki.archlinux.org/index.php?search=%arg%"
	"bing:::http://www.bing.com/search?q=%arg%"
	"brave:::https://search.brave.com/search?q=%arg%&source=web&="
	"duckduckgo:::https://duckduckgo.com/?q=%arg%&kp=-2\&ia=news"
	"google:::https://www.google.com/search?q=%arg%"
	"yandex:::https://yandex.com/search/?text=%arg%"
)

enet_xine_webm="xine -l '%arg%'"
enet_xine="xine '%arg%'"
enet_feh="feh --scale-down -B DarkSlateGray '%arg%'"
enet_mpv="mpv --no-msg-color '%arg%'"
enet_sxiv_gif="wget '%arg%' -O /tmp/image.gif; sxiv -a /tmp/image.gif"

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
enet_video_player="$enet_xine"

function enet_video_download {
	local url="$1"
	[[ $url == . ]] && url="$(edcmd=p e "${fl}p" "$fn")"
	[[ -z $url ]] && url="$(edcmd=p e "${fl}p" "$fn")"
	[[ -z $url ]] && return 2
	local video_name="$(yt-dlp --print filename "$url")"
	local title="%(title)s.%(ext)s"
	local quality="18/480p/720p/best"
	date >> "$enet_videolog"
        printf -- "%s\n" "$video_name" >> "$enet_videolog"
        printf -- "%s\n\n" "$url" >> "$enet_videolog"
        notify-send "Downloading video $video_name"
        yt-dlp -i -o "$enet_download_dir/$title" -f "$quality" "$url"
	return $?
}

function enet_video_watch {
	local url="$1"
	[[ $url == . ]] && url="$(edcmd=p e "${fl}p" "$fn")"
	[[ -z $url ]] && url="$(edcmd=p e "${fl}p" "$fn")"
	[[ -z $url ]] && return 2
	enet_video_download "$url"
	if [[ $? == 0 ]]
	then
		local video="$(ls -c "$enet_download_dir" | head -1)"
		local player="${enet_video_player}"
		player="${player//%arg%/$enet_download_dir/$video}"
		eval "$player"
	fi
}

enet_video="enet_video_watch '%arg%'"
enet_audio_format="mp3"

function enet_video_extract_audio {
	local url="$1"
	[[ $url == . ]] && url="$(edcmd=p e "${fl}p" "$fn")"
	[[ -z $url ]] && url="$(edcmd=p e "${fl}p" "$fn")"
	[[ -z $url ]] && return 2
	notify-send "Downloading audio from $url"
	local title="%(title)s.%(ext)s"
        yt-dlp --extract-audio --audio-format "$enet_audio_format" \
	                -o "$enet_download_dir/$title" "$url"
        notify-send "Downloading audio from $url finished"
}

function enet_video_assemble_playlist {
	local url="$1"
	[[ $url == . ]] && url="$(edcmd=p e "${fl}p" "$fn")"
	[[ -z $url ]] && url="$(edcmd=p e "${fl}p" "$fn")"
	[[ -z $url ]] && return 2
	local playlist_json="yt-dlp --flat-playlist -j '%arg%'"
	playlist_json="${playlist_json//%arg%/$url}"
	local result_json="$(eval $playlist_json)"
	local IFS=$'\n'
	local urls=($(echo "$result_json" | cut -d ',' -f4))
	local titles=($(echo "$result_json" | cut -d ',' -f5))
	for ((i=0; i < ${#urls[@]}; ++i))
	do
		local video="${urls[$i]}"
		local video_url="${video/\"url\": /}"
		local video_url="${video_url/ /}"
		local title="${titles[$i]}"
		local video_title="${title/\"title\": /}"
		printf -- '- %s\n%s\n\n' "${video_title//\"/}:" "${video_url//\"/}"
	done
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
		local url="$2"
		[[ $url == . ]] && url="$(edcmd=p e "${fl}p" "$fn")"
		[[ -z $url ]] && url="$(edcmd=p e "${fl}p" "$fn")"
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
				command="${command//%arg%/$url}"
				eval "$command"
				return
			fi
		done

		for i in ${enet_bookmark[@]}
		do
			local name="${i/:::*/}"
			local address="${i/*:::/}"
			if [[ $url =~ $name ]]
			then
				browser="${browser//%arg%/$address}"
				eval "$browser"
				return
			fi
		done

		browser="${browser//%arg%/$url}"
		eval "$browser"
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
		browser="${browser//%arg%/$engine_url}"
		eval "$browser"
	elif [[ $1 == download ]] || [[ $1 == d ]]
	then
		local url="$2"
		[[ $url == . ]] && url="$(edcmd=p e "${fl}p" "$fn")"
		[[ -z $url ]] && url="$(edcmd=p e "${fl}p" "$fn")"
		[[ -z $url ]] && return 2
		wget -c "$url"
	elif [[ $1 == download-video ]] || [[ $1 == dv ]]
	then
		local url="$2"
		[[ $url == . ]] && url="$(edcmd=p e "${fl}p" "$fn")"
		[[ -z $url ]] && url="$(edcmd=p e "${fl}p" "$fn")"
		[[ -z $url ]] && return 2
		enet_video_download "$url"
	elif [[ $1 == download-audio ]] || [[ $1 == da ]]
	then
		local url="$2"
		[[ $url == . ]] && url="$(edcmd=p e "${fl}p" "$fn")"
		[[ -z $url ]] && url="$(edcmd=p e "${fl}p" "$fn")"
		[[ -z $url ]] && return 2
		enet_video_extract_audio "$url"
	elif [[ $1 == playlist ]] || [[ $1 == pl ]]
	then
		local url="$2"
		[[ $url == . ]] && url="$(edcmd=p e "${fl}p" "$fn")"
		[[ -z $url ]] && url="$(edcmd=p e "${fl}p" "$fn")"
		[[ -z $url ]] && return 2
		enet_video_assemble_playlist "$url"
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
				download-audio da playlist pl" \
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
