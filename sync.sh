#!/bin/bash

filename=""
offset=""
direction=""

set -e

function help
{
  echo "This script shifts srt subtitle file on a given offset (format hours:minutes:seconds:milliseconds)"
  echo ""
  echo "Usage: $0 --file <srt_file_path> --offset <offset>" --forward --backward
}

function add_offset
{
  local value=$1
  local offset_mseconds=$2

  local mseconds=$(echo $value | awk -F ":|," '{print (($1 * 60 + $2) * 60 + $3) * 1000 + $4}')
  local res_mseconds=$(echo $mseconds $offset_mseconds | awk '{print $1 + $2}')
  local is_neg=$(echo $res_mseconds | awk '{print $1 < 0 ? 1 : 0}')

  if [ "$is_neg" == "1" ]; then
    local new_value="00:00:00,000"
  else
    local new_value=$(echo $res_mseconds | awk '
      {
        res=$1;
        ms=res%1000;
        res=res/1000;
        sec=res%60;
        res=res/60;
        min=res%60;
        hrs=res/60;
        printf "%02d:%02d:%02d,%03d", hrs, min, sec, ms;
      }' )
  fi

  echo $new_value
}

if [ $# -le 0 ]; then
  help
  exit 1
fi

while :; do
  if [ $# -le 0 ]; then
    break
  fi

  case $1 in
    --help)
      help
      exit 1
      ;;

    --file)
      if [ -n "$2" ]; then
        filename="$2"
        shift
      else
        echo "ERROR: file name should not be empty"
        exit 1
      fi
      ;;

    --offset)
      if [ -n "$2" ]; then
        offset="$2"
        shift
      else
        echo "ERROR: offset should not be empty"
        exit 1
      fi
      ;;

    --forward)
      if [ "$direction" != "" ]; then
        echo "ERROR: only single direction could be set up"
        exit 1
      fi
      direction="1"
      ;;

    --backward)
      if [ "$direction" != "" ]; then
        echo "ERROR: only single direction could be set up"
        exit 1
      fi
      direction="-1"
      ;;

    *)
      echo "ERROR: unknown argument"
      exit 1
      ;;
  esac

  shift
done

if [ "$filename" == "" ]; then
  echo "ERROR: empty filename"
  exit 1
fi

if [ "$offset" == "" ]; then
  echo "ERROR: empty offset"
  exit 1
fi

if [ "$direction" == "" ]; then
  echo "ERROR: empty direction"
  exit 1
fi

output=$(echo "$filename.synced.srt" | sed 's/.srt//')
rm -f $output

echo "Converting dos2unix"
dos2unix $filename &> /dev/null

offset_mseconds=$(echo $offset | awk -F ":" '{print (($1 * 60 + $2) * 60 + $3) * 1000 + $4}')
offset_mseconds=$(echo $offset_mseconds $direction | awk '{print $1 * $2}')

while IFS= read -r line
do
  # Record in srt format is next:
  #
  # <index>
  # <timing>
  # <actual text #1>
  # <actual text #2>
  # ...
  # empty line
  #

  # skip empty lines
  if [ "$line" == "" ]; then
    continue
  fi

  # save index
  index="$line"

  # save new timing
  IFS= read -r line
  start=$(echo $line | awk '{print $1}')
  end=$(echo $line | awk '{print $3}')

  new_start=$(add_offset $start $offset_mseconds)
  new_end=$(add_offset $end $offset_mseconds)

  if [ "$new_end" != "00:00:00,000" ]; then
    echo "$index" >> $output
    echo "$new_start --> $new_end" >> $output
  fi

  # save actual text
  IFS= read -r line
  while [ "$line" != "" ]; do
    if [ "$new_end" != "00:00:00,000" ]; then
      echo "$line" >> $output
    fi
    IFS= read -r line
  done

  # save empty line after record
  if [ "$new_end" != "00:00:00,000" ]; then
    echo "" >> $output
  fi
done < "$filename"

echo "INFO: synced $index records. RESULT: $output"
