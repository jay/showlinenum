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
####
#


function init()
{
    parsing_diff_header = 0;
    found_path = 0;
    path = 0;
    found_line = 0;
    line = 0;

    # To determine whether or not a variable was defined on the command line and is not an empty
    # string it must be tested. Many versions of gawk will show a warning if using option --lint and
    # an undefined variable is evaluated. Therefore this workaround to force define some variables
    # as a string by appending an empty string. The variables are later converted back to a number
    # by get_bool().
    show_header = show_header "";
    show_hunk = show_hunk "";
    show_path = show_path "";

    # Return the variable as a bool value unless it is empty then return its default bool value.
    show_header = get_bool( show_header, 1 );
    show_hunk = get_bool( show_hunk, ( show_header ? 1 : 0 ) );
    show_path = get_bool( show_path, ( show_header ? 0 : 1 ) );
}

# this returns the bool numeric value of 'input' if it contains a numeric or string bool value,
# otherwise it returns the numeric value of default_value.
function get_bool( input, default_value )
{
    if( default_value !~ /^[0-1]$/ )
    {
        print "FATAL: get_bool(): default_value must be a bool value.";
        print "default_value: " default_value;
        exit;
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
        parsing_diff_header = 1;
        found_path = 0;
        path = 0;
        found_line = 0;
        line = 0;

        if( show_header )
        {
            print;
        }

        next;
    }

    # check for combined diff line info
    if( $0 ~ /^(\033\[[0-9;]*m)*@@@ / )
    {
        print "FATAL: Failed to parse diff: Combined diff format not supported.";
        exit 1;
    }

    # check for diff line info
    if( $0 ~ /^(\033\[[0-9;]*m)*@@ / )
    {
        line = 0;
        found_line = 0;
        parsing_diff_header = 0;

        if( !found_path )
        {
            print "FATAL: Failed to parse diff: Line info found before path info.";
            exit 1;
        }

        stripped = strip_ansi_color_codes( $0 );

        regex = "^@@ -[0-9]+(,[0-9]+)? \\+([0-9]+)(,[0-9]+)? @@";
        if( stripped ~ regex )
        {
            line = gensub( regex, "\\2", "", stripped );
            line = line + 0;
            # Adding zero to line converts it from a string to an integer.
            # That only works when all color codes have been removed.
        }

        if( !line )
        {
            print "FATAL: Failed to parse diff line info: " $0;
            exit 1;
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
        regex = "^\\+\\+\\+ b\\/(.+)";
        if( stripped ~ regex )
        {
            path = gensub( regex, "\\1", "", stripped );

            # Exit if there's a colon in the path. This is to keep parsing sane.
            if( path ~ /:/ )
            {
                # Parse timestamps instead? I can't find that git diff outputs them.
                print "FATAL: Failed to parse diff: Colons in path are forbidden.";
                print;
                exit 1;
            }

            found_path = 1;
            #print "found path: " path;
        }

        if( show_header )
        {
            print;
        }

        next;
    }

    if( !found_path )
    {
        print "FATAL: Failed to parse diff: Path info not found.";
        exit 1;
    }

    if( !found_line )
    {
        print "FATAL: Failed to parse diff: Line info not found.";
        exit 1;
    }

    if( show_path )
    {
        printf "%s:", path;
    }

    # Awk stores all integers internally as floating point. If print is passed an integer it is
    # allowed convert it to scientific notation which I don't want for line numbers. I'm not sure
    # how relevant this is since it seems to vary between different versions of awk and only when
    # the integer is large.
    # In any case using the 'f' type specifier should show [-9007199254740992,9007199254740992]
    printf "%.0f:", line;
    print;

    if( $0 ~ /^(\033\[[0-9;]*m)*[ +]/ )
    {
        line++;
    }
}
