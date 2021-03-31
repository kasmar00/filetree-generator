#!/bin/bash

# shellcheck disable=SC2044,SC2013 # disabled due to IFS and set -f
set -eu

# Don't split on spaces and tabs.
IFS=$'\n'

# Disable bash globbing.
set -f

function display_help {
    bold=$(tput bold)
    normal=$(tput sgr0)
    italic=$(tput smul) #italic generates underline text, becouse terminal may have problems with dispaying italic
    echo "Script generates a graph of file system of provided directories, or of current directory if no directories are specified"
    echo
    echo "${bold}USAGE${normal}"
    echo " ${bold}filetree${normal} [-dhnopsv] [-b ${italic}browser${normal}] [-f ${italic}format${normal}] [-e ${italic}export-file${normal}] [${italic}directory${normal}] ..."
    echo
    echo "${bold}OPTIONS${normal}"
    echo " -b, --browser    allows specifing a program to open export file"
    echo " -d, --keep-dot   doesn't delete .dot file"
    echo " -e, --export     allows setting export file name, deafult: $EXPORT_FILE"
    echo " -f, --format     allows specifing export format"
    echo "   Avaliable formats: dot, xdotps, pdf, svg, svgz, fig, png, gif, jpg, jpeg, json, imap, cmapx"
    echo " -h, --help       displays this help and exits"
    echo " -n, --no-export  doesn't generate an export file, only .dot file, implies -d"
    echo " -o, --open       opens the export file using sensible browser, only if export generated, specific browser may be specified using --browser"
    echo " -p, --pretty     display treee in pretty style (coloring)"
    echo " -s, --symlinks   doesn't follow symlinks"
    echo " -v, --version    displays version and author information and exits"
}

function display_version {
    echo "Filetree generator"
    echo "Systemy Operacyjne"
    echo "2020-06 Marcin Kasznia"
}

function prettyfiy { #proof of concept, colors and shapes are just an example
    #caution! the fall through statemnet (;;&) requires bash version to be equal or greater than 4
    case "$1" in
        *"directory"*)
            echo -n "shape=box, " >> "$DOT_FILE"
            ;;&
        *"executable"*) #unfortunatelly doesnt always work
            echo -n "shape=diamond, " >> "$DOT_FILE"
            ;;&
        *"symbolic link"*)
            echo -n "shape=invhouse, color=red, " >> "$DOT_FILE"
            ;;&
        *"Python script"* | *".py:"*)
            echo -n "color=blue, " >> "$DOT_FILE"
            ;;&
        *"C source"* | *".c:"*)
            echo -n "color=green, " >> "$DOT_FILE"
            ;;&
        *"archive"* | *".zip:"* | *".tar.gz:"*)
            echo -n "shape=octagon, color=green, " >> "$DOT_FILE"
            ;;&
        *"PDF"*)
            echo -n "shape=trapezium, color=lightslateblue, " >> "$DOT_FILE"
            ;;
    esac
}

function visit {
    directory=$*
    directory=$(echo "$directory/" | tr -s "/")
    echo "\"$directory\" [shape=box, label=\"$directory\"];" >> "$DOT_FILE"
    local a #without this line, there are problems with recursive calling
    for a in $(find "$directory" -type d | grep -v -E "/\.")
    do
        local dir
        dir=$(echo "$a/" | tr -s "/") #squezze slash
        dirprim=${dir//\"/\\\"}
        for b in $(ls -Ah "$a")
        do
            FTYPE=$(file "$dir$b")
            b=${b//\"/\\\"} #changes double quote to escape double quote in file name
            echo -n "\"$dirprim$b\" [" >> "$DOT_FILE" #name of node (file name plus dir)
            if $PRETTY; then
                prettyfiy "$FTYPE"
            fi
            echo "label=\"$b\"];" >> "$DOT_FILE" #short file name
            aprim=${a//\"/\\\"}
            echo "\"$aprim\" -> \"$dirprim$b\";" >> "$DOT_FILE" #connection from dir to file

            if $SYMLINKS; then
                if [[ $FTYPE == *"symbolic link"* ]]; then
                    TARGET=$(file "$dir$b" | rev |cut -d ' ' -f 1 |rev)
                    #alterantiveley target of symlink could be found in ls
                    #TARGET=$(ls -l $dir |grep  $b | rev | cut -d ' ' -f 1 |rev)
                    echo "\"$dir$b\" -> \"$TARGET\" [style=dashed];" >> "$DOT_FILE" #connection from symlink to file
                    visit "$TARGET" #recursively call visit on target of symlink
                fi
            fi
        done
    done
}

#handling options
TEMP=$(getopt -o hvndsopb:f:e: --long help,version,no-export,keep-dot,symlinks,open,pretty,browser:,format:,export: -- "$@")
eval set -- "$TEMP"

GENERATE=true #if true, export file will be created
DELETE_DOT=true #if true, temporary dot file will be deleted
EXPORT_FORMAT="pdf" #sets default export format
SYMLINKS=true #if true, will follow symlinks
EXPORT_FILE="filetree" #Name of export file
DOT_FILE="filetree-temp.dot" #name and possibly location of temporary dot file
OPEN=false #if true, the export file will be opned by browser
BROWSER="sensible-browser"
PRETTY=false #if true, the export file will be colored

while true; do
    case "$1" in
    -h | --help)
        display_help
        exit 1
        ;;
    -v | --version)
        display_version
        exit 1
        ;;
    -n | --no-export)
        GENERATE=false
        DELETE_DOT=false
        shift
        ;;
    -d |--keep-dot)
        DELETE_DOT=false
        shift
        ;;
    -f | --format)
        EXPORT_FORMAT=$2
        shift 2
        ;;
    -o | --open)
        OPEN=true
        shift
        ;;
    -b | --browser)
        BROWSER=$2
        shift 2
        ;;
    -s | --symlinks)
        SYMLINKS=false
        shift
        ;;
    -e | --export)
        EXPORT_FILE=$2
        shift 2
        ;;
    -p | --pretty)
        PRETTY=true
        shift
        ;;
    --)
        shift
        break
        ;;
    esac
done

echo "digraph graphname {" > $DOT_FILE #configuration of graph
echo 'rankdir="LR"' >> $DOT_FILE #graph direction

if [ -z "$*" ]; then
    visit "."
else
    for i in "$@" #generating graph for each element in input
    do
        visit "$i"
    done
fi

echo "}" >> $DOT_FILE #finish graph

if $GENERATE; then #generating graph to export file
    dot "-T$EXPORT_FORMAT" $DOT_FILE > "$EXPORT_FILE.$EXPORT_FORMAT"
    echo "Genereted export as" "$EXPORT_FILE.$EXPORT_FORMAT"
    if $OPEN; then
        $BROWSER "$EXPORT_FILE.$EXPORT_FORMAT" &
    fi
fi

if $DELETE_DOT; then #deleting dot file
    rm $DOT_FILE
else
    echo "Preserved dot file as" $DOT_FILE
fi
