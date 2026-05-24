#!/bin/bash
# =================================================================
# usuwator_GRUB.sh
# - usuwa inteligentne bloki GrubZilla oraz stare wpisy CloneZilla
# - tworzy kopię zapasową pliku 40_custom
# =================================================================

GRUB_FILE="/etc/grub.d/40_custom"

# --- Sprawdzenie uprawnień ---
if [ "$(id -u)" -ne 0 ]; then
  echo "🚫 Ten skrypt musi być uruchomiony z uprawnieniami administratora (sudo)." >&2
  exit 1
fi

# --- Sprawdzenie, czy plik istnieje ---
if [ ! -f "$GRUB_FILE" ]; then
  echo "⚠️ Plik $GRUB_FILE nie istnieje. Przerywam."
  exit 1
fi

# --- Sprawdzenie, czy jest coś do roboty ---
# Szukamy albo nowych znaczników, albo starego słowa kluczowego
if ! grep -qE "### GRUBZILLA START ###|menuentry.*CloneZilla" "$GRUB_FILE"; then
    echo "👍 Nie znaleziono żadnych wpisów do usunięcia. Plik jest czysty."
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

echo "🛡️  Tworzę kopię zapasową pliku $GRUB_FILE..."
cp "$GRUB_FILE" "$BACKUP_PATH"
[ -n "$SUDO_USER" ] && chown "$SUDO_USER:$SUDO_USER" "$BACKUP_PATH"
echo "✅ Kopia zapisana w: $BACKUP_PATH"

# --- Właściwe czyszczenie za pomocą SED ---
echo "🔥 Czyszczenie pliku $GRUB_FILE..."

# 1. Usuwamy nowe bloki (wszystko między znacznikami włącznie)
sed -i '/### GRUBZILLA START ###/,/### GRUBZILLA KONIEC ###/d' "$GRUB_FILE"

# 2. Usuwamy stare wpisy (jeśli zostały po poprzednich wersjach)
sed -i '/menuentry "CloneZilla/,/^}/d' "$GRUB_FILE"

# 3. Usuwamy nadmiarowe puste linie (zostawia max jedną)
sed -i '/^$/N;/^\n$/D' "$GRUB_FILE"

# Upewniamy się, że uprawnienia są poprawne
chmod 755 "$GRUB_FILE"

echo "✅ Czyszczenie zakończone sukcesem."

# --- Aktualizacja GRUB ---
echo "🔄 Aktualizuję konfigurację GRUB (update-grub)..."
if update-grub; then
    echo "🎉 Gotowe! GRUB zaktualizowany."
else
    echo "❌ Błąd podczas aktualizacji GRUB."
fi

echo ""
read -p "👉 Naciśnij ENTER, aby zamknąć..."
