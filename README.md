showlinenum
===========

showlinenum.awk - show line numbers for git diff

This gawk script changes the output of git diff to prepend the line number for each line.

[![screenshot](screenshot.png?raw=true)](screenshot.png?raw=true)

Usage
-----

`git diff [options] | showlinenum.awk [options]`

All options for showlinenum require a value and are specified using the format `option=value`.

Combined diff format is not supported.

Output
------

The diff line output is in this format:  
`[path:]<line number>:<diff line>`

When the path is shown it's the new version's file path. Line numbers are shown for lines in the new version of the file (ie lines that are the same or added). If a line appears only in the old version of the file (ie lines removed) or the warning indicator is found then padding space is used in place of a line number. If a file was removed a tilde ~ is used in place of a line number.

The first character in `<diff line>` is one of four indicators:  
`-` : Line removed  
`+` : Line added  
` ` : Line same  
`\` : diff warning about previous line

For example:
```
 :-removed
7:+added
8: common
 :\ No newline at end of file
```

As far as I know the backslash indicator is only used for the missing newline at EOF warning. When that warning appears it applies to the line immediately above it. In the example above both the old and new version of the compared file are missing the newline at EOF. If the line above a warning is a removed line then the warning applies to the old version of the file, and if the line above a warning is an added line then the warning applies to the new version of the file.

On error a line that starts with `ERROR:` and is followed by script name and error message(s) --which may be one or more lines-- is sent to standard error output (stderr). The script then continues to the next line. ***This is unimplemented for now. All errors are treated as fatal errors.***

On fatal error a line that starts with `FATAL:` and is followed by script name and error message(s) --which may be one or more lines-- is sent to standard error output (stderr). The script then aborts with exit code 1.

Examples
--------

Simple example. Line numbers are prepended to git diff's output.  
`git diff --cached | showlinenum.awk`

This script properly handles the ANSI escape color codes output by git diff. To get color output you have to force git diff to send it by passing `--color=always`. When that option is used the color output is always output so it is not recommended unless you are either outputting to the terminal or somewhere that can properly handle the color codes. Many scripts do not function correctly when working with color coded input.

This is the same as the first example, but with color output.  
`git diff --color=always --cached | showlinenum.awk`

Options can be passed to this script by using awk's -v option or the traditional way (shown).  
`git diff --color=always HEAD~1 HEAD | showlinenum.awk show_header=0`  
`git diff --color=always HEAD~1 HEAD | showlinenum.awk show_path=1 show_hunk=0`

Options
-------

### Show diff headers.
#### `@show_header [0,1] default: 1`

Example:
```
diff --git a/abc.c b/abc.c
index 285065f..2471f87 100644
--- a/abc.c
+++ b/abc.c
```

### Show line hunks.
#### `@show_hunk [0,1] default: ( show_header ? 1 : 0 )`

Example: `@@ -0,0 +1,17 @@`

### Show paths before line numbers.
#### `@show_path [0,1] default: ( show_header ? 0 : 1 )`

Example:  
`testdir/file:39:+some added text`

### Show a binary file that differs in an empty format. `[path:][~]:`
#### `@show_binary [0,1] default: ( show_path ? 1 : 0 )`

Binary files have no concept of lines, therefore there is no line number or diff line to show that a binary file differs. If the headers are shown you can always see whether or not a binary file differs because there will be a message "Binary files &lt;old&gt; and &lt;new&gt; differ". If the headers are not shown however, that message is suppressed and a binary file that differs has an "empty format" with no information, except for a tilde that will be shown if the file was removed.

Here are two examples of the empty format, one where the path is shown and one where it isn't:  
`testdir/binary_file::`  
`:`

Here is an example of a removed binary file, path shown:  
`calc.exe:~:`

### Allow colons in path.
#### `@allow_colons_in_path [0,1] default: ( show_path ? 0 : 1 )`

If this option is off then abort if a path that contains a colon is encountered. That's done to guarantee that this script's diff line output can always be parsed with the first colon occurring immediately after the full path. Note git diff paths may start with '<commit>:' like HEAD:./foo/bar, and for such a path this option would need to be on.

### Add color to some sections.
#### `@color_{line_number,path,separator} <num>[;num][;num]`

Color the respective section using one or more [ANSI color codes](https://user-images.githubusercontent.com/965580/27257186-e5709826-539a-11e7-9dcb-414fa65a0fbe.png).
This is not recommended unless you are outputting to the terminal.
If semi-colons are present in these options your shell may need them quoted.

Example: "color_line_number=1;37;45" is bright white foreground (1;37) on purple background (45).

[![color_line_number](color_line_number.gif?raw=true)](color_line_number.gif?raw=true)


Other
-----


### License

showlinenum is free software and it is licensed under the [GNU General Public License version 3 (GPLv3)](http://www.gnu.org/copyleft/gpl.html), a license that will keep it free. You may not remove my copyright or the copyright of any contributors under the terms of the license. The source code for showlinenum cannot be used in proprietary software, but you can for example execute a free software application from a proprietary software application. **In any case please review the GPLv3 license, which is designed to protect freedom, not take it away.**

### Source

The source can be found on [GitHub](https://github.com/jay/showlinenum). Since you're reading this maybe you're already there?

### Send me any questions you have

Jay Satiro `<raysatiro$at$yahoo{}com>` and put showlinenum in the subject.
