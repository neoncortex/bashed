# bashed
bash wrapper for the ed editor.

# What it is:
It is a collection of functions that wraps the ed functionalities, and manage the files and windows using tmux, and fzf.  This allows files to be edited directly from the bash prompt.  It offers features like versioning, content searching, syntax highlight, and others.

# How it works:
It keeps state, the file opened, current line, and various others,  with shell variables, and files.

# Dependencies:
- ed;
- fzf;
- tmux 3.2, or above;

## Optional:
- highlight;
- wl-clipboard;
- xclip;
- ffplay;

# Configuration:
Add to your ~/.bashrc:

````
source /path/to/bashed/bashed.sh
````

## User interface:
Since it is a prompt editor, the user will have no indication of which file is opened, unless some customizations in the environinment are made.  Below are two suggested ways to configure bash and tmux to show the file opened, its size, and the current line.

### bash prompt:
The function below will show in the bash prompt the file size, and current line.  Plus it will show the return results of commands.  In ~/.bashrc:

````
function prompt {
	local dir="\[\e[0;32m\][\W]\[\e[0m\]"
	local return="\[\e[0;33m\]\$?\[\e[0m\]"
	if [[ -n $fl ]] && [[ -n $fs ]]
	then
		local edprompt="\[\e[0;32m\][$fl][$fs]\[\e[0m\]"
		PS1="$dir-$return-$edprompt-$ "
	else
		PS1="$dir-$return-$ "
	fi
}

PROMPT_COMMAND=prompt
````

### tmux pane name:
The tmux options below will make tmux show the pane name, and the opened file path and name in it's pane name, in case there is a opened file.  In ~/.tmux.conf:

````
set -g pane-border-status top
set -g pane-border-format "#T, #P, #{pane_current_command}"
set-window-option -g pane-active-border-style "fg=green,bold"
set-option -g display-panes-time 10000
````

# How to use it:
## Opening files:
````
editopen file
````

or eo, for short.  eo can receive an argument specifying that the file should be opened in a new tmux panel.  A new panel can be: u for up, d for down, l for left, r for right, n, for new window.

For example, to open a file into a new panel on top of the current one:

````
eo file u
````

Also, you can subdivide an existing pane.  Lets say you window have two panes, and you want to subdivide the unfocused pane, then: ul, for subdivide the upper pane, and open in the left, ur, for subdividing the upper pane, and open on the right, lu, for subdivide the left pane, and open on the top, ld, for subdivide the left pane, and open on the bottom, rl and rd does the same as lu and ld, but for the right pane, and dl and dr does the same as ul and ur, but for the bottom pane.  This argument, when 0, have no effect, and the file will be opened on the current pane.

### File arguments:
Files can be opened with arguments. These arguments can specify a line, or a string.  Examples:

````
eo file:10
eo file:'hello world'
````

In the first command, file will be opened, and the line 10 will be setted as the current line.  On the second, file will be opened, the string "hello world" will be searched, and the line containing that string will be setted as the current line.

## Closing files:
````
eq
````

## Finding files:
It is possible to search for file contents using editfilefind, or eff, for short:

````
eff content
````

It will search in the files on current directory for content using grep, and present the results in fzf.  To search recursively:

````
eff content r
````

A third argument can be passed, specifying where the file should be opened.  This argument is the same as the second eo argument, it specifies the pane that file will be opened.  For example, to open it in a new left pane:

On the current directory only:
````
eff content 0 l
````

Or recursively:
````
eff content r l
````

The results will be cached, and the next search using the same words, in the same directory, will display the cached results.  To make a new search, without using the cached results, a 4th argument, new, is used:

````
eff content r 0 new
````

## Specifying lines to edit:
Lines can be referenced like the following:
- a . is the current line of a opened file;
- +n is the current line + n lines, for example, +2;
- -n is the current line - n lines, for example, -2;
- $ is the last line;

## Adding line:
### Append:
````
ea line of text.
ea 'another line of text.'
````

The text will be appended after the current focused line.  Without arguments, a blank line will be added.

It also accepts piped text:
````
echo some text | ea
````

### Insert:
````
ei line of text.
````

The text will be inserted in the current line - 1.

It also accepts piped text:
````
echo some text | ei
````

## Deleting:
### Deleting line:
````
edel
````

Without any arguments, edel will delete the current line of the current file.

### Deleting range:
````
edel start-line end-line file?
````

 The lines from the start-line to end-line will be deleted.

file is optional, if given, the text in that file will be deleted. 

## Changing:
### Changing line:
````
ech start-line end-line "new text." file?
````

