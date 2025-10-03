#!/bin/bash
if [[ $1 == "n" ]]; then
				cd ~/Vshrd/Learner-Portfolio
				select=$(find . -print | fzf)
				ext=$(basename "$select")
				name=$(echo "${ext%.*}")
				echo -e -n "[[$name]]" | wl-copy

elif [[ $1 == "p" ]]; then
				cd ~/Vshrd/Learner-Portfolio
				select=$(find . -print | fzf)
				ext=$(basename "$select")
				name=$(echo "${ext%.*}")
				echo -e -n "[$name]: $select" | wl-copy
else
				echo "Arguments incorrect. \
								 Use lpc n to copy the name and \
								 lpc p to copy the path."
fi

