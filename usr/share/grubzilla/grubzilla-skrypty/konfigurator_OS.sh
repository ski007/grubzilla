#!/bin/bash
# =================================================================
# grubzilla 
# SKRYPT 1: GENERATOR KONFIGURACJI CLONEZILLA  
# - Uruchom na każdym systemie, który ma być dodany do menu GRUB.
# - Wykrywa UUID systemu i dysku USB.
# - Tworzy skrypty clone/restore na partycji ext4.
# - Zapisuje wpis GRUB do pliku .txt na partycji FAT32.
# - NIE modyfikuje GRUB-a lokalnego systemu.
# =================================================================

set -euo pipefail

ISO_FILENAME="clonezilla.iso"
MOUNT_DATA_DIR="/mnt/clonezilla_data_temp"
MOUNT_ISO_DIR="/mnt/clonezilla_iso_temp"

# --- Sprawdzenie uprawnień ROOT ---
if [[ $EUID -ne 0 ]]; then
  echo "❌ BŁĄD: Ten skrypt musi być uruchomiony z uprawnieniami roota (użyj sudo)."
  exit 1
fi

# --- Wykrycie partycji systemowej i nazwy OS ---
echo "⚙️  Wykrywanie informacji o systemie..."
SYS_PART=$(findmnt -n -o SOURCE /)
SYS_UUID=$(blkid -s UUID -o value "$SYS_PART")
OS_NAME=$(source /etc/os-release && clean="${NAME// /}" && echo "${clean////}")

# --- JEDYNA ZMIANA: Dodajemy unikalność tylko do nazw skryptów ---
# Pobieramy 4 znaki bez dotykania głównej zmiennej OS_NAME
SUFFIX=$(echo "$SYS_UUID" | cut -c1-4)

CLONE_SCRIPT_BACKUP="clone_${OS_NAME}_${SUFFIX}.sh"
CLONE_SCRIPT_RESTORE="restore_${OS_NAME}_${SUFFIX}.sh"

echo "📦 Wykryto system: $OS_NAME, ID: $SUFFIX, partycja: $SYS_PART"

# --- Wykrycie i wybór dysku USB ---
echo "🔎 Lista dostępnych dysków:"
lsblk -d -o NAME,SIZE,MODEL,TRAN | grep -E "usb|ata|nvme" || true

read -p "💾 Podaj nazwę urządzenia USB (np. sdb): " USB_DISK
USB_PATH="/dev/$USB_DISK"

if [[ ! -b "$USB_PATH" ]]; then
  echo "❌ BŁĄD: Urządzenie $USB_PATH nie istnieje lub nie jest urządzeniem blokowym."
  exit 1
fi

USB_ISO_PART="${USB_PATH}1"
USB_DATA_PART="${USB_PATH}2"

if [[ ! -b "$USB_ISO_PART" || ! -b "$USB_DATA_PART" ]]; then
  echo "❌ BŁĄD: Na wybranym dysku nie znaleziono wymaganych partycji (${USB_DISK}1 i ${USB_DISK}2)."
  echo "   Ten skrypt nie partycjonuje – uruchom najpierw instalator, który tworzy FAT32 + EXT4."
  exit 1
fi

# --- Pobranie UUID partycji USB ---
echo "⚙️  Odczytywanie UUID z partycji USB..."
UUID_ISO=$(blkid -s UUID -o value "$USB_ISO_PART" || true)
UUID_DATA=$(blkid -s UUID -o value "$USB_DATA_PART" || true)

if [[ -z "${UUID_ISO:-}" || -z "${UUID_DATA:-}" ]]; then
  echo "❌ BŁĄD: Nie udało się odczytać UUID z partycji na dysku $USB_PATH."
  exit 1
fi

echo "🔗 UUID FAT32 (ISO):  $UUID_ISO"
echo "🔗 UUID EXT4 (DATA):  $UUID_DATA"

# --- Tworzenie skryptów backup/restore na EXT4 ---
echo "✍️  Tworzenie skryptów na partycji danych (ext4)..."

mkdir -p "$MOUNT_DATA_DIR"
mount "$USB_DATA_PART" "$MOUNT_DATA_DIR"

# --- Backup ---
cat > "$MOUNT_DATA_DIR/$CLONE_SCRIPT_BACKUP" <<EOF
#!/bin/bash
set -euo pipefail
mkdir -p /home/partimag
mount UUID=$UUID_DATA /home/partimag || true
SYS_DEV=\$(readlink -f "/dev/disk/by-uuid/$SYS_UUID")
if [[ -z "\${SYS_DEV:-}" || ! -b "\$SYS_DEV" ]]; then
  echo "❌ Nie znaleziono urządzenia blokowego dla UUID=$SYS_UUID"
  exit 1
