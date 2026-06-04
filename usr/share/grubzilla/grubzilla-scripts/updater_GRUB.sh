#!/bin/bash
# =================================================================
# AKTUALIZATOR MENU GRUB - Wersja Graficzna
# - Automatycznie wykrywa USB GrubZilla
# - Zbiera konfiguracje i aktualizuje 40_custom
# =================================================================

GRUB_CUSTOM="/etc/grub.d/40_custom"
MOUNT_ISO_DIR="/mnt/clonezilla_iso_temp"

# --- Sprawdzenie ROOT (Graficznie) ---
if [[ $EUID -ne 0 ]]; then
    zenity --error --title="Permission error" --text="Run the program as root (sudo)."
    exit 1
fi

# --- Wykrywanie i wybór dysku USB ---
while true; do
    # Próba automatycznego znalezienia partycji o nazwie CLONEZILLA
    USB_ISO_PART=$(blkid -L "CLONEZILLA")
    
    if [ -z "$USB_ISO_PART" ]; then
        # Jeśli nie znaleziono po nazwie, pozwól wybrać z listy
        LISTA_USB=$(lsblk -dno NAME,SIZE,MODEL,TRAN | grep "usb" | awk '{print $1"|"$2"|"$3" "$4"|"$5}')
        
        if [ -z "$LISTA_USB" ]; then
            zenity --question --title="Updater GrubZilla" --width=400 \
                --text="❌ The GrubZilla USB drive was not found.\n\nConnect it and click ‘Yes’ to refresh, or ‘No’ to exit."
            if [ $? -ne 0 ]; then exit 1; fi
            continue
        fi

        WYBOR=$(echo "$LISTA_USB" | zenity --list \
            --title="Updater - USB Selection" \
            --text="The partition was not detected automatically: CLONEZILLA.\nSelect the USB device manually:" \
            --column="Disk" --column="Size" --column="Model" --column="Type" \
            --width=600 --height=300)
        
        if [ $? -ne 0 ] || [ -z "$WYBOR" ]; then exit 1; fi
        USB_DISK=$(echo "$WYBOR" | cut -d'|' -f1)
        USB_ISO_PART="/dev/${USB_DISK}1"
    fi
    break
done

# --- Montowanie i przetwarzanie (Pasek postępu) ---
(
echo "10"; echo "# Mounting a USB partition..."
mkdir -p "$MOUNT_ISO_DIR"
mount "$USB_ISO_PART" "$MOUNT_ISO_DIR" || exit 1

echo "30"; echo "# Checking configuration files..."
if ! ls "$MOUNT_ISO_DIR"/*_grub*.txt &>/dev/null; then
    echo "ERROR: No menu files found on the USB drive!"
    umount "$MOUNT_ISO_DIR"
    rmdir "$MOUNT_ISO_DIR"
    exit 1
fi

echo "50"; echo "# Backing up 40_custom..."
BACKUP_USER=${SUDO_USER:-$USER}
HOME_DIR=$(getent passwd "$BACKUP_USER" | cut -d: -f6)
cp "$GRUB_CUSTOM" "$HOME_DIR/40_custom_backup_$(date +%F_%H%M%S).bak"

echo "60"; echo "# Usuwanie starych wpisów GrubZilla..."
sed -i '/### GRUBZILLA START ###/,/### GRUBZILLA KONIEC ###/d' "$GRUB_CUSTOM"

echo "70"; echo "# Building a new menu..."
UUID_USB=$(blkid -s UUID -o value "$USB_ISO_PART")
TEMP_BLOCK=$(mktemp)

{
    echo "### GRUBZILLA START ###"
    echo "# ID_USB:$UUID_USB"
    # Sortowanie naturalne, aby "1_" było zawsze pierwsze
    for entry_file in $(ls "$MOUNT_ISO_DIR"/*_grub*.txt | sort -V); do
        echo ""
        cat "$entry_file"
    done
    echo ""
    echo "### GRUBZILLA KONIEC ###"
} > "$TEMP_BLOCK"

cat "$TEMP_BLOCK" >> "$GRUB_CUSTOM"
cp "$TEMP_BLOCK" "$MOUNT_ISO_DIR/grubzilla_full_config.txt"
rm "$TEMP_BLOCK"

echo "80"; echo "# Refreshing the GRUB boot menu..."
update-grub &>/dev/null

echo "100"; echo "# All done!"
umount "$MOUNT_ISO_DIR"
rmdir "$MOUNT_ISO_DIR"

) | zenity --progress --title="Updater GrubZilla" --text="Starting the update..." --percentage=0 --auto-close

# --- Sprawdzenie czy nie wystąpił błąd w potoku ---
if [ $? -ne 0 ]; then
    zenity --error --title="Error" --text="An error occurred during the update.\nMake sure the USB flash drive is properly formatted."
    exit 1
fi

# --- Finał ---
zenity --info --title="Update complete" --width=400 \
    --text="<b>The GRUB menu has been successfully updated!</b>\n\nSystem configurations saved to USB are now visible in the GRUB menu when the computer starts up"

exit 0
