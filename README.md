# bashed
bash wrapper for the ed editor

![screenshot](https://github.com/neoncortex/bashed/blob/main/image/image.png)

## Motivation:
ed is a good text editor, but it's interface is really bad.  I thought that bash would be a good interface for it, plus it allows all the bash trickery to be used directly in an editing session.

## What this does?
It wraps the ed editor in bash functions, allowing it use directly on command line.  It maintain the state, like the current line, using bash variables.

## Dependencies:
- ed;
- tmux;
- highlight;
- xclip;

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

Will copy the current line, to line 5, to the line 1.  The second argument (5, in last case), can be set using +, like +5.

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

Will join the current line with the next.  Can receive a an argument, either a number n, or +n, like:

#### Joining range:
````
ej 2
ej +2
````

### Moving:
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

#### Pitfalls:
##### Escape character:
The character \ can be problematic.  To insert a literal \ character using the wrappers (ea, ei, ech, esu), use \\.  This is not valid for the e command, there, you should use \\ when you command was between '', and \\\\ when you command is between "".  That means, using e, to insert a literal \:

````
e "a\n\\\\\n.\nw"
e 'a\n\\\n.\nw"
````

When using s under e, it gets even scarier.  For example, substituting a for \:
````
e "s/\\\\\\/a\nw"
e 's/\\\\/a\nw'
````

##### Groups:
Groups in regex are like:

````
esu "\\(re\\).*\\(re\\)"
````

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

#### diffarg:
Contains the diff options.  By default: "--color -c".

#### Highlight:
##### syntax:
Contains the name of the syntax file used by highlight for the current file.

##### editsyntax:
Set if es should use syntax.  Should be y, or n.

##### hitheme:
Contains the theme name used by highlight.

### Using e:
Commands can be passed directly to ed, using e, like:

````
e "a\nA new line.\n.\nw"
e "1,2d\nw"
````

