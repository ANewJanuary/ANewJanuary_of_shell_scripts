#!/usr/bin/env bash
# mntfix.sh
#
# Clears the dirty flag on the NTFS volumes (data, win) after a crash,
# so the ntfs3 driver will mount them read-write again.
# Mounts come from /etc/nixos/configuration.nix (x-systemd.automount),
# so they remount on next access.
#
# Note: ntfsfix only repairs basic inconsistencies and resets the journal.
# For real filesystem damage, boot Windows and run `chkdsk /f`.
#
# Usage: ./mntfix.sh

set -uo pipefail

declare -A VOLUMES=(
    [/mnt/data]=/dev/disk/by-uuid/432546C97B46BDA3
    [/mnt/win]=/dev/disk/by-uuid/76C42719C426DADF
)

[[ $EUID -ne 0 ]] && exec sudo "$0" "$@"

status=0
for mnt in "${!VOLUMES[@]}"; do
    dev=${VOLUMES[$mnt]}
    echo "── $mnt ($dev)"

    if [[ ! -e $dev ]]; then
        echo "   device not found, skipping"
        status=1
        continue
    fi

    # Unmount the real ntfs3 mount (the autofs trigger stays in place)
    if findmnt -n -t ntfs3 "$mnt" >/dev/null; then
        if ! umount "$mnt"; then
            echo "   can't unmount (busy?) — close programs using it:"
            fuser -vm "$mnt" 2>&1 | sed 's/^/   /'
            status=1
            continue
        fi
    fi

    if ntfsfix -d "$dev"; then
        echo "   cleaned"
    else
        echo "   ntfsfix failed"
        status=1
    fi
done

# A failed dirty mount makes systemd hit its start limit and drop the
# automount, so reset the units and remount explicitly
for mnt in "${!VOLUMES[@]}"; do
    unit=$(systemd-escape -p "$mnt")
    systemctl reset-failed "$unit.mount" "$unit.automount" 2>/dev/null
    systemctl restart "$unit.automount"
    ls "$mnt" >/dev/null 2>&1
    if findmnt -n -t ntfs3 "$mnt" >/dev/null; then
        echo "$mnt mounted"
    else
        echo "$mnt NOT mounted — see: journalctl -b -k | grep ntfs3"
        status=1
    fi
done

exit $status
