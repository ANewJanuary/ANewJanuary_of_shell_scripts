arg=$1
if [[ $1 == "" ]]; then
 arg="yorumi"
fi
wallpapers=$(ls ~/Vshrd/Projects/Visual/backgrounds/$arg)
random=$(printf "%s\n" "${wallpapers[@]}" | shuf -n 1)
echo $random
swaybg -m fill -i ~/Vshrd/Projects/Visual/backgrounds/$arg/$random &
