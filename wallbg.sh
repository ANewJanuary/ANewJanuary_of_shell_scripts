arg=$1
if [[ $1 == "" ]]; then
 arg="cold"
fi
wallpapers=$(ls ~/Vshrd/Visual/backgrounds/$arg)
random=$(printf "%s\n" "${wallpapers[@]}" | shuf -n 1)
echo $random
swaybg -m fill -i ~/Vshrd/Visual/backgrounds/$arg/$random &
