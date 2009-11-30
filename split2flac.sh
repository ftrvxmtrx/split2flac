#!/bin/sh
# Copyright (c) 2009 Serge "ftrvxmtrx" Ziryukin
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# Dependencies:
#          shntool, cuetools
# SPLIT:   flac, wavpack, mac
# CONVERT: flac, id3lib, lame, vorbis-tools
# ART:     ImageMagick
# CHARSET: iconv

CONFIG="${HOME}/.split2flac"
TMPCUE="${HOME}/.split2flac_sheet.cue"
TMPPIC="${HOME}/.split2flac_cover.jpg"

NOSUBDIRS=0
NORENAME=0
NOPIC=0
REMOVE=0
PIC_SIZE="192x192"
FORMAT=$(basename $0)
FORMAT=${FORMAT#split2}
FORMAT=${FORMAT%.sh}

# load settings
eval $(cat "${CONFIG}" 2>/dev/null)
DRY=0
SAVE=0
unset PIC
unset FILE
unset CUE
unset CHARSET
FORCE=0

HELP="Usage: split2flac.sh [OPTIONS] FILE
         -o DIRECTORY        * - set output directory
         -cue FILE             - use file as a cue sheet
         -f FORMAT             - use specified output format (current is \${FORMAT})
         -c FILE             * - use file as a cover image
         -cuecharset CHARSET   - convert cue sheet from CHARSET to UTF-8 (no conversion by default)
         -nc                 * - do not set any cover images
         -cs WxH             * - set cover image size (current is \${PIC_SIZE})
         -d                  * - create artist/album subdirs
         -nd                 * - do not create any subdirs
         -r                  * - rename tracks to include title
         -nr                 * - do not rename tracks (numbers only, e.g. '01.\${FORMAT}')
         -p                    - dry run
         -D                  * - delete original file
         -nD                 * - do not remove the original
         -f                    - force deletion without asking
         -s                    - save configuration to \"\${CONFIG}\"
         -h                    - print this message
         -H                    - print README

* - option has effect on configuration if -s option passed.
NOTE: '-c some_file.jpg -s' only allows cover images, it doesn't set a default one.
Supported FORMATs: flac, mp3, ogg."

README="split2flac.sh splits one big APE/FLAC/WV file to FLAC/MP3/OGG tracks with tagging and renaming.
It's better to pass '-p' option to see what will happen when actually splitting tracks.
You may want to pass '-s' option for the first run to save default configuration
(output dir, cover image size, etc.) so you won't need to pass a lot of options
every time, just a filename.
Script will try to find CUE sheet if it wasn't specified. It also supports internal CUE sheets."

# parse arguments
while [ "$1" ]; do
    case "$1" in
        -o)          DIR=$2; shift;;
        -cue)        CUE=$2; shift;;
        -f)          FORMAT=$2; shift;;
        -c)          NOPIC=0; PIC=$2; shift;;
        -cuecharset) CHARSET=$2; shift;;
        -nc)         NOPIC=1;;
        -cs)         PIC_SIZE=$2; shift;;
        -d)          NOSUBDIRS=0;;
        -nd)         NOSUBDIRS=1;;
        -r)          NORENAME=0;;
        -nr)         NORENAME=1;;
        -p)          DRY=1;;
        -D)          REMOVE=1;;
        -nD)         REMOVE=0;;
        -f)          FORCE=1;;
        -s)          SAVE=1;;
        -h)          eval "echo \"${HELP}\""; exit 0;;
        -H)          echo "${README}"; exit 0;;
        *)
            if [ -r "${FILE}" ]; then
                echo "Unknown option $1"
                eval "echo \"${HELP}\""
                exit 1
            elif [ ! -r "$1" ]; then
                echo "Unable to read $1"
                exit 1
            else
                FILE="$1"
            fi;;
    esac
    shift
done

METAFLAC="metaflac --no-utf8-convert"
VORBISCOMMENT="vorbiscomment -R -a"
ID3TAG="id3tag -2"

# search for a cue sheet if not specified
if [ -z "${CUE}" ]; then
    CUE="${FILE}.cue"
    if [ ! -r "${CUE}" ]; then
        CUE=$(echo ${FILE} | sed 's/[^\.]*$//')cue
        if [ ! -r "${CUE}" ]; then
            # try to extract internal one
            # MacOSX sed doesn't have 'I' (case insensitive) flag!
            CUESHEET=$(${METAFLAC} --show-tag=CUESHEET "${FILE}" 2>/dev/null | sed 's/[Cc][Uu][Ee][Ss][Hh][Ee][Ee][Tt]=//')

            if [ -z "${CUESHEET}" ]; then
                CUESHEET=$(wvunpack -q -c "${FILE}" 2>/dev/null)
            fi

            if [ "${CUESHEET}" ]; then
                CUE="${TMPCUE}"
                echo "${CUESHEET}" > "${CUE}"

                if [ $? -ne 0 ]; then
                    echo "Unable to save internal cue sheet"
                    exit 1
                fi
            else
                unset CUE
            fi
        fi
    fi
