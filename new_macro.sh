cd /home/orpheus/Vshrd/macros

name=$(zenity --entry --text="Name: WARNING: text is taken from clipboard!")
text=$(wl-paste)

echo "$text"

touch $name
wl-paste >> $name
