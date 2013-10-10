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
# This gawk script changes the output of git diff to include the path and line number for each line.
#
#

BEGIN {
    parsing_diff_header = 0;
    found_path = 0;
    path = 0;
    found_line = 0;
    line = 0;
}

# this returns a string with the ansi color codes removed
function strip_ansi_color_codes( input )
{
    return gensub( /\033\[[0-9;]*m/, "", "g", input );
}

# main
{
    if( $0 ~ /^(\033\[[0-9;]*m)*diff / )
    {
        parsing_diff_header = 1;
        found_path = 0;
        path = 0;
        found_line = 0;
        line = 0;
        print "found diff header: " $0;
        next;
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
        print path ":" $0;
        next;
    }

    if( parsing_diff_header )
    {
        stripped = strip_ansi_color_codes( $0 );
        #print "before: " $0;
        #print "after : " stripped;

        # Check for path
        regex = "^\\+\\+\\+ b\\/(.*)";
        if( stripped ~ regex )
        {
            path = gensub( regex, "\\1", "", stripped );
            found_path = 1;
            #print "found path: " path;
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

    print path ":" line ":" $0;

    if( $0 ~ /^(\033\[[0-9;]*m)*[ +]/ )
    {
        line++;
    }
}