fi

# print some info and check arguments
echo "Input file  :" ${FILE:?"No input filename given. Use -h for help."}
echo "Cue sheet   :" ${CUE:?"No cue sheet"}

if [ -n "${CHARSET}" ]; then
    echo "Cue charset : ${CHARSET} -> utf-8"
    CUESHEET=$(iconv -f "${CHARSET}" -t utf-8 "${CUE}" 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo "Unable to convert cue sheet from ${CHARSET} to utf-8"
        exit 1
    fi
    CUE="${TMPCUE}"
    echo "${CUESHEET}" > "${CUE}"

    if [ $? -ne 0 ]; then
        echo "Unable to save converted cue sheet"
        exit 1
    fi
fi

# search for a front cover image
if [ ${NOPIC} -eq 1 ]; then
    unset PIC
elif [ -z "${PIC}" ]; then
    # try common names 
    SDIR=$(dirname "${FILE}")

    for i in cover.jpg front_cover.jpg folder.jpg; do
        if [ -r "${SDIR}/$i" ]; then
            PIC="${SDIR}/$i"
            break
        fi
    done

    # try to extract internal one
    if [ -z "${PIC}" ]; then
        ${METAFLAC} --export-picture-to="${TMPPIC}" "${FILE}" 2>/dev/null
        if [ $? -ne 0 ]; then
            unset PIC
        else
            PIC="${TMPPIC}"
        fi
    fi
fi

echo "Cover image :" ${PIC:-"not set"}
echo "Output dir  :" ${DIR:?"Output directory wasn't set"}

# file removal warning
if [ ${REMOVE} -eq 1 ]; then
    echo -n "Also remove original"
    if [ ${FORCE} -eq 1 ]; then
        echo
    else
        echo " if user says 'y'"
    fi
fi

# save configuration if needed
if [ ${SAVE} -eq 1 ]; then
    echo "DIR=\"${DIR}\"" > "${CONFIG}"
    echo "NOSUBDIRS=${NOSUBDIRS}" >> "${CONFIG}"
    echo "NORENAME=${NORENAME}" >> "${CONFIG}"
    echo "NOPIC=${NOPIC}" >> "${CONFIG}"
    echo "REMOVE=${REMOVE}" >> "${CONFIG}"
    echo "PIC_SIZE=${PIC_SIZE}" >> "${CONFIG}"
    echo "Configuration saved"
fi

GETTAG="cueprint -n 1 -t"
VALIDATE="sed s/[^-[:space:][:alnum:]&_#,.'\"]//g"

# get common tags
TAG_ARTIST=$(${GETTAG} %P "${CUE}")
TAG_ALBUM=$(${GETTAG} %T "${CUE}")
TRACKS_NUM=$(${GETTAG} %N "${CUE}")

YEAR=$(awk '{ if (/REM[ \t]+DATE/) { printf "%i", $3; exit } }' < "${CUE}")
YEAR=$(echo ${YEAR} | tr -d -C '[:digit:]')

unset TAG_DATE

if [ -n "${YEAR}" ]; then
    if [ ${YEAR} -ne 0 ]; then
        TAG_DATE="${YEAR}"
    fi
fi

echo
echo "Artist : ${TAG_ARTIST}"
echo "Album  : ${TAG_ALBUM}"
if [ -n "${TAG_DATE}" ]; then
    echo "Year   : ${TAG_DATE}"
fi
echo "Tracks : ${TRACKS_NUM}"
echo

# prepare output directory
OUT="${DIR}"

if [ ${NOSUBDIRS} -ne 1 ]; then
    DIR_ARTIST=$(echo ${TAG_ARTIST} | ${VALIDATE})
    DIR_ALBUM=$(echo ${TAG_ALBUM} | ${VALIDATE})

    if [ "${TAG_DATE}" ]; then
        DIR_ALBUM="${TAG_DATE} - ${DIR_ALBUM}"
    fi

    OUT="${OUT}/${DIR_ARTIST}/${DIR_ALBUM}"
fi

echo "Saving tracks to \"${OUT}\""

if [ ${DRY} -ne 1 ]; then
    # create output dir
    mkdir -p "${OUT}"

    if [ $? -ne 0 ]; then
        echo "Failed to create output directory"
        exit 1
    fi

    case ${FORMAT} in
        flac) ENC="flac flac -8 - -o %f";;
        mp3)  ENC="cust ext=mp3 lame --preset extreme - %f";;
        ogg)  ENC="cust ext=ogg oggenc -q 10 - -o %f";;
        *)    echo "Unknown output format ${FORMAT}"; exit 1;;
    esac

    # split to tracks
    cuebreakpoints "${CUE}" | \
        shnsplit -O never -o "${ENC}" -d "${OUT}" -t "%n" "${FILE}"
    if [ $? -ne 0 ]; then
        echo "Failed to split"
        exit 1
    fi

    # prepare cover image
    if [ "${PIC}" ]; then
        convert "${PIC}" -resize "${PIC_SIZE}" "${TMPPIC}"
        if [ $? -eq 0 ]; then
            PIC="${TMPPIC}"
        else
            echo "Failed to convert cover image"
            unset PIC
        fi
    fi
