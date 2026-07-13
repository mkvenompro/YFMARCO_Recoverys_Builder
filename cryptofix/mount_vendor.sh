#!/sbin/sh
# Explicitly mount /vendor and /vendor_dlkm in TWRP recovery.
#
# TWRP only "prepares" logical partitions (creates the dm-<n> device and a
# by-name symlink) but never actually mounts /vendor as a filesystem. Without
# /vendor mounted, /vendor/etc/vintf/manifest.xml is unreadable, so TWRP sees
# an empty keymaster/keymint version and decryption fails (hangs / reboots).
#
# TWRP's fstab processing creates /dev/block/bootdevice/by-name/vendor once the
# logical partition is prepared, so we wait for that node and then mount.

mkdir -p /vendor /vendor_dlkm

wait_for() {
    dev="$1"
    i=0
    while [ ! -e "$dev" ] && [ "$i" -lt 90 ]; do
        sleep 1
        i=$((i + 1))
    done
}

# /vendor must be mounted so the keymint/gatekeeper HALs and the vintf manifest
# (/vendor/etc/vintf/manifest.xml) are reachable. The keymint shared libs are
# bundled in /sbin/cryptofix and exposed to the HALs via LD_LIBRARY_PATH in
# init.recovery.mt6789.rc, so /system is intentionally NOT mounted here (mounting
# super's /system would replace the recovery's own keystore2 and libs).
wait_for /dev/block/bootdevice/by-name/vendor
mount -t erofs -o ro /dev/block/bootdevice/by-name/vendor /vendor 2>/dev/null || \
    mount -t ext4 -o ro /dev/block/bootdevice/by-name/vendor /vendor 2>/dev/null

wait_for /dev/block/bootdevice/by-name/vendor_dlkm
mount -t erofs -o ro /dev/block/bootdevice/by-name/vendor_dlkm /vendor_dlkm 2>/dev/null || \
    mount -t ext4 -o ro /dev/block/bootdevice/by-name/vendor_dlkm /vendor_dlkm 2>/dev/null

# Now that /vendor (keymint HAL + vintf manifest) is reachable, start crypto.
setprop crypto.ready 1
