#!/bin/sh
set -eu

help_intro() {
    cat <<ENDUSAGE
Welcome to $(rainbow unfortunate)!
The default fortune database is: "$FORTUNE_FILE".
The pretty colors are from the $(rainbow rainbow) command.

A nice way to run $(rainbow fortune) is with a command like this:

    $(rainbow 'fortune | fold -s | rainbow')

Run $(rainbow unfortunate fortunes) to see a list of fortune databases
and how you can get fortunes from them.

Run $(rainbow unfortunate usage) to see other help topics.

The default $(rainbow fortune) database is from
$(rainbow THE INVISIBLE STATES OF AMERICA A TOURISM GUIDE BY UEL ARAMCHEK)
<https://github.com/mrled/fortunate/tree/master/invisiblestates>
Here's a nice fortune to get you started, randomly selected on each run:

$(fortune | fold -s | rainbow)
ENDUSAGE
}

help_fortunes() {
    cat <<ENDUSAGE
There are other fortune databases available at $(rainbow "$FORTUNE_DIR"):
$(ls -AlF "$FORTUNE_DIR" | rainbow)

Use them by passing their name to the $(rainbow fortune) command:

    $(rainbow "fortune $FORTUNE_DIR/mrled.tweets | fold -s | rainbow")
ENDUSAGE
}

help_usage() {
    cat <<ENDUSAGE
Usage: $(rainbow unfortunate [SUBCOMMAND...]): Help topics for this emulated Linux system

$(rainbow unfortunate usage)
    Show this help
$(rainbow unfortunate intro)
    Show intro text
$(rainbow unfortunate fortunes)
    Show list of fortune databases and how to retrieve fortunes from them
ENDUSAGE
}

if test $# -lt 1; then
    help_usage
    exit 1
fi

while test $# -gt 0; do
    case "$1" in
        usage) help_usage; shift;;
        intro) help_intro; shift;;
        fortunes) help_fortunes; shift;;
        *) help_usage; exit 1;;
    esac
done