Will change the the lines to "new text.".  file is optional, if given, the text in that file will be changed.

You can also use echl, that will change only the current line of the current file, but it will autocomplete the current line contents.

````
echl new content.
````

Both accepts piped text:
````
echo some text | ech
echo some text | echl
````

## Copying:
### Copy line:
````
ey start-line end-line dest-line file?
````

The lines from start-line to end-line will be copied to the dest-line.

### Yank:
Lines can be "yanked" like follows:

````
ey start-line end-line
````

This will copy the current line to the variable $yank.

## ecopy and epaste:
ecopy and epaste are two functinos that allows to copy and paste a portion of a text file to a temporary location, or the X/Wayland clipboard, so it can be pasted in another shell, file, etc.  The temporary location will be ~/.edit/readlines.

### ecopy:
ecopy works that way:
````
ecopy start-line end-line [x|w]? cut? file?
````

For example, to copy the current line:
````
ecopy
````

to copy from the line 1 to 5, to X11 clipboard, using xclip:
````
ecopy 1 5 x
````

to copy the current line to Wayland clipboard, using wl-copy:
````
ecopy . . w
````
#### cut:
You can cut the lines by using:
````
ecopy . . 0 cut
````

Or to copy to X11 clipboard:
````
ecopy . . x cut
````

and so on.

### epaste:
epaste works the same as ecopy.  For example, to paste in the current line:

````
epaste
````

to paste in the current line from the X11 clipboard, using xclip:
````
epaste . . x
````

to paste in the 
## Joining:
### Joining lines:
````
ej
````

Will join the current line with the next.

### Joining range:
````
ej start-line end-line file?
````

That will join from the start-line to the end-line.

## Moving:
````
em start-line end-line dest-line file?
````

Will move from start-line to end-line, to the dest-line.

## Substitution:
````
esu start-line end-line "regex-src" "result" g? file?
````

The g argument, and the file argument are optional.  g will make every ocurrence of "a" to be substitued with "b" in the specified range of lines, and file will make the substition in that file istead of the current file.

## Searching:
The most common searching mechanism would be:

````
ef 'g/re/n'
````

This will return a list with all occurences of "re".  More details on how to navigate this list in the Natigation section.

If a second argument fz is passed, the results will be presented in fzf, and if one of them is selected, the line of the selection will be used as new current line.

The efg function calls ef, but it wraps the first argument in g//n.  Its a shortcut for:

````
ef 'g/re/n'
````

## Commands:
Shell commands can be applied to a region using ec:

````
ec start-line end-line command
````

Commands with spaces should be:
````
ec start-line end-line "fmt -w 80"
````

## Checking indentation:
You can check how many tabs and spaces there is at the beginning of a line using:

````
el
````

Optionally, a line and a file can be specified:
````
el line? file?
````

## Navigation:
### On the text:
#### Forward:
To move one line forward:

````
es
es +
````

To move n lines forward, use +n.  For example, to move 5 lines forward:

````
es +5
````

You can use a literal n to move a page forward:

````
es n
````

#### Backward:
To move one line backward:

````
es -
````

To move n lines backward, use -n.  For example:

````
es -5
````

You can use p to move a page backward:

````
es p
````

#### Specific location:
For example, to go to the line 8:

````
es 8 
````

To the end of the file:

````
es $
es G
````

To the beginning of the file:

````
es b
es g
````

To show the current line:

````
es l
es .
````

#### Searching forward:
You can search forward using:

````
es '/re'
````

For example, to search a line beginning with a tab, and ending with 'then':

````
es '/^\tthen$'
````

You can use two search terms, to display from one to another, for example:

````
es '/\t^if,/^\tfi'
````

Will display the next if/fi pair of 1 tab level.  Searching from the beginning of the file to some point can be done like this:

````
es '//,/^\tfi'
````

Where // represent the beginning of the file.  The same can be done to search from some point to the end:

````
es '\t^if,//'
````

#### Range:
````
es 1,10
es +1,10
es 1,+10
es +1,+10
````

#### Quick visualizing:
````
es c
````

Will display from $pagesize/2 above the current line, to $pagesize/2 below the current line.

#### Repeating:
````
es r
````

Will repeat the last es command.

#### Visualizing a terminal page:
With v, you can show as much text as there's rows in the terminal window:

````
es v
````

#### Files:
You can visualize a different file.  Examples:

````
es c file
es n file
````

This will not change the current opened file, just display the desired portion of another file.

### On the searching list:
#### Going up on the list:
````
es u
````

#### Goind down on the list:
````
es d
````

#### Going to a item in the list:
````
es fn
````

