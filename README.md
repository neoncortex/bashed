# bashed
bash wrapper for the ed editor

![screenshot](https://github.com/neoncortex/bashed/blob/main/image/bob.png)

## Motivation:
ed is a good text editor, but it's interface is not optimal.  I thought that bash would be a good interface for it, plus it allows all the bash trickery to be used directly in an editing session.

## What this does?
It wraps the ed editor in bash functions, allowing it use directly on command line.  It maintain the state, like the current line, using bash variables.

## Dependencies:
### Required:
- ed;
- highlight;
- xclip;

### Optional:
- tmux;
- chafa;
- terminology;
- xdotool;
- wmctrl;

## Configuration:
Add to your ~/.bashrc:

````
source /path/to/bashed/bashed.sh
````

Then you should configure if you want to use it with tmux, terminology, or directly:

### Tmux:
Add to your ~/.bashrc, after the sourcing:

````
edtmux=1
edty=0
````

### Terminology:
Add to your ~/.bashrc, after the sourcing:

````
edtmux=0
edty=1
edtysleep=0.2
````

You can tweak edtysleep to a highter value.  It may be necessary if 0.2 is not enough time for your system to open terminology, and paste the commands using xdotool.  In extreme cases, if you machine are under too much load, it may happen that the terminology opening, focusing, and sending commands goes out of sync.  In that case, you will need to set edty to 0, and manage windows manually.

### Directly:
Add to your ~/.bashrc, after the sourcing:

````
edtmux=0
edty=0
````

This is the manual way of managing windows.  In this mode, the file will be opened directly under the current shell.

### Syntax highlight:
Syntax highlight are enabled by default.  To disable, add to your ~/.bashrc, after the sourcing:

````
edsyntax=0
````

### Images:
Images are enabled by default.  To disable, add to your ~/.bashrc, after the sourcing:

````
edimg=0
````

### Escape sequences:
Escape sequences are enabled by default.  To disable, add to your ~/.bashrc, after sourcing:

````
edesc=0
````

### Tables:
Tables are enabled by default.  To disable, add to your ~/.bashrc, after sourcing:

````
edtables=0
````

### Blocks:
Source blocks are enabled by default.  To disable, add to your ~/.bashrc, after sourceing:

````
edblock=0
````

### Include:
Including are enabled by default.  To disable, add to your ~/.bashrc, after sourcing:

````
edinclude=0
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

## A note about file types:
The features: images, source blocks, tables, including external files, and escaping are disabled in any file that have an extension that is not .org, or .txt.  This is done like this because these features can misinterpret source code, and configuration files.

## How to use it:
### Opening files:
````
eo file
````

When opening files, if bashed is configured to use tmux, or terminology, it will verify if the same file is already opened in another tmux pane, or terminology window.  It it does, the tmux pane, or terminology window, will be focused, otherwise, the file will be opened in the current tmux pane, or a new terminology window.  If it's not using tmux or terminology, the file will be opened in the current shell.

eo can receive an argument specifying that the file should be opened in a new tmux panel.  A new panel can be: u for up, d for down, l for left, r for right, n, for new window.

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

If there is a tmux pane, or terminology window, with file already opened, then it will be focused, and the current line will be changed using the argument.

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

Will display the next if/fi pair of 1 tab level.  Searching from the beginning of the file to some point can be done like this:

````
es '//,/^\tfi'
````

Where // represent the beginning of the file.  The same can be done to search from some point to the end:

````
es '\t^if,//'
````

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
editsyntax=0 command
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
eu diff f1 f2
````

Will present a diff from the file f1, and file f2.  f1, and f2, can be either a stored file or a regular file.  For example, to compare the current file with the stored version 2:

````
eu diff 2 $fn
````

The diff arguments can be set be changing the diffarg variable.  By default, ther arguments are: --color -c.

#### Selecting:
````
eu n
````

Will substitute the current file with the file n from the stored file list (eu l)

#### Copying:
You can copy a stored file version somewhere else.  For example:

````
eu cp 1 /path/to/file
````

Will copy the stored file version 1 of the current opened file to /path/to/file.

### Images:
If a path to a image file is found, bashed will display it. If bashed is configured to use tmux, it will be displayed using chafa, and if it's configured to use terminology, the image will be displayed using tycat.  The image path should be the sole content of the line.  For example:

````
/usr/share/pixmaps/xine.xpm
````

Here's how it looks in tmux, using chafa:

![screenshot](https://github.com/neoncortex/bashed/blob/main/image/chafa.png)

And here's how it looks in terminology, using tycat:

![screenshot](https://github.com/neoncortex/bashed/blob/main/image/tycat.png)

Images can be disabled by setting the variable edimg to 0.

### Escape sequences:
Lines containing escape sequences are special.  Bashed have a special syntax that allows it to pass escape sequences to the terminal.  The syntax is:
[[ followed by '\033[', followed by the escape code, space, content, space, '\033[', the escape finalization, and ]].  For example:

````
[[\033[31m test \033[0m]]
````

Nothing should be typed together with the sequences.  For example, if you want to place a dot after the sequence:

````
[[\033[31m test \033[0m]] .
````

#### Spaces after the escape sequence:
By default, a space will be added at the end of the escape sequence.  To prevent this, you can place a '\E ' before the escape sequence.  For example:

````
\E [[\033[31m test \033[0m]] , word
````

This will place the escape sequence and the comma together, without spaces in the middle.

#### Two or more spaces in lines containing escape sequences:
The space is used as the word delimiter when parsing lines containing escape sequences.  For that reason, spaces will be collapsed, that is, two or more space characters in sequence will become one space character.  To use extra spaces, you can place a '\S'.  For example:

````
[[\033[31m test \033[0m]] \S word
````

That will place a extra space between the escape sequence containing test, and the word 'word'.  To place more than one:

````
[[\033[31m test \033[0m]] \S \S word
````

And so on.

#### Hiding the escape sequences:
Sometimes it will be useful to hide the escape sequences, for example when you want to pass the text to a command.  To do this, you set the variable edesch to 1.

### Multimedia:
#### emq:
If you are using Bashed with Terminology, you can view the all the media files in a text file using the command emq.  It receives the same argument as es, and call tyq on each result.  For example, to see all media from the line 10 to line 20:

````
emq 10,20
````

#### etycat:
You can cat media on the terminal using etycat.  It works the same as emq, but execute tycat instead of tyq.

### efmt:
This is the internal paragraph formatter.  For example:

````
efmt 1 10
````

Will format the lines 1 to 10.  By default, it will format lines in 80 columns, but a third argument can be passed to set the column size:

````
efmt 1 10 70
````

As usual, the first and second argument can be ., or $, or +n, and -n.

### Editing text in the $EDITOR:
You can edit a region of the text usin $EDITOR.  For example, to edit the current line:

````
ee . .
````

Yo can use $, or (+|-)n, and so on.

### Including another files for displaying:
Other files can be included in the current file using [[include:file]].  For example:

````
[[include:/etc/fstab]]
````

The [[include:...]] line will be replaced with the contents of the file, in that case, /etc/fstab.  An argument can be placed after the file name, specifying what portion of the file you want to show.  For example, to show from the line 1 to line 5:

````
[[include:/etc/fstab:1,5]]
````

These arguments are the same accepted by es.  The file including can be turned off by setting edinclude to 0.

### Tables:
Tables can be created like this:

````
#+table
header1     header2     header3
item1       item2       item3
#+end_table
````

Tem separator is a TAB character.  Showing tables can be disabled by setting the variable edtables to 0.  To print the table box using ASCII only, set edtable_ascii to 1.

### Hiding text:
It is possible to hide a portion of the text by using hidden blocks.  For example:

````
#+hidden
This text will not be shown
#+end_hidden
````

To show these blocks, the variable edhidden should be set to 0.

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

#### edty:
Controls if terminology should be used, By default, 0.  Should be 1, or 0.

#### edtysleep:
Contains a real number, that is used as interval between xdotool commands that are sent to terminology windows.  By default, 0.2.

#### edimg:
Controls if bashed show display images.  By default, 1.  Should be 1, or 0.

#### edhidden:
Contols if hidden blocks should be shown.  By default, 1.  Should be 1, or 0.

#### edinclude:
Controls if files inside [[include:]] shoud be displayed.

#### edblock:
Controls if source blocks should be displayed with the syntax highlighting.

#### Highlight:
##### syntax:
Contains the name of the syntax file used by highlight for the current file.

##### block_syntax:
Contains the name of the syntax used in a code block.

##### edsyntax:
Set if es should use syntax.  By default, 1.  Should be 1, or 0.

##### hitheme:
Contains the theme name used by highlight.

#### Escape sequences:
##### edesc:
Controls if escape sequences should be interpreted,  By default, 1.  Should be 1, or 0.

##### edesch:
Controls if escape sequences shoud be displayed.  By default, 0.  Should be 0, or 1.

##### edecesch:
Controls if ec should use escape sequences.  By default, 1.  Should be 0, or 1.

#### Files:
##### editdir:
Contains the path to the edit directory.  By default: $HOME/.edit

##### editversiondir:
Contains the path to the edit versioning directory.  By default: $editdir/version.

##### hidir:
Contains the path to the custom highlight files.  By default: $editdir/hi.

#### Tables:
##### edtables:
Controls if tables showd be shown.  By default, 1.  Should be 1, or 0.

##### edtable_ascii:
Controls if ascii characters should be used to print the table box.  By default, 0.  Should be 1, or 0.

##### edtable_top*, edtable_middle*, edtable_bottom*, edtable_horizontal*, edtable_vertical*:
These variables is where the characters used to draw the tables are set.

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
edty=0
edimg=0
...
````

That means, in your script, you have to source bashed, and set edtmux to 0, so that the commands running in the script will not mess with your tmux sessions.  edimg is also set to 0, unless you want images on your results.

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
& should be used like \\& when you substituting something with it.  Example:

````
esu x '\&'
````

#### Syntax highlighting:
It will misbehave here and there (at least I'm not alone on this).  It is useful enough to catch some bugs, but not perfect.

#### Images and emore:
It seems that chafa, tycat, and more does not work well together, so, for now, emore does not display images.

#### Escape sequences and ec:
Escape sequences will be lost when a command is executed in a region of the text that contains them.  It's done that way because passing escape sequences to commands will, in general, yield the wrong result.  You can force the escape sequences on ec input by setting edecesch to 0.

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
- editexternal, ee: edit region in $EDITOR;
- editfind, ef: find text;
- editfmt, efmt: format paragraphs;
- editinsert, ei: insert line;
- editjoin, ej: join lines;
- editlevel, el: count tab indentation;
- editlocate, efl: find line;
- editmediaqueue, emq: show all media files in a text file when using Terminology.
- editmore, emore, scroll file forward using more;
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
- editescape: manipulate and print escape sequences;
- edithi: display text;
- editimg: display images;
- editpresent: display file contents; 
- editregion: used internally to separate regions of the text;
- editsyntax: set the syntax to be used;
- edittable: display tables;
- edittable_printbox: print a line of a tale box
- edittable_printline: print a line of a table text;
- edittycat, etycat: print media on the terminal using Terminology tycat;
- editwindowtmux: used to open and find tmux windows;
- editwindowty: used to open and find terminology windows;
- editwindow: open/find windows;

Also, some functions will come in pairs, for example: editappend, and \_editappend.  These \_functions are used for auto completing the arguments of the functions, and should not be called directly.

# org files:
Bashed have it's own flavor of org.  For now, there's only a subset of babel, described below.

## syntax:
To configure org syntax highlight:

````
mkdir -p ~/.edit/hi
cp /path/to/bashed/extra/highlight/org-simple.lang ~/.edit/hi/
````

# Modules:
## Babel:
Bashed have a module that can do some things that org-babel, from Emacs can.  It does:
- Block execution;
- noweb;
- tangle;

### Configuration:
Add to your ~/.bashrc, after sourcing bashed:

````
source /path/to/bashed/modules/babel/babel.sh
````

### Source blocks:
Source blocks are written like this:

````
#+name: block_name
#+begin_src lang syntax dir noweb tangle
code ...
#+end_src
````

Where:
- lang is how the block will be executed;
- syntax is the syntax highlight to be used for the source code inside the block
- dir is a path to cd when executing the block, or 0;
- noweb is 1, or 0;
- tangle is a path to write the block, or 0;

### How to use it:
For example, a simple shell block:

````
#+name: example
#+begin_src sh sh 0 0 0
ls
#+end_src
````

After that, with the file containing the block opened, you can executing the block like this:

````
babel example
````

Or you can do

````
babel n
````

Where n is the line number of the #+name line.  Also, you can:

````
es n
babel
````

Where n, again, is the line number of the #+name line.  Blocks from another files can be executed like this:

````
babel n filename
babel name filename
````

Where n is the line number of the block, name is the name of the block, and filename is the name of the file containing the block.

#### noweb:
A block can include source code from another block.  For example:

````
#+name: block_1
#+begin_src sh sh 0 0 0
echo "hello"
#+end_src

#+name: block_2
#+begin_src sh sh 0 1 0
<<block_1>>
echo "world"
#+end_src
````

If you execute the block_2, the output will be:

````
hello
world
````

You can also include blocks from other files, like this:

````
#+begin_src sh sh 0 1 0
<</path/to/file:::block_1>>
echo "world"
#+end_src
````

If file is in the current directory, you can use just "file":

````
...
<<file:::block_1>>>
...
````

#### tangle:
Tangle works like this:

````
#+name: block_1
#+begin_src sh sh 0 0 0
echo "hello"
#+end_src

#+name: block_2
#+begin_src sh sh 0 1 /path/to/result/file
<<block_1>>
echo "world"
#+end_src
````

The path/to/result/file will contain:

````
echo "hello"
echo "world"
````

### Execution langs available:
By default, babel come with these langs;
- as;
- c;
- cpp;
- python;
- python_2;
- sh;
- tex_png;
- yasm;
- yasm_gcc;
- yasm_gcc_no_pie;

#### How to customized it:
You can copy the langs definitions, and the babel_exec array to your ~/.bashrc, and customize it.  The definitions are just shell commands inside a variable.  These definitions should be added to babel_exec array like: name:::var, where name will be the lang name, like c, cpp, etc, and the var will be the variable containing the code to be executed.  Just look into the modules/babel/babel.sh and it will become clear.

## Db:
This module is a file tagging system.

### Configuration:
Add to your ~/.bashrc, after sourcing bashed:

````
source /path/to/bashed/modules/db/db.sh
````

### How it works:
#### Inserting:
To insert a file, use the editdbinsert function.  For example:

````
editdbinsert /path/to/file tag1,tag2
````

#### Deleting:
To delete a file from the database, use editdbdelete:

````
editdbdelete /path/to/file
````

#### Moving:
To move a file on the database, use editdbmove:

````
editdbmove /path/to/file /new/path/to/dir
````

File will be move to dir.

#### Searching:
##### Searching tags:
To search tagged files:

````
editdbsearch tag1,tag2
````

###### Tag subtraction:
Tags can be subtracted from the search.  For example, to search all the files containing the tags t1, and t3, but not t2:

````
editdbsearch t1,-t2,t3
````

You can search using a curses interface, by using editdbsearchcurses.  The command used to opening the result of the curses search is setted in the variable edbopencommand, that is setted by default to eo.

##### Searching files:
To search for files, use editdbquery:

````
editdbquery files 'regex'
````

For example:

````
editdbquery files 'sh$'
````

##### Tags of a file:
To see what tags a file have, use editdbquery:

````
editdbquery tags /path/to/file
````

#### Tag operations:
##### Adding tags to a file:
To add a tag to a file that was previously inserted in the database:

````
editdbinserttag /path/to/file tag3,tag4
````

##### Deleting tags of a file:
To remove a tag of a file that was previously inserted in the database:

````
editdbdeletetag /path/to/file tag3,tag4
````

##### Moving tags of a file:
To move a tag of a file that was previously inserted in the dabatase, that is, change a set of tags to a new one:

````
editdbmovetag /path/to/dir tag3,tag4 tag5,tag6
````

All the tagged files will be moved to dir.

#### Tag directories, and inheritance:
You can add a directory to the database, with tags.  After that, any file added to the database that is under the added directory will inherit it's tags.  For example, if you add:

````
editdbinsert /path/to/directory d1,d2
````

And then:

````
editdbinsert /path/to/directory/f1 t1,t2
````

The directory will have tags d1, and d2, and f1 will have tags d1, d2, t1, and t2.

#### Actions:
You can apply acions on tagged files.  The actions are: delete, move, command, inserttags, deletetags, movetags.  These actions will be applied in the database, and in the files, that means, for example, that a delete action will delete the entries of the database, and the corresponding files in the filesystem, so be careful =D.

##### Deleting tagged files:
To delete tagged files:

````
editdbaction delete tag1,tag2
````

#### Moving taggeed files:
To move tagged files:

````
editdbaction move tag1,tag2 /path/to/destiny
````

#### Executing commands on tagged files:

````
editdbaction command tag1,tag2 "command %file% ..."
````

The command will run once for each file.  The %file% will be substituted for the file name at each iteration.

#### Inserting tags on tagged files:
````
edbtdbaction inserttags tag1,tag2 tag3,tag4
````

This will insert tag3, and tag4 in all files tagged with tag1, and tag2

#### Deleting tags on tagged files:
````
editdbaction deletetags tag1,tag2 tag3,tag4
````

This will delete tag3, and tag4 for every file tagged with tag1, and tag2.

#### Moving tagged files:
````
editdbaction movetags tag1,tag2, tag3,tag4 tag5,tag6
````

This will move tag3, and tag4 to tag5, and tag6, in every file tagged with tag1, and tag2.
 
### Clean:
To delete files from the database tha don't exist anymore in the filesystem:

````
editdbclean
````

### Auto completion:
Before use auto completing, you need to generate the cache files:

````
editdbgeneratecache
````

After executing it, you can use auto completion on the editdb* commands.

### The database file:
The database file is a text file.  It's path is setted in the edbfile variable.  By default, it will be ~/.edit/db/db.  You can change this variable to something else, this allows you to have multiple databases.  For example:

````
edbfile=/home/user/Documents/db
````

Now all the editdb* commands will work with this database file.

### Function dictionary:
- edb, editdbsearch;
- edba, editdbaction;
- edbc, editdbclean;
- edbdt, editdbdeletetag;
- edbd, editdbdelete;
- edbg, editdbgeneratecache;
- edbit, editdbinserttag;
- edbi, editdbinsert
- edbm, editdbmove;
- edbmt, editdbmovetag;
- edbq, editdbquery;
- edbu, editdbsearchcurses;

## Session:
This module is a more traditional way of handling files.  It will provide a list of files you have opened, mechanism to open, close, switch, save state, etc.

### Configuration:
Add to your ~/.bashrc, after sourcing bashed:

````
source /path/to/bashed/modules/session/session.sh
````

You will also need to set edtmux, and edty, to 0.

### Opening files:
Use the command editsessionopen, eso for short:

````
editsessionopen /path/to/file
````

Files can be opened with arguments, like:

````
editsessionopen /path/to/file argument
editsessionopen /path/to/file:argument
````

It works the same as editopen/eo.

### Closing files:
To close a file, use the editsessionclose command, esq for short:

````
editsessionclose
````

### Writing state:
To write the state of the session, use editsessionwrite, esw for short:

````
editsessionwrite
````

This will save the state of the editing session for the current file.  By state I mean the content of the variables used to configure bashed, like edcmd, edimg, edesc, etc.

### Listing sessions:
To list the sessions, that is, the opened files, use the editsession command, ese for short, with list argument:

````
editsession list
````

Each session will be given a number, this number is used to select a session.

### Selecting a session:
To select a session, use the editsession command, ese for short, with a number argument:

````
editsession 1
````

This number should be one of the numbers displayed for each session by editsession list.

### Deleting session:
To delete a session, use the editsession command, ese for short, with delete argument, and a number:

````
editsession delete 1
````

This number should be one of the numbers displayed for each session by editsession list.

### db and sessions:
You may want to set the edbopencommand to eso, so the curses search will open files using eso, instead of the default eo.

### Function dictionary:
- editsession, ese;
- editsessionopen, eso;
- editsessionclose, esq;
- editsessionwrite, esw;