fi

# set tags and rename
echo
echo "Setting tags"

i=1
while [ $i -le ${TRACKS_NUM} ]; do
    TAG_TITLE=$(cueprint -n $i -t %t "${CUE}")
    f="${OUT}/$(printf %02i $i).${FORMAT}"
    FILE_TRACK=$(basename "$f" .${FORMAT})
    FILE_TITLE=$(echo ${TAG_TITLE} | ${VALIDATE})

    echo "$i: ${TAG_TITLE}"

    if [ ${NORENAME} -ne 1 ]; then
        FINAL="${OUT}/${FILE_TRACK} - ${FILE_TITLE}.${FORMAT}"
        if [ ${DRY} -ne 1 ]; then
            mv "$f" "${FINAL}"
            if [ $? -ne 0 ]; then
                echo "Failed to rename track file"
                exit 1
            fi
        fi
    else
        FINAL="$f"
    fi

    if [ ${DRY} -ne 1 ]; then
        case ${FORMAT} in
            flac)
                ${METAFLAC} --remove-all-tags \
                    --set-tag="ARTIST=${TAG_ARTIST}" \
                    --set-tag="ALBUM=${TAG_ALBUM}" \
                    --set-tag="TITLE=${TAG_TITLE}" \
                    --set-tag="TRACKNUMBER=$i" \
                    "${FINAL}" >/dev/null
                RES=$?

                if [ -n "${TAG_DATE}" ]; then
                    ${METAFLAC} --set-tag="DATE=${TAG_DATE}" "${FINAL}" >/dev/null
                    RES=$((${RES} + $?))
                fi

                if [ -n "${PIC}" ]; then
                    ${METAFLAC} --import-picture-from="${PIC}" "${FINAL}" >/dev/null
                    RES=$((${RES} + $?))
                fi
                ;;

            mp3)
                ${ID3TAG} "-a${TAG_ARTIST}" \
                    "-A${TAG_ALBUM}" \
                    "-s${TAG_TITLE}" \
                    "-t$i" \
                    "-T${TRACKS_NUM}" \
                    "${FINAL}" >/dev/null
                RES=$?

                if [ -n "${TAG_DATE}" ]; then
                    ${ID3TAG} -y"${TAG_DATE}" "${FINAL}" >/dev/null
                    RES=$((${RES} + $?))
                fi
                ;;

            ogg)
                ${VORBISCOMMENT} "${FINAL}" \
                    -t "ARTIST=${TAG_ARTIST}" \
                    -t "ALBUM=${TAG_ALBUM}" \
                    -t "TITLE=${TAG_TITLE}" \
                    -t "TRACKNUMBER=$i" >/dev/null
                RES=$?

                if [ -n "${TAG_DATE}" ]; then
                    ${VORBISCOMMENT} "${FINAL}" -t "DATE=${TAG_DATE}" >/dev/null
                    RES=$((${RES} + $?))
                fi
                ;;
            *)    echo "Unknown output format ${FORMAT}"; exit 1;;
        esac

        if [ ${RES} -ne 0 ]; then
            echo "Failed to set tags for track"
            exit 1
        fi
    fi

    echo "   -> ${FINAL}"

    i=$(($i + 1))
done

rm -f "${TMPPIC}"
rm -f "${TMPCUE}"

if [ ${DRY} -ne 1 -a ${REMOVE} -eq 1 ]; then
    YEP="n"

    if [ ${FORCE} -ne 1 ]; then
        echo -n "Are you sure you want to delete original? [y] >"
        read YEP
    fi

    if [ "${YEP}" = "y" -o ${FORCE} -eq 1 ]; then
        rm -f "${FILE}"
    fi
fi

echo
echo "Finished"
