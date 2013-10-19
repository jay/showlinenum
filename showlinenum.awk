#!/bin/gawk -f
#
# Copyright (C) 2013 Jay Satiro <raysatiro@yahoo.com>
# All rights reserved.
#
# This file is part of the showlinenum project.
# https://github.com/jay/showlinenum/
#
# This file is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This file is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this file. If not, see <http://www.gnu.org/licenses/>.
#
#
#
# This gawk script changes the output of git diff to prepend the line number for each line.
#
#
#### Usage:
#
# git diff [options] <required> | showlinenum.awk [option=<value>]
#
# The diff line output is in this format:
# [path:]<line number:><diff line>
#
# On error a line that starts with ERROR: and is followed by script name and error message(s)
# --which may be one or more lines-- is sent to standard error output (stderr). The script then
# continues to the next line. This is unimplemented for now. All errors are treated as fatal errors.
#
# On fatal error a line that starts with FATAL: and is followed by script name and error message(s)
# --which may be one or more lines-- is sent to standard error output (stderr). The script then
# aborts with exit code 1.
#
####
#
#### Examples:
#
# Simple example. Line numbers are prepended to git diff's output.
# git diff --cached | showlinenum.awk
#
# This script properly handles the ANSI escape color codes output by git diff. To get color output
# you have to force git diff to send it by passing --color=always. When that option is used the
# color output is always output so it is not recommended unless you are either outputting to the
# terminal or somewhere that can properly handle the color codes. Many scripts do not function
# correctly when working with color coded input.
#
# This is the same as the first example, but with color output.
# git diff --color=always --cached | showlinenum.awk
#
# Options can be passed to this script by using awk's -v option or the traditional way (shown).
# git diff --color=always HEAD~1 HEAD | showlinenum.awk show_header=0
# git diff --color=always HEAD~1 HEAD | showlinenum.awk show_path=1 show_hunk=0
#
#
####
#
#
#### Options:
#
# @show_header [0,1] default: 1
# Show diff headers.
#
# Example:
# diff --git a/abc.c b/abc.c
# index 285065f..2471f87 100644
# --- a/abc.c
# +++ b/abc.c
#
##
#
# @show_hunk [0,1] default: ( show_header ? 1 : 0 )
# Show line hunks.
#
# Example: @@ -0,0 +1,17 @@
#
##
#
# @show_path [0,1] default: ( show_header ? 0 : 1 )
# Show paths before line numbers.
#
# Example:
# testdir/file:39:+some added text
#
##
#
# @show_binary [0,1] default: ( show_header ? 0 : 1 )
# Show a binary file that differs in an empty format. [path:]<:>
#
# Binary files have no concept of lines, therefore there is no line number to show that a binary
# file differs. If the headers are shown you can always see whether or not a binary file differs
# because there will be a message "Binary files <old> and <new> differ". If the headers are not
# shown however, that message is suppressed and a binary file that differs is signified by a colon
# that ends the line, with no line number before it. That is what I refer to as an "empty format".
#
# Here are two examples of the empty format, one where the path is shown and one where it isn't:
# testdir/binary_file::
# :
#
##
#
# @allow_colons_in_path [0,1] default: 0
# Allow colons in path.
#
# By default this script will abort if it encounters a path that contains a colon. That's done to
# guarantee that this script's diff line output can always be parsed with the first colon occurring
# immediately after the full path, if the path is shown. Even if it's not shown it's still checked.
#
####
#


function reset_header_variables()
{
    parsing_diff_header = 0;
    found_path = 0;
    path = 0;
    found_line = 0;
    line = 0;
    found_diff = 0;
    diff = 0;
}

function init()
{
    reset_header_variables();

    # To determine whether or not a variable was defined on the command line and is not an empty
    # string it must be tested. Many versions of gawk will show a warning if using option --lint and
    # an undefined variable is evaluated. Therefore this workaround to force define some variables
    # as a string by appending an empty string. The variables are later converted back to a number
    # by get_bool().
    show_header = show_header "";
    show_hunk = show_hunk "";
    show_path = show_path "";
    show_binary = show_binary "";
    allow_colons_in_path = allow_colons_in_path "";

    # Return the variable as a bool value unless it is empty then return its default bool value.
    show_header = get_bool( show_header, 1 );
    show_hunk = get_bool( show_hunk, ( show_header ? 1 : 0 ) );
    show_path = get_bool( show_path, ( show_header ? 0 : 1 ) );
    show_binary = get_bool( show_binary, ( show_header ? 0 : 1 ) );
    allow_colons_in_path = get_bool( allow_colons_in_path, 0 );
}

function FATAL( error_message )
{
    # Apparently there is no portable way to get this script's name at runtime?
    error_message = "FATAL: showlinenum: " error_message;
    print error_message > "/dev/stderr";
    exit 1;
}

# this returns the bool numeric value of 'input' if it contains a numeric or string bool value,
# otherwise it returns the numeric value of default_value.
function get_bool( input, default_value )
{
    if( default_value !~ /^[0-1]$/ )
    {
        errmsg = "get_bool(): default_value must be a bool value.";
        errmsg = errmsg "\n" "default_value: " default_value;
        FATAL( errmsg );
    }

    regex = "^[[:blank:]]*([0-1])[[:blank:]]*$";
    return ( ( input ~ regex ) ? gensub( regex, "\\1", "", input ) : default_value ) + 0;
}

