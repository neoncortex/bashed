#!/usr/bin/env bash

babeldir="$editdir/babel"
babelblock="$babeldir/block"

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

babel_sh="bash %src%"
babel_python="python3 %src%"
babel_python2="python %src%"
babel_c="gcc %src% && ./a.out"
babel_yasm="yasm -g dwarf2 -f elf64 %src% -o asm.o && ld -g asm.o -o asm && ./asm"
babel_yasm_gcc="yasm -g dwarf2 -f elf64 %src% -o asm.o && gcc -g asm.o -o asm \
	&& ./asm"
babel_yasm_gcc_no_pie="yasm -g dwarf2 -f elf64 %src% -o asm.o \
	&& gcc -g -no-pie asm.o -o asm && ./asm"
babel_exec=(
	"bash:::babel_sh"
	"sh:::babel_sh"
	"tex-png:::babel_tex_png"
	"python:::bale_python"
	"python2:::babel_python"
	"c:::babel_c"
	"yasm:::babel_yasm"
	"yasm-gcc:::babel_yasm_gcc"
	"yasm-gcc-no-pie:::babel_yasm_gcc_no_pie"
)
function babel {
	local block_line="$fl"
	[[ -n $1 ]] && block_line="$1"
	[[ -n $2 ]] && local fn="$2" && local fs="$(wc -l "$fn" | cut -d ' ' -f1)"
	[[ -z $fn ]] && return 1
	! [[ -d $babeldir ]] && mkdir -p "$babeldir"
	if ! [[ $block_line =~ ^[0-9]+$ ]]
	then
		local n=1
		while read -r line
		do
			if [[ $line =~ \#\+name:\ ?${block_line}$ ]]
			then
				local block_line="$n"
				break
			fi

			n="$((n + 1))"
		done < "$fn"
	fi

	local block_header="$(e $((block_line + 1))p "$fn")"
	local IFS=$' '
	local index=0
	for i in $block_header
	do
		case $index in
		1)
			local lang="$i"
			;;
		2)
			local syntax="$i"
			;;
		3)
			local dir="$i"
			;;
		4)
			local noweb="$i"
			;;
		5)
			local tangle="$i"
			;;
		esac

		index="$((index + 1))"
	done

	[[ -f $babelblock ]] && rm "$babelblock"
	local n="$((block_line + 1))"
	local IFS=$'\n'
	while true
	do
		local line="$(e ${n}p "$fn")"
		if [[ $line == "#+end_src" ]]
		then
			break
		elif [[ $line =~ ^\<\<.*\>\>$ ]] && [[ $noweb -eq 1 ]]
		then
			local b="${line/\<\</}"
			local b="${b/\>\>/}"
			babel "$b" "$fn"
		else
			echo "$line" >> "$babelblock"
		fi

		n="$((n + 1))"
	done

	[[ $tangle != "0" ]] && cp "$babelblock" "$tangle"
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

