#!/bin/bash
# =================================================================
# KonfiguratorOS - Samodzielny Skrypt Graficzny na USB
# =================================================================

# --- AUTOMATYCZNE PODNOSZENIE UPRAWNIEŃ (GRAFICZNIE) ---
if [[ $EUID -ne 0 ]]; then
    pkexec env DISPLAY=$DISPLAY XAUTHORITY=$XAUTHORITY "$0" "$@"
    exit $?
fi

# --- OD TEGO MOMENTU JESTEŚMY ROOTEM ---

if ! command -v zenity >/dev/null; then
    echo "Error: 'zenity' is not installed. Please install it: sudo apt install zenity"
    read -p "Press Enter to close..."
    exit 1
fi

# --- Automatyczne wykrywanie pendrive'a GrubZilla ---
USB_DATA_PART=$(blkid -L "CLONEZILLA_DATA")
MOUNT_POINT=$(findmnt -n -o TARGET "$USB_DATA_PART")

if [ -z "$MOUNT_POINT" ]; then
    zenity --error --title="Error" --text="The USB stick with the CLONEZILLA_DATA partition could not be found.\n\nMake sure the USB stick is connected and recognised."
    exit 1
fi

# --- Wykrywanie obecnego systemu ---
SYS_PART=$(findmnt -n -o SOURCE /)
SYS_UUID=$(blkid -s UUID -o value "$SYS_PART")

if [ -z "$SYS_UUID" ]; then
    SYS_UUID=$(lsblk -no UUID "$SYS_PART" | head -n1)
fi

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
USB_DEV_BASE=$(echo "$USB_DATA_PART" | sed 's/[0-9]*$//')
UUID_ISO=$(blkid -s UUID -o value "${USB_DEV_BASE}1")
UUID_DATA=$(blkid -s UUID -o value "$USB_DATA_PART")

# --- Generowanie plików (Pasek postępu) ---
(
echo "10"; echo "# Creating operational scripts..."

# Skrypt Backup
cat <<EOF > "$MOUNT_POINT/clone_${OS_NAME}_${SUFFIX}.sh"
#!/bin/bash
# 1. Montowanie bazy i pobieranie urządzenia po UUID
sudo mkdir -p /home/partimag && sudo mount UUID=$UUID_DATA /home/partimag
DEV_PATH=\$(blkid -U $SYS_UUID)
SYS_DEV=\$(basename "\$DEV_PATH")

if [ -z "\$SYS_DEV" ]; then
    echo "BŁĄD: Nie znaleziono partycji o UUID: $SYS_UUID"
    exit 1
fi

# 2. Dynamiczne sprawdzanie szyfrowania w locie (gocryptfs)
ENC_ARGS=()
CONF="/home/partimag/.grubzilla_enc.conf"

if [ -f "\$CONF" ]; then
    source "\$CONF"
    if [ "\$STATUS" = "enabled" ]; then
        if [ "\$MODE" = "auto" ] && [ -n "\$PASS" ]; then
            ENC_ARGS=("-goc" "-pg" "\$PASS")
        else
            ENC_ARGS=("-goc")
        fi
    fi
fi

# 3. Wywołanie Clonezilli
/usr/sbin/ocs-sr -nogui -q2 -j2 -z9p -i 0 -sfsck "\${ENC_ARGS[@]}" -p poweroff saveparts "${OS_NAME}_${SUFFIX}-\$(date +%F-%H%M)" "\$SYS_DEV"
EXIT_CODE=\$?

# 4. Bezpieczne sprzątanie
if [ -f "\$CONF" ]; then
    source "\$CONF"
    if [ "\$MODE" = "auto" ]; then
        # Zamazujemy zawartość pliku bez natychmiastowej zmiany nazwy przez shred
        shred -z -n 1 "\$CONF" 2>/dev/null
        # Tradycyjne, pewne usunięcie pliku z systemu plików
        rm -f "\$CONF"
        # Usunięcie ewentualnych śmieci po wcześniejszych przebiegach shreda
        rm -f /home/partimag/0* 2>/dev/null
        # Wymuszenie zapisu na nośnik przed zgaszeniem zasilania
        sync
    fi
fi

exit \$EXIT_CODE
EOF

# Skrypt Restore
cat <<EOF > "$MOUNT_POINT/restore_${OS_NAME}_${SUFFIX}.sh"
#!/bin/bash
# 1. Montowanie bazy i pobieranie urządzenia po UUID
sudo mkdir -p /home/partimag && sudo mount UUID=$UUID_DATA /home/partimag
LATEST=\$(ls -td /home/partimag/${OS_NAME}_${SUFFIX}-* 2>/dev/null | head -n1 | xargs -n1 basename)
DEV_PATH=\$(blkid -U $SYS_UUID)
SYS_DEV=\$(basename "\$DEV_PATH")

if [ -z "\$LATEST" ] || [ -z "\$SYS_DEV" ]; then
    echo "BŁĄD: Brak obrazu do przywrócenia lub nie znaleziono dysku!"
    exit 1
fi

# 2. Obsługa deszyfrowania przy restore (jeśli obraz zawiera gocryptfs.conf)
ENC_ARGS=()
CONF="/home/partimag/.grubzilla_enc.conf"

if [ -f "/home/partimag/\$LATEST/gocryptfs.conf" ]; then
    if [ -f "\$CONF" ]; then
        source "\$CONF"
        if [ "\$STATUS" = "enabled" ] && [ -n "\$PASS" ]; then
            ENC_ARGS=("-goc" "-pg" "\$PASS")
        else
            ENC_ARGS=("-goc")
        fi
    else
        ENC_ARGS=("-goc")
    fi
fi

# 3. Wywołanie przywracania
/usr/sbin/ocs-sr -nogui -e2 -t -iui -k -scr "\${ENC_ARGS[@]}" -p poweroff restoreparts "\$LATEST" "\$SYS_DEV"
EXIT_CODE=\$?

# 4. Bezpieczne sprzątanie
if [ -f "\$CONF" ]; then
    source "\$CONF"
    if [ "\$MODE" = "auto" ]; then
        # Zamazujemy zawartość pliku bez natychmiastowej zmiany nazwy przez shred
        shred -z -n 1 "\$CONF" 2>/dev/null
        # Tradycyjne, pewne usunięcie pliku z systemu plików
        rm -f "\$CONF"
        # Usunięcie ewentualnych śmieci po wcześniejszych przebiegach shreda
        rm -f /home/partimag/0* 2>/dev/null
        # Wymuszenie zapisu na nośnik przed zgaszeniem zasilania
        sync
    fi
fi

exit \$EXIT_CODE
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
