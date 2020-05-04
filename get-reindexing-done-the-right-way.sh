#!/bin/sh

# MIT License
# 
# Copyright (c) 2020 Evgeny Karpovich
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

NAME="get-reindexing-done-the-right-way"
VERSION="0.1.0-alpha"

show_help()
{
    echo "Usage: $0 [OPTION]... [FILE]..."
    echo
    echo "${NAME} ${VERSION}"
    echo
    echo "Sync information about the FILEs (the current directory by default) with media files database."
    echo "Full reindexing using synoindex takes too much time, so lets do it the right way and handle"
    echo "only difference, without rescaning already indexed files."
    echo
    echo "Options:"
    echo "  -t, --type TYPE       video, photo or music, default: ${TYPE}"
    echo "  -f, --force           ignore a timestamp file and check all files"
    echo
    echo "  -l, --log FILE        log file location, default: ${LOG_FILE}"
    echo "  -V, --verbose         add more details to the log"
    echo "  -s, --silent          do not duplicate log messages to stdout"
    echo
    echo "  -h, --help            show this help message and exit"
    echo "  -v, --version         show script version and exit"
    echo "  -L, --list-only       show currently indexed files and exit"
    echo
    echo "THE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR"
    echo "IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,"
    echo "FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE"
    echo "AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER"
    echo "LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,"
    echo "OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE"
    echo "SOFTWARE."
    echo
    echo "Copyright (c) 2020 Evgeny Karpovich, released under MIT license"
    echo
}

show_version()
{
    echo "${VERSION}"
}

# initialize parameters with default values
WORK_DIR="/var/log/${NAME}"
mkdir -p "${WORK_DIR}"

# type: video, photo or music
TYPE="video"

# where to create a reference time stamp file
TIMESTAMP_FILE="${WORK_DIR}/time-of-last-reindexing-${TYPE}.empty"

# where to write log
LOG_FILE="${WORK_DIR}/log.txt"

# if set to "no", then logs will be duplicated to stdout
SILENT="no"

# print additional debug information
VERBOSE="no"

# list currently indexed files and exit
LIST_ONLY="no"

# ignore timestamp file and scan all the files
FORCE="no"

log()
{
    if [ "${SILENT}" = "no" ] ; then
        echo `date` "$@" | tee --append "${LOG_FILE}"
    else
        echo `date` "$@" >> "${LOG_FILE}"
    fi
}

log_verbose()
{
    if [ "${VERBOSE}" = "yes" ] ; then
        log "$@"
    fi
}

log_error()
{
    echo `date` $@ | tee --append "${LOG_FILE}" >&2
}

FILES=""
while [ $# -gt 0 ] ; do
    KEY=$1
    case "$KEY" in

        -h|--help)
            show_help
            exit 0
        ;;

        -v|--version)
            show_version
            exit 0
        ;;

        -f|--force)
            FORCE="yes"
            shift # skip option
        ;;

        -t|--type)
            TYPE=$2
            if ! echo "${TYPE}" | grep --quiet "^\(video\|photo\|music\)$" ; then
                log_error "Type ${TYPE} is unrecognized. Supported values are 'video', 'photo' or 'music'"
                exit 1
            fi
            TIMESTAMP_FILE="${WORK_DIR}/time-of-last-reindexing-${TYPE}.empty"
            shift # skip key
            shift # skip value
        ;;

        -l|--log)
            LOG_FILE=$2
            shift # skip key
            shift # skip value
        ;;

        -V|--verbose)
            VERBOSE="yes"
            shift # skip option
        ;;

        -s|--silent)
            SILENT="yes"
            shift # skip option
        ;;

        -L,--list-only)
            LIST_ONLY="yes"
            shift # skip option
        ;;

        *)  # unknown option, try to handle it as a file or directory
            if [ ! -e "$1" ] ; then
                log_error "'$1' is either unknown option or non-existing (unavailable) file or directory (verify your permissions)"
                exit 1
            fi
            FILES="$FILES $1"
            shift # skip argument
        ;;

    esac
done

# if no files specified, then use current directory
if [ -z "${FILES}" ] ; then
    FILES=`pwd`
fi

# define additional utility functions
sql()
{
    psql mediaserver postgres -tA -c "$1"
}

create_timestamp()
{
    touch "${TIMESTAMP_FILE}"
}

add_file()
{
    log "Adding '$1' to the database"
    synoindex -a "$1"
}

add_file_if_not_indexed()
{
    log_verbose "Found '$1', checking if it's indexed"
    COUNT=`sql "SELECT COUNT(*) FROM ${TYPE} WHERE path = \\$\\$$1\\$\\$"`
    if [ $COUNT -gt 0 ] ; then
        log_verbose "'$1' is already indexed, skipping"
        return
    fi 
    add_file "$1"
}

remove_file()
{
    log "Removing '$1' from the database"
    synoindex -d "$1"
}

# check pre-requisites
if ! [ -x "`command -v synoindex`" ]; then
  log_error 'Error: synoindex is not installed, looks like it is not DSM'
  exit 1
fi

if ! [ -x "`command -v psql`" ]; then
  log_error 'Error: psql is not installed, looks like it is not DSM'
  exit 1
fi

if [ "${LIST_ONLY}" = "yes" ] ; then
    sql "SELECT path FROM ${TYPE} ORDER BY path"
    exit 0
fi

case ${TYPE} in
    "video")
        FILTERS=".*\.\(avi\|mkv\|mov\|mpg\|mp4\|vob\|3gp\)$"
    ;;
    "photo")
        FILTERS=".*\.\(jpg\|jpeg\|png\)$"
    ;;
    "music")
        FILTERS=".*\.\(mp3\|oog\)$"
    ;;
esac


log "-------------- Started '$0' --------------"
log "Files to scan:  '${FILES}'"
log "Type:           '${TYPE}'"
log "Filters:        '${FILTERS}'"
log "Log file:       '${LOG_FILE}'"

log "Looking for non-indexed files"
if [ ! -e "${TIMESTAMP_FILE}" -o "${FORCE}" = "yes" ] ; then
    log "Have not found a timestamp reference file ${TIMESTAMP_FILE} or -f/--force option provided"

    log "Looking for all ${TYPE} files matching regexp ${FILTERS}"
    find ${FILES} -type f | grep -i ${FILTERS} | while read FILE
    do
        add_file_if_not_indexed "${FILE}"
    done
else
    TIMESTAMP=`stat --format "%z" ${TIMESTAMP_FILE}`
    log "Found a timestamp reference file ${TIMESTAMP_FILE}, last touched on ${TIMESTAMP}"
    log "Looking for ${TYPE} files matching regexp ${FILTERS} and newer than ${TIMESTAMP}"
    find ${FILES} -type f -newer ${TIMESTAMP_FILE} | grep -i ${FILTERS} | while read FILE
    do
        add_file_if_not_indexed "${FILE}"
    done
fi

log "Looking for indexed files that do not exist anymore"
sql "SELECT path FROM ${TYPE} ORDER BY path" | while read FILE
do
    if [ ! -e "${FILE}" ] ; then
        remove_file "${FILE}"
    fi
done

log "Creating/updating timestamp reference file ${TIMESTAMP_FILE}"
create_timestamp

log "-------------- We're done, exiting --------------"

# just add a few empty lines to the end of the log file for readability
echo >> "${LOG_FILE}" 
echo >> "${LOG_FILE}" 
echo >> "${LOG_FILE}"

exit 0
