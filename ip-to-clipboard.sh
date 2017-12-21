#!/bin/bash

if [ "$1" != "" ]; then
	tail -n1 "$1" | grep -oP "(\d{1,3}\.){3}\d{1,3}" | tr -d '\n' | xsel --clipboard && xsel --clipboard -o
	exit
fi

files=$(ls -1 *.ip)
echo -e "Systems for which there are IP records:\n"
while read file
do
	let $[i++]
	printf "%5s $file\n" "[$i]"
done <<< "$files"
echo
read -p "Enter the number of your selection: " n

file=$(sed -n "${n}p" <<< "$files")

clear
curIP=$(tail -n1 "$file" | grep -oP "(\d{1,3}\.){3}\d{1,3}" | tr -d '\n')
echo -e "Most recent IP history for ${file/.ip/}\n"
tail -n3 "$file"
echo
echo -n $curIP | xsel --clipboard && echo -e "$curIP was copied to the clipboard.\n"
read -p "Press [Enter] to close this window."
