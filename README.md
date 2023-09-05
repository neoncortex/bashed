# bashed
bash wrapper for the ed editor.

# How it works:
It is a collection of functions that wraps the ed functionalities, and manage the files and windows using tmux.

# Dependencies:
- ed;
- tmux;

## Optional:
- highlight;
- wl-clipboard;
- xclip;

# Configuration:
Add to your ~/.bashrc:

````
source /path/to/bashed/bashed.sh
````

## Optional, prompt:
You can customize the prompt to show the file size, and current line.  For example, in ~/.bashrc:

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

## Optional, tmux:
You can customize tmux to show the file path in it's pane name.  In ~/.tmux.conf:

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

Also, you can subdivide an existing pane.  Lets say you window have two panes, and you want to subdivide the unfocused pane, then: ul, for subdivide the upper pane, and open in the left, ur, for subdividing the upper pane, and open on the right, lu, for subdivide the left pane, and open on the top, ld, for subdivide the left pane, and open on the bottom, rl and rd does the same as lu and ld, but for the right pane, and dl and dr does the same as ul and ur, but for the bottom pane.

### Arguments:
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

## Adding line:
### Append:
````
ea line of text.
ea 'another line of text.'
````

The text will be appended after the current focused line.  Without arguments, a blank line will be added.

### Insert:
````
ei line of text.
````

The text will be inserted in the current line - 1.

## Deleting:
### Deleting line:
````
edel
````

### Deleting range:
````
edel n
````

Where n is the end line.  The lines from the current line to n will be deleted.  n can also be specified in the format +n, like:

````
edel +n
````

That will delete the text from current line, to the text +n line.  Examples:

````
edel 2
edel 5,10
edel 10,+2
````

## Changing:
### Changing line:
````
ech "new text."
````

Will change the current line to "new text.".

You can also use echl, that will change only the current line, but it will autocomplete the current line contents.

````
echl new content.
````

### Changing range:
````
ech "new text." n
````

Will change the text from the current line, to the n line, to "new text.".  For example:

````
ech "new text." 5
ech "changed." +2
````

## Copying:
### Copy line:
````
ey n
````

The current line will be copied to line n.

### Copy range:
````
ey a b
````

The current line, to b, will be copied to line n.  For example:

````
ey 1 5
````

The current line, to line 5, will be copied to the line 1.  The second argument (5, in last case), can be set using +, like +5.

### Yank:
Lines can be "yanked" like follows:

````
ey ''
````

This will copy the current line to the variable $yank.

## ecopy and epaste:
ecopy and epaste are two functinos that allows to copy and paste a portion of a text file to a temporary location, or the X/Wayland clipboard, so it can be pasted in another shell, file, etc.  The temporary location will be ~/.edit/readlines.

### ecopy:
ecopy works that way:
````
ecopy start end x|y
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
ej can receiva an argument, n, or +n

````
ej 2
ej +2
````

That will join from the current line to line 2, and from the current line + 2 lines, respectively.

## Moving:
Can receive a number, (+|-)n, or $ as its argument.

### Moving line:
````
em 2
````

Will move the current line to line 2.

### Moving range:
````
em 2 10
````

Will move lines from the current line, to the line 10, to line 2

````
em 2 +5
````

Will move the current line, plus the five subsequent lines, to the line 2.

## Substitution:
### Substitution on current line:
````
esu "a" "b"
````

Can receive the g argument, like:

````
esu "a" "b" '' g
````

To replace every ocurrence.

### Substition on range:
````
esu "a" "b" n
````

Will substitute "a" for "b" from the current line, to the line n.  n can be setted with +, like:

````
esu "a" "b" +n
````

It can also receive the g argument:

````
esu "a" "b" n g
````

Examples:
````
esu "a" "b" 10
esu "a" "b" +5
esu "a" "b" +5 g
````

#### Substitution on the entire file:
The third argument can be %, like:
````
esu "a" "b" %
esu "a" "b" % g
````

That will execute the substitution on the entire file.

## Searching:
The most common searching mechanism would be:

````
ef 'g/re/p'
````

This will return a list with all occurences of "re".  More details on how to navigate this list in the Natigation section.

## Commands:
Shell commands can be applied to a region using ec:

````
ec 1 10 fmt
````

To apply a command to one line only, do:
````
ec 10 10 fmt
````

Commands with spaces should be:
````
ec 1 10 "fmt -w 80"
````

ec can receive +n, -n, ., and $, to represent lines.  For example, to apply a command from the current line to last:

````
ec . $ fmt
````

Or from the current line, + 2 lines:

````
ec . +2 fmt
````

## Checking indentation:
You can check how many tabs there is at the beginning of a line using:

````
el
````

And how many spaces using:

````
els
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
emore . file
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

Where n should be a number of an item of the search list.

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

## Disable line numbering:
To disable line numbering for the next command:

````
edcmd=p command
````

## Changing the text color:
You can edit the variable edcolor, to change the text color.  It does ANSI escape codes, so you can set edcolor to 31 to have red, 32 for green, and so on.

## Editing text in the $EDITOR:
You can edit a region of the text usin $EDITOR.  For example, to edit the current line:

````
ee . .
````

Yo can use $, or (+|-)n, and so on.

## Termbin:
You can paste a region of the text in termbin by using the function etermbin.  For example, to paste the line 10:

