#!/bin/bash
# =================================================================
# usuwator_GRUB.sh
# - usuwa inteligentne bloki GrubZilla oraz stare wpisy CloneZilla
# - tworzy kopię zapasową pliku 40_custom
# =================================================================

GRUB_FILE="/etc/grub.d/40_custom"

# --- Sprawdzenie uprawnień ---
if [ "$(id -u)" -ne 0 ]; then
  echo "🚫 This script must be run with administrator privileges (sudo)." >&2
  exit 1
fi

# --- Sprawdzenie, czy plik istnieje ---
if [ ! -f "$GRUB_FILE" ]; then
  echo "⚠️ File $GRUB_FILE It doesn't exist. I'm stopping."
  exit 1
fi

# --- Sprawdzenie, czy jest coś do roboty ---
# Szukamy albo nowych znaczników, albo starego słowa kluczowego
if ! grep -qE "### GRUBZILLA START ###|menuentry.*CloneZilla" "$GRUB_FILE"; then
    echo "👍  No entries were found to delete. The file is clean."
    exit 0
fi

# --- Tworzenie kopii zapasowej ---
if [ -n "$SUDO_USER" ]; then
  USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
  USER_HOME="/root"
fi
BACKUP_FILENAME="40_custom_backup_$(date +%Y-%m-%d_%H-%M-%S)"
BACKUP_PATH="$USER_HOME/$BACKUP_FILENAME"

echo "🛡️  I am backing up the file $GRUB_FILE..."
cp "$GRUB_FILE" "$BACKUP_PATH"
[ -n "$SUDO_USER" ] && chown "$SUDO_USER:$SUDO_USER" "$BACKUP_PATH"
echo "✅ Copy saved in: $BACKUP_PATH"

# --- Właściwe czyszczenie za pomocą SED ---
echo "🔥 Cleaning the file $GRUB_FILE..."

# 1. Usuwamy nowe bloki (wszystko między znacznikami włącznie)
sed -i '/### GRUBZILLA START ###/,/### GRUBZILLA KONIEC ###/d' "$GRUB_FILE"

# 2. Usuwamy stare wpisy (jeśli zostały po poprzednich wersjach)
sed -i '/menuentry "CloneZilla/,/^}/d' "$GRUB_FILE"

# 3. Usuwamy nadmiarowe puste linie (zostawia max jedną)
sed -i '/^$/N;/^\n$/D' "$GRUB_FILE"

# Upewniamy się, że uprawnienia są poprawne
chmod 755 "$GRUB_FILE"

echo "✅ Cleaning completed successfully."

# --- Aktualizacja GRUB ---
echo "🔄 Updating the GRUB configuration (update-grub)..."
if update-grub; then
    echo "🎉 All done! GRUB has been updated."
else
    echo "❌ Error during the GRUB update."
fi

echo ""
read -p "👉 Press ENTER to close..."