fi
/usr/sbin/ocs-sr -nogui -q2 -j2 -z9p -i 0 -sfsck -p poweroff \\
  saveparts "${OS_NAME}_${SUFFIX}-\$(date +%F-%H%M)" "\$SYS_DEV"
EOF
chmod +x "$MOUNT_DATA_DIR/$CLONE_SCRIPT_BACKUP"

# --- Restore ---
cat > "$MOUNT_DATA_DIR/$CLONE_SCRIPT_RESTORE" <<EOF
#!/bin/bash
set -euo pipefail
mkdir -p /home/partimag
mount UUID=$UUID_DATA /home/partimag || true
LATEST_BACKUP_NAME=\$(ls -td /home/partimag/${OS_NAME}_${SUFFIX}-* 2>/dev/null | head -n1 | xargs -n1 basename || true)
if [[ -z "\${LATEST_BACKUP_NAME:-}" ]]; then
  echo "❌ Brak backupu dla ${OS_NAME}_${SUFFIX}"
  read -p 'Naciśnij ENTER aby wyjść...' _
  exit 1
fi
SYS_DEV=\$(readlink -f "/dev/disk/by-uuid/$SYS_UUID")
if [[ -z "\${SYS_DEV:-}" || ! -b "\$SYS_DEV" ]]; then
  echo "❌ Nie znaleziono urządzenia blokowego dla UUID=$SYS_UUID"
  exit 1
fi
/usr/sbin/ocs-sr -nogui -e2 -t -iui -k -scr -p poweroff \\
  restoreparts "\$LATEST_BACKUP_NAME" "\$SYS_DEV"
EOF
chmod +x "$MOUNT_DATA_DIR/$CLONE_SCRIPT_RESTORE"

umount "$MOUNT_DATA_DIR"
rmdir "$MOUNT_DATA_DIR"
echo "👍 Skrypty zostały zapisane na EXT4: $CLONE_SCRIPT_BACKUP, $CLONE_SCRIPT_RESTORE"

# --- GRUB: zapis do pliku na FAT32 (bez modyfikacji lokalnego GRUB-a) ---
mkdir -p "$MOUNT_ISO_DIR"
mount "$USB_ISO_PART" "$MOUNT_ISO_DIR"

ENTRY_FILE="$MOUNT_ISO_DIR/${OS_NAME}_${SUFFIX}_grub_menu.txt"
read -p "📝 Podaj nazwę systemu (do wyświetlenia w GRUB): " OS_GRUB_NAME

cat > "$ENTRY_FILE" <<EOF
menuentry "CloneZilla - Backup systemu $OS_GRUB_NAME" {
    search --no-floppy --set=iso_dev --fs-uuid $UUID_ISO
    set iso_path="/$ISO_FILENAME"
    loopback loop (\$iso_dev)\$iso_path
    linux (loop)/live/vmlinuz boot=live locales=pl_PL.UTF-8 keyboard-layouts=pl ocs_lang="pl_PL.UTF-8" ocs_keymap="pl" \\
        config edd=on nomodeset components union=overlay username=user hostname=debian noswap \\
        ocs_live_extra_param="" ocs_live_batch="yes" findiso=\$iso_path \\
        ocs_prerun="sudo mount UUID=$UUID_DATA /home/partimag" \\
        ocs_live_run="bash /home/partimag/$CLONE_SCRIPT_BACKUP" toram=filesystem.squashfs
    initrd (loop)/live/initrd.img
}

menuentry "CloneZilla - Przywracanie systemu $OS_GRUB_NAME" {
    search --no-floppy --set=iso_dev --fs-uuid $UUID_ISO
    set iso_path="/$ISO_FILENAME"
    loopback loop (\$iso_dev)\$iso_path
    linux (loop)/live/vmlinuz boot=live locales=pl_PL.UTF-8 keyboard-layouts=pl ocs_lang="pl_PL.UTF-8" ocs_keymap="pl" \\
        config edd=on nomodeset components union=overlay username=user hostname=debian noswap \\
        ocs_live_extra_param="" ocs_live_batch="yes" findiso=\$iso_path \\
        ocs_prerun="sudo mount UUID=$UUID_DATA /home/partimag" \\
        ocs_live_run="bash /home/partimag/$CLONE_SCRIPT_RESTORE" toram=filesystem.squashfs
    initrd (loop)/live/initrd.img
}
EOF

umount "$MOUNT_ISO_DIR"
rmdir "$MOUNT_ISO_DIR"

echo "✅ Zakończono pomyślnie!"
echo "📄 Plik GRUB zapisano: (FAT32)/${OS_NAME}_grub_menu.txt"
echo "ℹ️  Pamiętaj, aby na partycji FAT32 znajdował się plik: $ISO_FILENAME"
echo ""
read -p "👉 ENTER, aby zamknąć..." 