Where n should be a number of an item of the search list.  You can also go to a item of the search list by using fzf:

````
es fz
````

#### Showing the content in the middle:
````
es m
````

If the search list have, for example, 3 items, and you want to see what's in the middle of item 1, and item 2:

````
es f1
es m
````

#### Display the list again:
````
es s
````

## eprint:
The function eprint receives and does the seame as the editshow, but without color and line numbering, it is a shortcut to:

````
edcmd=p edcolor=0 es ...
````

## Searching line with fzf:
The function editshowfzf, or esf, for short, provide a way to search for lines of text using fzf.  It receives the same argument as editshow.

## Content with fzf:
The function editcontent, or ect, for short, display file paths and urls on fzf.  The selection will be opened using the command inside the variable edcontentcmd, that is by default, xdg-open.

The contents are filtered with grep -E, using the pattern: '^([/~.]\\/\*|.\*\\:\\/\\/\*)'.

## Disable line numbering:
To disable line numbering for the next command:

````
edcmd=p command
````

## Changing the text color:
You can edit the variable edcolor, to change the text color.  It does ANSI escape codes, so you can set edcolor to 31 to have red, 32 for green, and so on.  0 will disable it.

## Editing text in the $EDITOR:
You can edit a region of the text usin $EDITOR.  For example, to edit the current line:

````
ee . . file?
````

## Termbin:
You can paste a region of the text in termbin by using the function etermbin.  For example, to paste the line 10:

````
etermbin 10
````

The arguments are the same of the es function.

## Auto typing words:
the function editwords gives a fzf inside a tmux display-popup window, containing all the words of the current file.  When one of these words are selected, it will be typed on the command line.  The source of the words, that is, the file that the words will be extracted, are setted when you open a file using eo, or when you display something using es, without a file argument.  You can manually set a file using: editwordsrc filename.

Its called by pressing C-b o.  The key, o, can be changed by setting the desired new key in the variable $editwordkey.  C-b is the default prefix key on tmux, if you have changed it, use your setted prefix instead.

In $editdir (by default, ~/.edit), a directory called dict can be created.  Inside, a file called words can be created, and inside the file, words can be placed, one per line, that will be presented for every file (that is, they will be presented in conjunction with the words of the word source file).

Also, a file named with a file extension can be created, for example, sh, and words can be placed there, and they will be appear when the opened file match the extension.

Also, you can have a file called .bashed-words in a directory.  The words inside it will be presented when the opened file are from that directory.

If the highlight module is available, it will also try to extract keywords from the langDefs highlight files, using the \_edithiextract function.  It will try to extract based on the extension, or it will use the type setted by the user using the ess function of the highligth module.

## Sounds:
A sound can be played for errors, and alerts.  The variable edsound controls if sounds should or should not be played, by setting it to 1, or 0, respectively.  The sound files shoud be setted in the variables:
- ederrorsound;
- edalertsound;

They should be a path to the desired sound file.  The sound files will be played using ffplay.

## Variables:
- edcmd: Contains the command that should be used by es.  It should be p, or n;
- edcontentcmd: Contains the command used to open files and urls;
- editwordkey: the key to be used with bind-key ro call editwords;
- edfzfsize: size of the fzf tmux popup, by default, 80%;
- edfzfpsize: size of the fzf preview window, by default, 30%;
- eslast: Contains the last command executed by es;
- eslastarg: Contains the last argument received by es;
- edsound: Sets the sound on, or off.  By default, 1;
- fileresult: Contains the search results to be displayed by ef, and es s;
- fileresult_a: It's an array that have one entry to each result of an ef search;
- fn: Contains the complete path to the file beign edited;
- fl: Contains the current line number;
- fs: Contains the size of the file being edited;
- pagesize: Size of a page.  Used by es n, es p, and es c;

### File variables:
- edalertsound: sound file to play on alerts;
- ederrorsound: sound file to play on errors;
- editdir: Contains the path to the edit directory.  By default: $HOME/.edit;
- editreadlines: File used to store lines that where cut/copied; 
- editsearchdir: Contains the path to store the file search cache;

## Using e:
Commands can be passed directly to ed, using e, like:

````
e "a\nA new line.\n.\nw"
e "1,2d\nw"
````

## Scripting:
You can use bashed in scripts, for example:

````
source /path/to/bashed.sh
...
````

## Pitfalls:
### Escape character:
The character \ can be problematic.  To insert a literal \ character using the wrappers (ea, ei, ech, esu), use \\\\.  This is not valid for the e command, there, you should use \\\\ when you command was between '', and \\\\\\\\ when you command is between "".  That means, using e, to insert a literal \\:

