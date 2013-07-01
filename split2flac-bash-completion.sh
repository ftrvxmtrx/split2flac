#!/usr/bin/env bash

_split2flac () {
  local cur prev opts formats

  _get_comp_words_by_ref cur prev

  opts="-p -o -of -cue -cuecharset -nask -f -e -eh -enca -c -nc -C -nC -cs -d -nd -D -nD -F -colors -nocolors -g -ng -s -h -v"
  formats="flac m4a mp3 ogg wav"

  if [[ ${cur} == -* ]] ; then
    COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
  else
    case "${prev}" in
      -o)
        _filedir -d
        ;;
      -of|-e|-enca|-C|-cs)
        # no completion, wait for user input
        ;;
      -cue)
        _filedir cue
        ;;
      -cuecharset)
        local available_locales
        available_locales=$( iconv -l | sed 's,//,,g' )
        COMPREPLY=( $(compgen -W "${available_locales}" -- ${cur}) )
        ;;
      -c)
        _filedir
        ;;
      -f)
        COMPREPLY=( $(compgen -W "${formats}" -- ${cur}) )
        ;;
      *)
        _filedir
        ;;
    esac
  fi
}

complete -F _split2flac split2flac
