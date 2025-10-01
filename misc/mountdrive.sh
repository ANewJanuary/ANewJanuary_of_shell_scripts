echo "Name of drive: $1"
sudo ntfsfix $1
sudo mount -t ntfs-3g $1 /run/media