# this returns a string with the ansi color codes removed
function strip_ansi_color_codes( input )
{
    return gensub( /\033\[[0-9;]*m/, "", "g", input );
}

# main
{
    if( NR == 1 )
    {
        init();
    }

    if( $0 ~ /^(\033\[[0-9;]*m)*diff / )
    {
        reset_header_variables();
        parsing_diff_header = 1;

        diff = strip_ansi_color_codes( $0 );
        found_diff = 1;

        if( show_header )
        {
            print;
        }

        next;
    }

    # check for combined diff line info
    if( $0 ~ /^(\033\[[0-9;]*m)*@@@ / )
    {
        FATAL( "Combined diff format not supported." );
    }

    # check for diff line info
    if( $0 ~ /^(\033\[[0-9;]*m)*@@ / )
    {
        line = 0;
        found_line = 0;
        parsing_diff_header = 0;

        if( !found_path )
        {
            FATAL( "Line info found before path info." );
        }

        stripped = strip_ansi_color_codes( $0 );

        regex = "^@@ -[0-9]+(,[0-9]+)? \\+([0-9]+)(,[0-9]+)? @@.*$";
        if( stripped ~ regex )
        {
            line = gensub( regex, "\\2", "", stripped );
            line = line + 0;
            # Adding zero to line converts it from a string to an integer.
            # That only works when all color codes have been removed.
        }

        if( !line )
        {
            FATAL( "Line number not found." "\n" $0 );
        }

        found_line = 1;

        if( show_hunk )
        {
            print;
        }

        next;
    }

    if( parsing_diff_header )
    {
        stripped = strip_ansi_color_codes( $0 );
        #print "before: " $0;
        #print "after : " stripped;

        # Check for path
        regex = "^\\+\\+\\+ (\\042?b\\/.+)$";
        if( stripped ~ regex )
        {
            path = gensub( regex, "\\1", "", stripped );

            # Exit if there's a colon in the path. This is to keep parsing sane.
            if( !allow_colons_in_path && ( path ~ /:/ ) )
            {
                # Parse timestamps instead? I can't find that git diff outputs them.
                errmsg = "Colons in path are forbidden.";
                errmsg = errmsg "\n" "To override use option allow_colons_in_path.";
                FATAL( errmsg );
            }

            found_path = sub( /b\//, "", path );

            if( show_header )
            {
                print;
            }

            next;
        }

        regex = "^Binary files (.*) differ$";
        if( stripped ~ regex )
        {
            path = gensub( regex, "\\1", "", stripped );

            # This gets the path for a binary file by digging through the first line of the diff
            # header ('diff') and the binary file notice line ('stripped') to find the longest
            # rightmost match between the two.
            while( match( path, /and \042?b\/.+$/ ) )
            {
                path_len = RLENGTH - 4;
                path = substr( path, RSTART + 4, path_len );

                diff_rstart = ( length( diff ) + 1 ) - path_len;
                if( diff_rstart < 1 )
                {
                    continue;
                }
                path2 = substr( diff, diff_rstart, path_len );

                if( path == path2 )
                {
                    found_path = sub( /b\//, "", path );
                    break;
                }
            }

            if( show_header )
            {
                print;
            }

            if( !found_path )
            {
                errmsg = "Path info for binary file not found in header lines.";
                errmsg = errmsg "\n" diff "\n" stripped;
                FATAL( errmsg );
            }

            if( show_binary )
            {
                if( show_path )
                {
                    printf "%s:", path;
                }

                print ":";
            }

            reset_header_variables();
            next;
        }

        if( show_header )
        {
            print;
        }

        next;
    }

    if( !found_path )
    {
        FATAL( "Path info not found." );
    }

    if( !found_line )
    {
        FATAL( "Line info not found." );
    }

    if( show_path )
    {
        printf "%s:", path;
    }

    # I'm using match() to get the location of the indicator character because if I were to use
    # gensub() I'd have to strip the diff line of ansi color codes either before or after since it
    # can embed the color codes in a match. I think it would be slower to strip every diff line if
    # done before, or if done after it could lead to corruption if internally gensub() prepends or
    # appends escape codes to the indicator that it finds in the diff line itself (ie actually part
    # of the diff line, not the colorization added by git diff). Unfortunately early versions of
    # gawk (like the one included with git for Windows) do not support an array parameter for
    # match() so the indicator must be extracted on success by using substr().
    if( ( $0 !~ /^(\033\[[0-9;]*m)*[ +-]/ ) || !match( $0, /[ +-]/ ) || ( RLENGTH != 1 ) )
    {
        FATAL( "Failed to extract indicator from diff line." "\n" $0 );
    }

    indicator = substr( $0, RSTART, RLENGTH );

    if( ( indicator == "+" ) || ( indicator == " " ) )
    {
        # Awk stores all integers internally as floating point. If print is passed an integer it is
        # allowed convert it to scientific notation which I don't want for line numbers. I'm not
        # sure how relevant that is since it seems to vary between different versions of awk and
        # only when the integer is large (how large?).
        # Using the 'f' type specifier should show [-9007199254740992, 9007199254740992]
        printf "%.0f:", line++;
    }
    else if( indicator == "-" )
    {
        padding = length( ( line + 1 ) "" ) + 1;
        printf "%" padding "s", ":";
    }
    else
    {
        FATAL( "Diff line indicator not recognized." "\n" $0 );
    }

    print;
}
