#!/bin/bash
# =================================================================
# grubzilla
# SKRYPT 2: AKTUALIZATOR MENU GRUB
# - Uruchom na GŁÓWNYM systemie, który zarządza GRUB-em.
# - Podłącz dysk USB ze skonfigurowanymi wpisami.
# - Skrypt zbierze wszystkie pliki *_grub_menu.txt z USB.
# - Doda je do /etc/grub.d/40_custom i zaktualizuje GRUB.
# =================================================================

# --- Zmienne globalne ---
GRUB_CUSTOM="/etc/grub.d/40_custom"
MOUNT_ISO_DIR="/mnt/clonezilla_iso_temp"

# --- Sprawdzenie uprawnień ROOT ---
if [[ $EUID -ne 0 ]]; then
    echo "❌ BŁĄD: Ten skrypt musi być uruchomiony z uprawnieniami roota (użyj sudo)."
    exit 1
fi

# --- Wykrycie i wybór dysku USB ---
echo "🔎 Lista dostępnych dysków:"
lsblk -d -o NAME,SIZE,MODEL,TRAN | grep -E "usb|ata|nvme"

read -p "💾 Podaj nazwę urządzenia USB, z którego wczytać konfiguracje (np. sdb): " USB_DISK
USB_PATH="/dev/$USB_DISK"

# --- Walidacja wyboru dysku ---
if [[ ! -b $USB_PATH ]]; then
    echo "❌ BŁĄD: Urządzenie $USB_PATH nie istnieje."
    exit 1
fi

USB_ISO_PART="${USB_PATH}1"
if [[ ! -b $USB_ISO_PART ]]; then
    echo "❌ BŁĄD: Nie znaleziono partycji FAT32 (${USB_DISK}1) na wybranym dysku."
    exit 1
fi

# --- Montowanie partycji FAT32 ---
echo "⚙️ Montowanie partycji FAT32 z dysku USB..."
mkdir -p "$MOUNT_ISO_DIR"
mount "$USB_ISO_PART" "$MOUNT_ISO_DIR"

if ! mountpoint -q "$MOUNT_ISO_DIR"; then
    echo "❌ BŁĄD: Nie udało się zamontować partycji $USB_ISO_PART."
    rmdir "$MOUNT_ISO_DIR"
    exit 1
fi

# --- Sprawdzenie, czy istnieją pliki konfiguracyjne ---
# Używamy prostszego wzorca i wyłączamy na chwilę błąd wyjścia
if ! ls "$MOUNT_ISO_DIR"/*_grub*.txt &>/dev/null; then
    echo "⚠️ OSTRZEŻENIE: Nie znaleziono żadnych plików konfiguracyjnych (*_grub*.txt) na partycji."
    umount "$MOUNT_ISO_DIR"
    rmdir "$MOUNT_ISO_DIR"
    echo "👉 ENTER, aby zamknąć..."
    read -r
    exit 0
fi

# --- Aktualizacja pliku 40_custom ---
echo "✍️  Aktualizowanie pliku $GRUB_CUSTOM..."

# Określ użytkownika, który wywołał skrypt z sudo
# Sudo przechowuje oryginalnego użytkownika w zmiennej SUDO_USER
BACKUP_USER=${SUDO_USER:-$USER}
HOME_DIR=$(getent passwd "$BACKUP_USER" | cut -d: -f6)

if [ -n "$HOME_DIR" ]; then
    BACKUP_PATH="$HOME_DIR/kopia-$(basename "$GRUB_CUSTOM").bak_$(date +%F_%H-%M-%S)"
    cp "$GRUB_CUSTOM" "$BACKUP_PATH"
    echo "👍 Utworzono kopię zapasową jako $BACKUP_PATH"
else
    echo "⚠️ OSTRZEŻENIE: Nie można określić katalogu domowego dla użytkownika. Kopia zapasowa nie została utworzona."
fi

# 3. Dodanie nowych wpisów na końcu pliku
{
    echo ""
    for entry_file in "$MOUNT_ISO_DIR"/*_grub_menu.txt; do
        if [ -f "$entry_file" ]; then
            cat "$entry_file"
            echo "" # Dodatkowa pusta linia dla czytelności
        fi
    done
    echo ""
} >> "$GRUB_CUSTOM"

echo "👍 Nowe wpisy zostały dodane do $GRUB_CUSTOM."

# --- Odmontowanie partycji ---
umount "$MOUNT_ISO_DIR"
rmdir "$MOUNT_ISO_DIR"

# --- Aktualizacja GRUB ---
echo "🔄 Aktualizowanie menu GRUB (update-grub)..."
update-grub

echo "✅ Gotowe! Menu GRUB zostało zaktualizowane."
echo ""
read -p "👉 ENTER, aby zamknąć..." 