````
e "a\n\\\\\n.\nw"
e 'a\n\\\n.\nw"
````

When using s under e, it gets even scarier.  For example, substituting a for \:

````
e "s/\\\\\\/a\nw"
e 's/\\\\/a\nw'
````

### Newlines in substitutions:
\N can be used to represent a new line.  For example:

````
esu a '\N'
````

### & in substitutions:
& should be used like \\& when you substituting something with it.  Example:

````
esu x '\&'
````

## .bashed files:
A .bashed file can be placed in any directory.  These files can be used to change the configuration of the editor based on the location of the file.  Any valid bash command can be placed in these files, they will be sourced.  For example:

````
edcmd=p
var=1
function my_special_function { echo "special"; }
````

## Function dictionary:
The functions that are to be used directly have two names: one "big" name, unambiguous, and other shorter, easier to type.

The functions are:
- edit, e: execute ed commands on file;
- editappend, ea: Append lines;
- editcmd, ec: execute command on region; 
- editcopy, ecopy: copy text to a temporary location or clipboard;
- editchange, ec: change lines;
- editclose, eq: close file;
- editdelete, edel: delete lines;
- editexternal, ee: edit region in $EDITOR;
- editfind, ef: find text;
- editinsert, ei: insert line;
- editjoin, ej: join lines;
- editlevel, el: count tab and space indentation;
- editlocate, efl: find line;
- editmove, em: move lines;
- editopen, eo: open file;
- editpaste, epaste: paste text from the temporary location, or clipboard;
- editshow, es: show file text in various ways;
- editshowfzf, esf: select a line using fzf;
- editstore, et: store a version of file;
- editsub, esu; substitution;
- etermbin, paste in termbin;
- edittransfer, ey: copy lines;
- editundo, eu: show, diff, restore, delete stored version files;
- editwordsrc, ews: set the current file as a source of words;
- editwords, ew: show a list of words from a file and type the selction;

There are other functions that are used internally by the ones above:
- \_editalert: display messages and play sounds during alerts and errors;
- \_editarg: parse the arguments of a file;
- \_editfzf: display fzf selection interfaces;
- \_editindent: count tabs, or spaces, at the beginning of the line;
- \_editline: calculate line numbers;
- \_editwindow: open/find windows;

Also, some functions will come in pairs, for example: editappend, and \_editappend.  These \_functions are used for auto completing the arguments of the functions, and should not be called directly.

# Modules:
## Version:
The simplest undo mechanism I can think of is to store versions of the files, and have mechanisms to display, restore, and compare these versions.

### Configuration:
Add to your ~/.bashrc:

````
source /path/to/bashed/modules/version/version.sh
````

### Storing:
````
et
````

Will store a copy of the current file.

### Listing:
````
eu l
eu list
````

Will show a list of the copies of the current file previously stored using et.  listcurses, or lu, can be used instead of l, or list, to list files using fzf.  The selected file version will substitute your current file.

### Showing:
#### With line numbering:
````
eu show n
eu es n
````

showcurses, or esu, can be used instead of show, or es, to select the file to show using fzf.

#### Plain:
````
eu print n
eu p n
````
printcurses, or pu, can be used instead of print, or p, to select the file to print using fzf.

### Diff:
````
eu diff f1 f2
````

Will present a diff from the file f1, and file f2.  f1, and f2, can be either a stored file or a regular file.  For example, to compare the current file with the stored version 2:

````
eu diff 2 $fn
````

The diff arguments can be set be changing the diffarg variable.  By default, ther arguments are: --color -c.  diffcurses can be used instead of diff, to select the files to diff using fzf.  You should select two files from fzf, or one, if you pass a filename.  For example:

### Selecting:
````
eu n
````

Will substitute the current file with the file n from the stored file list (eu l)

### Copying:
You can copy a stored file version somewhere else.  For example:

````
eu cp 1 /path/to/file
````

Will copy the stored file version 1 of the current opened file to /path/to/file.  copycurses, or cpu, can be used instead of copy, or cp, to select the file to copy using fzf:

````
eu copycurses /path/to/file
````

will copy the selected file to /path/to/file.

### Deleting:
You can delete file versions using delete, or rm:

````
eu delete n
````

You can use deletecurses, or du, to select the version files to delete using fzf.

### Variables:
- editversiondir: directory to store the file versions
- diffarg: diff arguments, by default, "--color -c"

## Clip:
An clipboard manager.  This module add the function editclipboard, or eclip, for short.

