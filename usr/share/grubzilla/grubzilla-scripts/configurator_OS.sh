#!/bin/bash
# =================================================================
# KonfiguratorOS - Samodzielny Skrypt Graficzny na USB
# =================================================================

# --- AUTOMATYCZNE PODNOSZENIE UPRAWNIEŃ (GRAFICZNIE) ---
if [[ $EUID -ne 0 ]]; then
    # Próba uruchomienia przez pkexec (standard GUI)
    pkexec env DISPLAY=$DISPLAY XAUTHORITY=$XAUTHORITY "$0" "$@"
    
    # Jeśli pkexec nie zadziałało lub użytkownik anulował, kończymy bez błędów w tle
    exit $?
fi

# --- OD TEGO MOMENTU JESTEŚMY ROOTEM ---

# Sprawdzanie czy Zenity jest w systemie (na wszelki wypadek)
if ! command -v zenity >/dev/null; then
    # Jeśli nie ma zenity, musimy użyć terminala jako ratunku
    echo "Error: 'zenity' is not installed. Please install it: sudo apt install zenity"
    read -p "Press Enter to close..."
    exit 1
fi

# --- Automatyczne wykrywanie pendrive'a GrubZilla ---
USB_DATA_PART=$(blkid -L "CLONEZILLA_DATA")
# findmnt jest pewniejszy niż szukanie w /media/$USER
MOUNT_POINT=$(findmnt -n -o TARGET "$USB_DATA_PART")

if [ -z "$MOUNT_POINT" ]; then
    zenity --error --title="Error" --text="The USB stick with the CLONEZILLA_DATA partition could not be found.\n\nMake sure the USB stick is connected and recognised."
    exit 1
fi

# --- Wykrywanie obecnego systemu ---
SYS_PART=$(findmnt -n -o SOURCE /)
SYS_UUID=$(blkid -s UUID -o value "$SYS_PART")

# Jeśli blkid zawiedzie (np. na Live USB), spróbujmy innej metody
if [ -z "$SYS_UUID" ]; then
    # Próba wyciągnięcia UUID z nazwy partycji, jeśli findmnt coś zwrócił
    SYS_UUID=$(lsblk -no UUID "$SYS_PART" | head -n1)
fi

# Krytyczne sprawdzenie:
if [ -z "$SYS_UUID" ]; then
    zenity --error --title="Critical error" \
        --text="The UUID of the system partition could not be retrieved.\n\nYou may be running a script on the Live system that isn't installed on the disk yet."
    exit 1
fi

OS_NAME=$(source /etc/os-release && clean="${NAME// /}" && echo "${clean////}")
SUFFIX=$(echo "$SYS_UUID" | cut -c1-4)

# --- Graficzne pytanie o nazwę systemu ---
OS_GRUB_NAME=$(zenity --entry \
    --title="Configurator GrubZilla" \
    --text="Enter a name for this system:" \
    --entry-text="$OS_NAME ($SUFFIX)")

if [ -z "$OS_GRUB_NAME" ]; then exit 1; fi

# --- Pobranie UUID partycji ISO ---
USB_DEV_BASE=$(echo "$USB_DATA_PART" | sed 's/[0-9]*$//') # Bardziej uniwersalne niż %2
UUID_ISO=$(blkid -s UUID -o value "${USB_DEV_BASE}1")
UUID_DATA=$(blkid -s UUID -o value "$USB_DATA_PART")

# --- Generowanie plików (Pasek postępu) ---
(
echo "10"; echo "# Creating operational scripts..."
# Skrypty Backup/Restore
cat <<EOF > "$MOUNT_POINT/clone_${OS_NAME}_${SUFFIX}.sh"
#!/bin/bash
mkdir -p /home/partimag
mount UUID=$UUID_DATA /home/partimag
SYS_DEV=\$(blkid -U $SYS_UUID)
/usr/sbin/ocs-sr -nogui -q2 -j2 -z9p -i 0 -sfsck -p poweroff saveparts "${OS_NAME}_${SUFFIX}-\$(date +%F-%H%M)" "\$SYS_DEV"
EOF

cat <<EOF > "$MOUNT_POINT/restore_${OS_NAME}_${SUFFIX}.sh"
#!/bin/bash
mkdir -p /home/partimag
mount UUID=$UUID_DATA /home/partimag
LATEST_BACKUP_NAME=\$(ls -td /home/partimag/${OS_NAME}_${SUFFIX}-* 2>/dev/null | head -n1 | xargs -n1 basename)
if [[ -z "\$LATEST_BACKUP_NAME" ]]; then exit 1; fi
SYS_DEV=\$(blkid -U $SYS_UUID)
/usr/sbin/ocs-sr -nogui -e2 -t -iui -k -scr -p poweroff restoreparts "\$LATEST_BACKUP_NAME" "\$SYS_DEV"
EOF

chmod +x "$MOUNT_POINT/clone_${OS_NAME}_${SUFFIX}.sh"
chmod +x "$MOUNT_POINT/restore_${OS_NAME}_${SUFFIX}.sh"

echo "60"; echo "# Preparing the GRUB entry..."
MOUNT_ISO="/mnt/tmp_gz_iso"
mkdir -p "$MOUNT_ISO"
mount "${USB_DEV_BASE}1" "$MOUNT_ISO"

MENU_FILE="OS_${OS_NAME}_${SUFFIX}_grub_menu.txt"
ISO_FILENAME="clonezilla.iso"

cat <<EOF > "$MOUNT_ISO/$MENU_FILE"
menuentry "CloneZilla - System Backup $OS_GRUB_NAME" {
    search --no-floppy --set=iso_dev --fs-uuid $UUID_ISO
    set iso_path="/$ISO_FILENAME"
    loopback loop (\$iso_dev)\$iso_path
    linux (loop)/live/vmlinuz boot=live locales=en_US.UTF-8 keyboard-layouts=us ocs_lang="en_US.UTF-8" ocs_keymap="us" config edd=on nomodeset components union=overlay username=user hostname=debian noswap ocs_live_batch="yes" findiso=\$iso_path ocs_prerun="sudo mkdir -p /home/partimag && sudo mount UUID=$UUID_DATA /home/partimag" ocs_live_run="bash /home/partimag/clone_${OS_NAME}_${SUFFIX}.sh" toram=filesystem.squashfs
    initrd (loop)/live/initrd.img
}

menuentry "CloneZilla - System Restore $OS_GRUB_NAME" {
    search --no-floppy --set=iso_dev --fs-uuid $UUID_ISO
    set iso_path="/$ISO_FILENAME"
    loopback loop (\$iso_dev)\$iso_path
    linux (loop)/live/vmlinuz boot=live locales=en_US.UTF-8 keyboard-layouts=us ocs_lang="en_US.UTF-8" ocs_keymap="us" config edd=on nomodeset components union=overlay username=user hostname=debian noswap ocs_live_batch="yes" findiso=\$iso_path ocs_prerun="sudo mkdir -p /home/partimag && sudo mount UUID=$UUID_DATA /home/partimag" ocs_live_run="bash /home/partimag/restore_${OS_NAME}_${SUFFIX}.sh" toram=filesystem.squashfs
    initrd (loop)/live/initrd.img
}
EOF

umount "$MOUNT_ISO"
rmdir "$MOUNT_ISO"
echo "100"; echo "# All done!"
) | zenity --progress --title="Configurator GrubZilla" --text="Processing data..." --auto-close

# --- Finał ---
zenity --info --title="Success!" --text="System Configuration <b>$OS_GRUB_NAME</b> was saved to a USB drive.\nNow run 'Updater Grub' in the main system to update the Grub menu."





