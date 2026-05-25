**GrubZilla** is a program that allows you to launch CloneZilla directly from the GRUB menu and create or restore Linux system backups with a single click from that menu.

GrubZilla is based on **CloneZilla**  - a free backup utility for HDD/SSD partitions and disks. CloneZilla is a powerful tool with many advanced options, but unfortunately it also uses a rather old-fashioned TUI (Text User Interface), which may discourage beginner users from using it.
   GrubZilla simplifies backup creation and restoration of Linux operating systems directly from the GRUB menu to a single HDD/SSD USB drive (all Ubuntu and Debian-based Linux distributions available for PC).
Warning!
After connecting the USB drive, GrubZilla will format the entire USB device and create two partitions:

- 2 GB FAT32 partition
- remaining space as ext4

**How It Works**
After installing the .deb package, before launching the program from:
Menu → Administration in Linux Mint (other Linux distributions may place the program in a different menu category, e.g. “System”) you must connect the USB drive first. After launching GrubZilla(menu), the program control panel will appear with several options to choose from:

<img width="600" height="320" alt="image" src="https://github.com/user-attachments/assets/2347d5be-d9a5-4cb6-822a-c18da40a928a" />

First Launch  - USB Preparation
When launching the first option: GrubZilla, the program will perform its main tasks:

- ​    formatting the USB drive
- ​    configuring all files required for proper operation.

In the displayed window you can choose the USB device: sda, sdb, sdc etc.

<img width="400" height="250" alt="image" src="https://github.com/user-attachments/assets/bff94244-a77a-4f05-9839-207da6610294" />

You must also enter a name for your operating system.

<img width="300" height="120" alt="image" src="https://github.com/user-attachments/assets/25862e81-edb6-4a0e-9f64-465d326556a9" />

After formatting the USB drive, copy the CloneZilla ISO image to the FAT32 partition. Partition label: CLONEZILLA 
Download :  https://clonezilla.org/downloads.php

Rename the ISO file to: /clonezilla.iso
Note:If one of the partitions is not visible after formatting, disconnect and reconnect the USB device. The program will update GRUB and create a backup copy of the 40_custom file in the user’s home directory.
Configuring Additional Linux Systems
You can then switch to another Linux system installed on your computer (if available).
On the second system: 
    1. connect the USB drive,
    2. read and save the operating system configuration using the script: configurator_OS.sh
Location:
USB ext4 partition: CLONEZILLA_DATA/grubzilla-scripts 
or installed system path: /usr/share/grubzilla/grubzilla-scripts 
You can also use the script: configuratorOS-click-terminal
Assign a name for the operating system that should appear in the GRUB menu.
If you have multiple Linux systems installed, repeat these steps on each system.
All configurations will be saved as text files on: 
USB-HDD/SSD (FAT32):/system_name_id_grub_menu.txt

   To save all Linux system configurations into the GRUB menu, return to the main operating system where the update-grub command is managed.
**IMPORTANT!**
GRUB menu management should only be performed from one operating system. Otherwise, the GRUB configuration may become disorganized.
Connect the USB drive and choose:

- GRUB Updater
- or use the submenu in GrubZilla(menu)
- or run the script: updater_GRUB.sh

After updating GRUB and rebooting the system, additional entries should appear in the GRUB menu. :

<img width="600" height="400" alt="image" src="https://github.com/user-attachments/assets/2e930179-7b64-4cd3-a080-ded0d0caf859" />

Important! 
Formatting the currently used system partition is blocked for safety reasons.
However, GrubZilla cannot prevent accidental formatting of another USB drive if the user 
selects the wrong device. Be very careful when choosing the disk to format.
Additionally, during every update-grub operation, a backup copy of the 40_custom GRUB configuration file is automatically created in the user’s home directory.Since Linux kernel version 5.3, block devices are detected in a non-deterministic (almost random) order.
Because of this, GrubZilla identifies system partitions using UUID numbers instead of device names.It is possible that kernel version 6.15.x may restore stable device ordering.
GrubZilla also provides a tool/script called: Remover GRUB
This utility helps quickly remove all CloneZilla-related entries from the 40_custom file without uninstalling the program.

Restoring a System
During system restoration, the latest backup image stored on the USB drive is selected automatically. If you want to restore a different backup version, choose: Clonezilla - Standard TUI from the GRUB menu and manually select another image in CloneZilla.

Backup Selection Feature
To simplify backup management, GrubZilla includes the menu option: Backup Selection
This allows you to manually select a specific backup image.After confirmation and GRUB update, the selected backup will appear as an additional GRUB menu entry. :

<img width="350" height="250" alt="image" src="https://github.com/user-attachments/assets/5a375c6e-e2ec-4da9-8238-2966d11297d9" />

Using Multiple USB Backup Drives
GrubZilla also supports easy usage of multiple USB HDD/SSD backup drives.

**How It Works**

If one USB drive becomes full and you do not want to delete older backups:
    1. use another USB drive,
    2. repeat all steps from this tutorial,
    3. first remove the old GRUB configuration using: Remover Grub
Then use the menu option: Verifier USB. The script checks whether the connected USB drive matches the UUID configuration stored in 40_custom. If everything matches → no action is taken. If not → the script offers to update the GRUB configuration automatically.
An option has also been added to detect Windows, provided it is not additionally encrypted with BitLocker, and to add a backup and restore option for this system to the GRUB menu.

Script Permissions
If you run scripts manually in the terminal, make sure they have executable permissions:
sudo chmod +x /path_to_script/aktualizator_GRUB.sh

​                                                                                        **FINAL WARNING**

**To correctly create or restore a backup image using CloneZilla from the GRUB menu: The USB drive must be connected BEFORE the GRUB menu appears during computer startup.**