### Configuration:
Add to your ~/.bashrc, after sourcing bashed:

````
source /path/to/bashed/modules/clip/clip.sh
````

### Clipboard files:
The text that's copied is stored in plain text files, in the directory ~/.edit/clip.

### Copy:
To copy text from the current file:
````
eclip c . name
````

It will copy the current line to a clipboard file.  The dot can be substituted by anything that editshow understands.  For example:

````
eclip c 1,10 file.sh
eclip c 1,+2 file.c
````

The name is the name of the clipboard file.  Naming is useful for organization, also, it is useful when displaying with the list command, because it will pick up the file extension, and display the content accordingly.  The name is optional, and the current date will be used if a name is not given.

### List:
To list the copied text files:

````
eclip l
````

The files will be listed in the format:

````
---------
n - name:
---------
content
...
````

The n will be a number that can be used to identify a clipboard file.  These numbers are not fixed, and can change when files are renamed, or deleted.  The color that these are displayed can be changed in the variable $edclipcolor, by default, 31.

### Show:
To show the contents of a clip entry, that is, to print it, you use:
````
eclip sh n
````

Where n is a number of one of the copied text files, or a name.

### Search:
To search for a clipboard file name:

````
eclip s word
````

All clipboard file names that contains word will be listed.

### Search content:
To search the contents of a clipboard file:

````
eclip sc word
````

All clipboard files that contains word will be listed.

### Paste:
To paste some copied text to the current file:

````
eclip p n
````

Where n is a number of one of the copied text files, or a name;

````
eclip p 1
eclip p shell-function.sh
````

### Cut:
To cut text from the current file:

````
eclip x . name
````

The dot can be substituted for anything that editshow can understand.

### Delete:
To delete some clipboard text file:

````
eclip d n
````

Where n is a number of some clipboard text file, or a name.  A fzf interface is available, that allows selection of multiple files to be deleted:

````
eclip du
````

### Rename:
````
eclip r n newname
````

Where n is a number of some clipboard text file, or a name.  For example:

````
eclip r 1 url
eclip r shell-function.sh my-shell-function.sh
````

### Copy to X clipboard:
To copy some clipboard file content to the X clipboard:

````
eclip tx n
````

Where n is a number of some clipboard text file, or a name.

### Copy to Wayalnd clipboard:
````
eclip tw n
````

Where n is a number of some clipboard text file, or a name.

### Copy from X clipboard:

````
eclip fx name
````

### Copy from Wayland clipboard:
````
eclip fw name
````

### Type:
The contents of a clipboard file can be typed into the command line by using type.  This is binded on tmux to C-b b.  It will display a tmux display-popup containing fzf with a list of the clipboard files, and the selected one will have its contents typed on the command line.  The variable $edclipkey contains the key that will be binded on tmux, b, and shoud be customized if necessary.

### Functions:
- edclipboard, eclip: the clipboard;

and the ones used internally:
- \_edclipfile: used internally to find clipboard files;
- \_editclipword: display a tmux popup with a fzf containing the clipboard file names;
- \_editclipstart: clipboard startup;

### Variables:
- edclipdir: the directory to store the files;
- edclipcolor: the color of the clip headers;
- edclipkey: key to be binded on tmux;

## highlight:
Syntax highlight can be used via the highlight module.

### Configuration:
Add to your ~/.bashrc, after sourcing bashed:

````
source /path/to/bashed/modules/syntax/highlight/highlight.sh
````

### How it works:
This module will provide the function editshowhi, or ess for short.  This functin works almost the same as editshow/es, but the output is highlighted.

For files that are recognized by highlight, you just use the ess function as you would use es.  For files that it does not recognize, you may need to tell which language/type the file is.  For example:

````
ess a file sh
````

will tell ess that the file should be highlighted as a shell script.  This will be memorized, and future interactions with that file will use the sh highlight, so you will not need to pass sh anymore.

If you decide to change the theme, like setting ehitheme to vampire, for example, or some other theme, the theme will be loaded after the next file modification.  You can force a reloading by passing a 4th argument 'rewrite', like this:

````
ess a file sh rewrite
````

Omitting the third argument will keep the current language syntax:
````
ess a file '' rewrite
````

### Variables:
- ehidir: directory to store the temporary highlighted files;
- ehidefs: highlight langDefs, by default, /usr/share/highlight/langDefs;
- ehioutformat: highlight output format, by default, xterm256;
- ehitheme: highlight theme, by default, camo;

### Functions:
- editshowhi, ess: show the file contents, and optionally set the type of the file;
- \_edithiextract: extract keywords from the highlight langDefs file;

