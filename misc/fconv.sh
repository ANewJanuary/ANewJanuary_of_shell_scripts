#!bin/bash
for i in *.mp4;
  do name=`echo "$i" | cut -d'.' -f1,2`
  echo "$name"
  ffmpeg -i "$i" -b:a 192K -vn "${name}.mp3"
done