````
etermbin 10
````

The arguments are the same of the es function.

## Variables:
- edcmd: Contains the command that should be used by es.  It should be p, or n;
- eslast: Contains the last command executed by es;
- eslastarg: Contains the last argument received by es;
- e_uresult: Contains the last selections of a curses menu;
- fileresult: Contains the search results to be displayed by ef, and es s;
- fileresult_a: It's an array that have one entry to each result of an ef search;
- fn: Contains the complete path to the file beign edited;
- fl: Contains the current line number;
- fs: Contains the size of the file being edited;
- pagesize: Size of a page.  Used by es n, es p, and es c;

### File variables:
- editdir: Contains the path to the edit directory.  By default: $HOME/.edit;

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
- editlevel, el: count tab indentation;
- editlocate, efl: find line;
- editmove, em: move lines;
- editopen, eo: open file;
- editpaste, epaste: paste text from the temporary location, or clipboard;
- editshow, es: show file text in various ways;
- editspaces, els: count space indentation;
- editstore, et: store a version of file;
- editsub, esu; substitution;
- etermbin, paste in termbin;
- edittransfer, ey: copy lines;
- editundo, eu: show, diff, restore, delete stored version files;

There are other functions that are used internally by the ones above:
- \_editarg: parse the arguments of a file;
- editcurses: used to generate curses menus;
- \_editread, er: read a region of file, and store in ~/.edit/readlines
- \_editregion: used internally to separate regions of the text;
- \_editwindow: open/find windows;

Also, some functions will come in pairs, for example: editappend, and \_editappend.  These \_functions are used for auto completing the arguments of the functions, and should not be called directly.

# Modules:
## curses:
This module includes a function, \_editcurses, that can be used by other modules.

## Version:
The simplest undo mechanism I can think of is to store versions of the files, and have mechanisms to display, restore, and compare these versions.

### Configuration:
Add to your ~/.bashrc:

````
source /path/to/bashed/modules/curses/curses.sh
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

Will show a list of the copies of the current file previously stored using et.  listcurses, or lu, can be used instead of l, or list, to list files using a curses interface.  The selected file version will substitute your current file.

### Showing:
#### With line numbering:
````
eu show n
eu es n
````

showcurses, or esu, can be used instead of show, or es, to select the file to show using a curses interface.

#### Plain:
````
eu print n
eu p n
````
printcurses, or pu, can be used instead of print, or p, to select the file to print using a curses interface.

### Diff:
````
eu diff f1 f2
````

Will present a diff from the file f1, and file f2.  f1, and f2, can be either a stored file or a regular file.  For example, to compare the current file with the stored version 2:

````
eu diff 2 $fn
````

The diff arguments can be set be changing the diffarg variable.  By default, ther arguments are: --color -c.  diffcurses can be used instead of diff, to select the files to diff using a curses interface.  You should select two files from the curses interface, or one, if you pass a filename.  For example:

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

Will copy the stored file version 1 of the current opened file to /path/to/file.  copycurses, or cpu, can be used instead of copy, or cp, to select the file to copy using the curses interface:

````
eu copycurses /path/to/file
````

will copy the selected file to /path/to/file.

### Deleting:
You can delete file versions using delete, or rm:

````
eu delete n
````

You can use deletecurses, or du, to select the version files to delete using a curses interface.

### Variables:
- editversiondir: "$editdir/version"
- diffarg: "--color -c"

## Clip:
An clipboard manager.  This module add the function editclipboard, or eclip, for short.

### Configuration:
Add to your ~/.bashrc, after sourcing bashed:

````
source /path/to/bashed/modules/curses/curses.sh
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

#### Cut:
To cut text from the current file:

````
eclip x . name
````

The dot can be substituted for anything that editshow can understand.

#### Delete:
To delete some clipboard text file:

````
eclip d n
````

Where n is a number of some clipboard text file, or a name.  A curses interface is available, that allows selection of multiple files to be deleted:

````
eclip du
````

#### Rename:
````
eclip r n newname
````

Where n is a number of some clipboard text file, or a name.  For example:

````
eclip r 1 url
eclip r shell-function.sh my-shell-function.sh
````

#### Copy to X clipboard:
To copy some clipboard file content to the X clipboard:

````
eclip tx n
````

Where n is a number of some clipboard text file, or a name.

#### Copy to Wayalnd clipboard:
````
eclip tw n
````

Where n is a number of some clipboard text file, or a name.

#### Copy from X clipboard:

````
eclip fx name
````

#### Copy from Wayland clipboard:
````
eclip fw name
````

#### Functions:
- edclipfile: used internally to find clipboard files;
- edclipboard, eclip: the clipboard;

#### Variables:
- edclipdir: the directory to store the files;
- edclipcolor: the color of the clip headers;

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
ess a sh
````

will tell ess that the current file should be highlighted as a shell script.  This will be memorized, and future interactions with that file will use the sh highlight, so you will not need to pass sh anymore.

If you decide to change the theme, like setting ehitheme to vampire, for example, or some other theme, the theme will be loaded after the next file modification.  You can force a reloading by passing a 4th argument 'rewrite', like this:

````
ess a '' '' rewrite
````

### Variables:
- ehidir: "$editdir/syntax/hi";
- ehidefs: "/usr/share/highlight/langDefs";
- ehioutformat: "xterm256";
- ehitheme: camo;

