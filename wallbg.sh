arg=$1
if [[ $1 == "" ]]; then
 arg="dark"
fi
wallpapers=$(ls ~/Vshrd/Visual/backgrounds/$arg)
random=$(printf "%s\n" "${wallpapers[@]}" | shuf -n 1)
echo $random
swaybg -m stretch -i ~/Vshrd/Visual/backgrounds/$arg/$random &
