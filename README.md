GrubZilla to w skrócie  program umożliwiający uruchomienie programu CloneZilla z menu Grub oraz wykonanie kopii zapasowej systemu Linux i jej 
przywrócenie za pomocą jednego kliknięcia z w/w menu. 




GrubZilla ułatwia wykonanie kopii zapasowych i przywracanie systemów operacyjnych z rodziny Linux z menu GRUB na pojedynczy dysk twardy 
HDD / SSD - USB (wszystkie systemy operacyjne Linux bazujące na Ubuntu i Debian) ...Uwaga!!! po podłączeniu dysku USB, program GrubZilla 
sformatuje wszystko na USB i utworzy dwie partycje: 2 GB (FAT32) i resztę jako ext4.
Jak to działa:
Po zainstalowaniu programu .deb przed jego uruchomieniem z menu :Administracja
w Linux Mint (inne wersje linux-a mogą mieć różną  pozycję programu w menu np. : System itp )  musisz podłączyć dysk USB !
Po uruchomieniu GrubZilla następuje (okno terminala) formatowanie USB w terminalu masz możliwość wyboru dysku usb np. sda, sdb, sdc itd.

<img width="1452" height="259" alt="Zrzut ekranu z 2026-02-07 11-16-45" src="https://github.com/user-attachments/assets/fd9399d3-0de8-47ae-ba35-62336959375b" />

musisz nazwać swój system operacyjny

<img width="1264" height="243" alt="Zrzut ekranu z 2026-02-07 11-15-00" src="https://github.com/user-attachments/assets/a170ab7b-c10a-4bb1-b838-63015e541dfd" />

Po sformatowaniu USB skopiuj obraz ISO CloneZilli na w/w i partycję FAT32 (nazwa partycji: CLONEZILLA), zmieniając nazwę obrazu na: /clonezilla.iso.
(Uwaga : Jeśli po formatowaniu jedna z partycji jest niewidoczna  wyłącz i podłącz USB ponownie)
Program zaktualizuje GRUB-a i zrobi kopię pliku 40_custom w folderze domowym użytkownika a następnie możesz przełączyć się na inny system (Linux) 
na swoim komputerze jeśli takowy posiadasz. Na drugim systemie podłącz dysk USB i odczytaj oraz zapisz konfigurację tego systemu operacyjnego za 
pomocą skryptu konfigurator_OS.sh (partycja na USB : CLONEZILLA_DATA (ext4) / folder :grubzilla-skrypty, lub w głównym systemie gdzie zainstalowano
program ścieżka: /usr/share/grubzilla/grubzilla-skrypty) lub kliknij skrypt: konfiguratorOS-klik-terminal ), wykonaj podobne działania jak w 
pierwszym kroku i systemie operacyjnym np. nadaj nazwę systemu wyświetlanemu w menu GRUB (obecnego systemu !)  itd. Jeśli masz wiele systemów 
operacyjnych, powtórz te kroki na każdym z nich. Konfiguracje wszystkich zostaną zapisane jako pliki tekstowe na:
USB-HDD/SSD (partycja fat32)   /nazwa_systemu_id_grub_menu.txt. 
Aby zapisać wszystkie konfiguracje w menu GRUB, musimy wrócić do głównego systemu operacyjnego, w którym uruchamiamy polecenie update-grub!
(UWAGA!!! Zarządzanie menu GRUB jest możliwe tylko na jednym systemie operacyjnym bo mielibyśmy ciągle bałagan w menu GRUB). 
Podłącz dysk USB i wybierz: Uruchom Aktualizator-GRUB z menu lub podmenu programu GrubZilla (menu Administracja) albo użyj skryptu 
aktualizator_GRUB.sh.

<img width="715" height="618" alt="podmeu" src="https://github.com/user-attachments/assets/f946c4d0-7783-4c43-b1e8-ada1ffb855c3" />

Po wykonaniu tych operacji i zaktualizowaniu GRUB / ponownym uruchomieniu systemu w menu GRUB powinny pojawić się dodatkowe wpisy, na przykład:

![foto_wynik1](https://github.com/user-attachments/assets/b28858b2-695b-4d24-98e5-4afab2a6bd95)

Info ! : Ze względów bezpieczeństwa formatowanie partycji systemowej jest wykluczone podczas formatowania dysku USB. Jednak przypadkowego
sformatowania innych dysków przez program/skrypt GrubZilla z powodu twojego błędnego wyboru nie można w 100% zapobiec... więc bądź ostrożny 
przy wyborze dysku którego chcesz formatować !. Ponadto dla bezpieczeństwa, podczas uruchamiania polecenia update-grub, w folderze domowym 
użytkownika tworzona jest kopia zapasowa pliku 40_custom (tj. ustawień menu GRUB).
PS. Od jądra 5.3 w systemach Linux urządzenia blokowe są wykrywane niedeterministycznie, tj. niemal losowo. Dlatego w programie GrubZilla
wykrywanie partycji systemowych opiera się na numerze UUID partycji/dysku. Prawdopodobnie jądro 6.15.x powróci do stabilnego stanu.
W podmenu programu GrubZilla znajduje się również dodatkowy skrypt : Usuwator-GRUB  który może pomóc w szybkim usunięciu wszystkich wpisów
zawierających nazwę CloneZilla w pliku 40_custom.Podczas przywracania systemu operacyjnego wybierana jest zawsze ostatnia / najnowsza wersja
obrazu z USB, jeśli chcemy użyć innej możemy wybrać z menu Grub opcję : Clonezilla - Standard TUI żeby samodzielnie wskazać inną kopię systemu.
UWAGA !
Aby poprawnie wykonać kopię zapasową na dysk USB lub przywrócić obraz systemu (CloneZilla) z menu Grub, podczas uruchamiania komputera dysk
USB musi zostać podłączony przed pojawieniem się menu Grub !!! 

