#!/usr/bin/env bash

babeldir="$editdir/babel"
babelblock="$babeldir/block"

babel_as="as -o a.o %src% && ld -o a.out a.o && ./a.out"
babel_c="gcc -Wall %src% && ./a.out"
babel_cpp="g++ -Wall %src% && .a.out"
babel_dc="cat %src% | dc"
babel_python="python3 %src%"
babel_python_2="python %src%"
babel_sh="bash %src%"
babel_tex_png="
echo -e '\
\documentclass[12pt]{slides}
\usepackage[mathletters]{ucs}
\usepackage{textcomp}
\usepackage{polyglossia}
\usepackage{amsmath}
\usepackage[normalem]{ulem}
\usepackage{cancel}
\usepackage{xcolor}
\usepackage{tikz}
\usepackage{gensymb}
\usepackage{svg}
\usepackage{arcs}
\usepackage{yhmath}
\usepackage{amssymb}' > tex_png.tex; \
cat %src% >> tex_png.tex; \
xelatex -no-pdf -interaction nonstopmode tex_png.tex; \
dvisvgm -n -b min tex_png.xdv > tex_png.svg; \
convert -trim -quality 100 -density 1000 tex_png.svg tex_png.png ;\
rm tex_png.xdv tex_png.tex tex_png.aux tex_png.log tex_png.svg"
babel_yasm="yasm -g dwarf2 -f elf64 %src% -o asm.o && ld -g asm.o -o asm && ./asm"
babel_yasm_gcc="yasm -g dwarf2 -f elf64 %src% -o asm.o && gcc -g asm.o -o asm \
	&& ./asm"
babel_yasm_gcc_no_pie="yasm -g dwarf2 -f elf64 %src% -o asm.o \
	&& gcc -g -no-pie asm.o -o asm && ./asm"

babel_exec=(
	"asm:::babel_as"
	"bash:::babel_sh"
	"c:::babel_c"
	"cpp:::babel_cpp"
	"dc:::babel_dc"
	"python:::bale_python"
	"python2:::babel_python"
	"sh:::babel_sh"
	"tex-png:::babel_tex_png"
	"yasm:::babel_yasm"
	"yasm-gcc:::babel_yasm_gcc"
	"yasm-gcc-no-pie:::babel_yasm_gcc_no_pie"
)

function babel {
	local block_line="$fl"
	[[ -n $1 ]] && block_line="$1"
	[[ -n $2 ]] && local fn="$2"
	[[ $fn =~ ^%.*% ]] && fn="$(edbq files "$fn")"
	[[ -z $fn ]] && return 1
	! [[ -f $fn ]] && return 1
	! [[ -d $babeldir ]] && mkdir -p "$babeldir"
	if ! [[ $block_line =~ ^[0-9]+$ ]]
	then
		local found=0
		local n=1
		while read -r line
		do
			if [[ $line =~ \#\+name:\ ?${block_line}$ ]]
			then
				local block_line="$n"
				found=1
				break
			fi

			n="$((n + 1))"
		done < "$fn"

		[[ $found -eq 0 ]] && return 2
	fi

	local block_header="$(e $((block_line + 1))p "$fn")"
	local IFS=$' '
	local index=0
	local lang=0
	local syntax=0
	local dir=0
	local noweb=0
	local tangle=0
	for i in $block_header
	do
		case $index in
		1)
			lang="$i"
			;;
		2)
			syntax="$i"
			;;
		3)
			dir="$i"
			;;
		4)
			noweb="$i"
			;;
		5)
			tangle="$i"
			;;
		esac

		index="$((index + 1))"
	done

	[[ -z $3 ]] && [[ -f $babelblock ]] && rm "$babelblock"
	local fs="$(wc -l "$fn" | cut -d ' ' -f1)"
	local n="$((block_line + 2))"
	local IFS=$'\n'
	while true
	do
		[[ $n -gt $fs ]] && break
		local line="$(e ${n}p "$fn")"
		if [[ $line == "#+end_src" ]]
		then
			break
		elif [[ $line =~ ^\<\<.*\>\>$ ]] && [[ $noweb -eq 1 ]]
		then
			local b="${line/\<\</}"
			local b="${b/\>\>/}"
			if [[ $b =~ ::: ]]
			then
				local block_name="${b/*:::/}"
				local file_name="${b/:::*/}"
				babel "$block_name" "$file_name" 1
			else
				babel "$b" "$fn" 1
			fi
		else
			echo "$line" >> "$babelblock"
		fi

		n="$((n + 1))"
	done

	[[ $3 -eq 1 ]] && return 0
	[[ $tangle != "0" ]] && cp "$babelblock" "$tangle" && return 0
	for ((i=0; i < ${#babel_exec[@]}; i++))
	do
		pattern="${babel_exec[$i]/:::*}"
		command="${babel_exec[$i]/*:::}"
		if [[ "$lang" == "$pattern" ]]
		then
			command="${!command}"
			command="${command//%src%/$babelblock}"
			eval $command
			break
		fi
	done
}

function _babelcompletion {
	[[ -z $fn ]] && return 1
	local blocks=()
	while read -r line
	do
		if [[ $line =~ ^\#\+name: ]]
		then
			local b="${b/\#\+name:\ /}"
			b="${line/\#\+name:/}"
			blocks+=("$b")
		fi
	done < "$fn"

	echo "${blocks[@]}"
}

function _babel {
	local cur=${COMP_WORDS[COMP_CWORD]}
	case "$COMP_CWORD" in
		1)
			local blocks="$(_babelcompletion)"
			COMPREPLY=($(compgen -o nosort -W "$blocks" -- $cur))
			;;
		*)
			COMPREPLY=($(compgen -o default))
			;;
	esac
}

complete -F _babel babel
