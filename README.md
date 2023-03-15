# bashed
bash wrapper for the ed editor

![screenshot](https://github.com/neoncortex/bashed/blob/main/image/image.png)

## Motivation:
ed is a good text editor, but it's interface is not optimal.  I thought that bash would be a good interface for it, plus it allows all the bash trickery to be used directly in an editing session.

## What this does?
It wraps the ed editor in bash functions, allowing it use directly on command line.  It maintain the state, like the current line, using bash variables.

## Dependencies:
- ed;
- tmux;
- highlight;
- xclip;
- chafa;

## Configuration:
Add to your ~/.bashrc:

````
    source /path/to/bashed.sh
````

### Optional, prompt:
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

### Optional, tmux:
You can customize tmux to show the file path in it's pane name.  In ~/.tmux.conf:

````
set -g pane-border-status top
set -g pane-border-format "#T, #P, #{pane_current_command}"
set-window-option -g pane-active-border-style "fg=green,bold"
set-option -g display-panes-time 10000
````

## How to use it:
All the commands below should be used inside a tmux session.

### Opening files:
````
eo file
````
When opening files, it will verify if the same file is already opened in another tmux pane.  It it does, these pane will be focused, otherwise, the file will be opened in the current pane.

eo can receive an argument specifying that the file should be opened in a new panel.  A new panel can be: u for up, d for down, l for left, r for right, n, for new window.

For example, to open a file into a new panel on top of the current one:

````
eo file u
````

#### Arguments:
Files can be opened with arguments. These arguments can specify a line, or a string.  Examples:

````
eo file:10
eo file:'hello world'
````

In the first command, file will be opened, and the line 10 will be setted as the current line.  On the second, file will be opened, the string "hello world" will be searched, and the line containing that string will be setted as the current line.

If there is a pane with file already opened, then it will be focused, and the current line will be changed using the argument.

### Closing files:
````
eq
````

### Adding line:
#### Append:
````
ea "line of text."
````

The text will be appended after the current focused line.  Without arguments, a blank line will be added.

#### Insert:
````
ei "line of text."
````

The text will be inserted in the current line - 1.

### Deleting:
#### Deleting line:
````
edel
````

#### Deleting range:
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

### Changing:
#### Changing line:
````
ech "new text."
````

Will change the current line to "new text.".

#### Changing range:
````
ech "new text." n
````

Will change the text from the current line, to the n line, to "new text.".  For example:

````
ech "new text." 5
ech "changed." +2
````

### Copying:
#### Copy line:
````
ey n
````

The current line will be copied to line n.

#### Copy range:
````
ey a b
````

The current line, to b, will be copied to line n.  For example:

````
ey 1 5
````

The current line, to line 5, will be copied to the line 1.  The second argument (5, in last case), can be set using +, like +5.

#### Yank:
Lines can be "yanked" like follows:

````
ey ''
````

This will copy the current line to the variable $yank.

#### Yank to X11 clipboard:
````
ey '' '' x
````

Will copy the current line to X11 clipboard, using xclip.  The second argument can be setted to copy a range, like:

````
ey '' 10 x
ey '' +5 x
````

### Joining:
#### Joining lines:
````
ej
````

Will join the current line with the next.

#### Joining range:
ej can receiva an argument, n, or +n

````
ej 2
ej +2
````

That will join from the current line to line 2, and from the current line + 2 lines, respectively.

### Moving:
Can receive a number, (+|-)n, or $ as its argument.

#### Moving line:
````
em 2
````

Will move the current line to line 2.

#### Moving range:
````
em 2 10
````

Will move lines from the current line, to the line 10, to line 2

````
em 2 +5
````

Will move the current line, plus the five subsequent lines, to the line 2.

### Substitution:
#### Substitution on current line:
````
esu "a" "b"
````

Can receive the g argument, like:

````
esu "a" "b" '' g
````

To replace every ocurrence.

#### Substition on range:
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

##### Substitution on the entire file:
The third argument can be %, like:
````
esu "a" "b" %
esu "a" "b" % g
````

That will execute the substitution on the entire file.

### Searching:
The most common searching mechanism would be:

````
ef 'g/re/p'
````

This will return a list with all occurences of "re".  More details on how to navigate this list in the Natigation section.

### Commands:
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

### Checking indentation:
You can check how many tabs there is at the beginning of a line using:

````
el
````

And how many spaces using:
````
els
````

### Navigation:
#### On the text:
##### Forward:
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

##### Backward:
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

##### Specific location:
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

##### Searching forward:
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

Will display the next if/fi pair of 1 tab level.

##### Range:
````
es 1,10
es +1,10
es 1,+10
es +1,+10
````

##### Quick visualizing:
````
es c
````

Will display from $pagesize/2 above the current line, to $pagesize/2 below the current line.

##### Repeating:
````
es r
````

Will repeat the last es command.

##### emore:
You can use the emore command to visualize using more.  It will display the file from the current line to the end.  A start line can be passed, for example, 10:

````
emore 10
````

##### Visualizing a terminal page:
With v, you can show as much text as there's rows in the terminal window:

````
es v
````

##### Files:
You can visualize a different file.  Examples:

````
es c file
es n file
emore . file
````

This will not change the current opened file, just display the desired portion of another file.

#### On the searching list:
##### Going up on the list:
````
es u
````

##### Goind down on the list:
````
es d
````

##### Going to a item in the list:
````
es fn
````

Where n should be a number of an item of the search list.

##### Showing the content in the middle:
````
es m
````

If the search list have, for example, 3 items, and you want to see what's in the middle of item 1, and item 2:

````
es f1
es m
````

##### Display the list again:
````
es s
````

#### Disable syntax:
To disable syntax for the next command:

````
editsyntax=n command
````

#### Disable line numbering:
To disable line numbering for the next command:

````
edcmd=p command
````

### Versioning:
The simplest undo mechanism I can think of is to store versions of the files, and have mechanisms to display, restore, and compare these versions.

#### Storing:
````
et
````

Will store a copy of the current file.

#### Listing:
````
eu l
eu list
````

Will show a list of the copies of the current file previously stored using et.

#### Showing:
##### With syntax:
````
eu show n
eu es n
````

##### Plain:
````
eu print n
eu p n
````

#### Diff:
````
eu diff n1 n2
````

Will present a diff from the file n1, and file n2 from the stored file list (eu l).

#### Selecting:
````
eu n
````

Will substitute the current file with the file n from the stored file list (eu l)

### Images:
If a path to a image file is found, it will be displayed using chafa.  The image path should be the sole content of the line.  For example:

````
/usr/share/pixmaps/xine.xpm
````

Here's how it looks:

![screenshot](https://github.com/neoncortex/bashed/blob/main/image/chafa.png)

It can be disabled by setting the variable edimg to 0.

### Variables:
#### fn:
Contains the complete path to the file beign edited.

#### fl:
Contains the current line number.

#### fs:
Contains the size of the file being edited.

#### edcmd:
Contains the command that should be used by es.  It should be p, or n.

#### pagesize:
Size of a page.  Used by es n, es p, and es c.

#### eslast:
Contains the last command executed by es.

#### eslastarg:
Contains the last argument received by es.

#### fileresult:
Contains the search results to be displayed by ef, and es s.

#### fileresult_a:
It's an array that have one entry to each result of an ef search.

#### diffarg:
Contains the diff options.  By default: "--color -c".

#### edtmux:
Controls if tmux should be used.  By default, 1.  Should be 1, or 0.

#### edimg:
Controls if bashed show display images.  By default, 1.  Should be 1, or 0.

#### Highlight:
##### syntax:
Contains the name of the syntax file used by highlight for the current file.

##### block_syntax:
Contains the name of the syntax used in a code block.

##### edsyntax:
Set if es should use syntax.  Should be y, or n.

##### hitheme:
Contains the theme name used by highlight.

### Using e:
Commands can be passed directly to ed, using e, like:

````
e "a\nA new line.\n.\nw"
e "1,2d\nw"
````

### Scripting:
You can use bashed in scripts, for example:

````
source /path/to/bashed.sh
edtmux=0
...
````

That means, in your script, you have to source bashed, and set edtmux to 0, so that the commands running in the script will not mess with your tmux sessions.

### Pitfalls:
#### Escape character:
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

#### Newlines in substitutions:
\N can be used to represent a new line.  For example:

````
esu a '\N'
````

#### & in substitutions:
& should be used like \& when you substituting something with it.  Example:

````
esu x '\&'
````
#### Syntax highlighting:
It will misbehave here and there (at least I'm not alone on this).  It is useful enough to catch some bugs, but not perfect.

#### Images and emore:
It seems that chafa and more does not work well together, so, for now, emore does not display images.

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
- editchange, ec: change lines;
- editclose, eq: close file;
- editdelete, edel: delete lines;
- editfind, ef: find text;
- editinsert, ei: insert line;
- editjoin, ej: join lines;
- editlevel, el: count tab indentation;
- editlocate, efl, find line;
- emore, scroll file forward using more;
- editmove, em: move lines;
- editopen, eo: open file;
- editread, er: read a region of file, and store in ~/.edit/readlines
- editshow, es: show file text in various ways;
- editspaces, els: count space indentation;
- editstore, et: store a version of file;
- editsub, esu; substitution;
- edittransfer, ey: copy lines;
- editundo, eu: show, diff, restore, delete stored version files;

There are other functions that are used internally by the ones above:
- editarg: parse the arguments of a file;
- editpresent: display file contents; 
- editsyntax: set the syntax to be used;
- hi: display text;
- img: display images;
