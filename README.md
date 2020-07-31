## HiSilicon password restorer for flash dumps
This script allows to "restore" the blank password for the admin/user accounts of a HiSilicon DVR using the XM "chipset". This needs a full dump of the SPI memory, and a bit of luck.

### Pre-requisites
* Any relative "new" Linux distro with `binwalk`, `jefferson`, `jq` and `mtd-utils`. Jefferson needs to be installed from [its repository](https://github.com/sviehb/jefferson).
* A full flash dump of the SPI memory of the DVR. You need to phyiscally desolder the chip itself. Maybe this could be achieved via U-Boot and a serial console. Please share your instructions if you've managed to accomplish this :).
* A mean to program back the new image to the SPI memory (using the same programmer/reader from before or another method involving U-Boot).

### Usage
Simply grab the full dump of the SPI memory and invoke the script as follows:
```bash
# ./magic.sh <path_to_full_dump_file> <path_to_new_image>
# For example:
./magic.sh ~/dumps/dump.bin ~/dumps/new-dump.bin
# Where ~/dumps/dump.bin is the input dump file, and
# ~/dumps/new-dump.bin would be the generated image.
```

### Notes
* If the target DVR has an SPI memory that doesn't use a 64k erase block, please edit the `JFFS2_ERASE_BLOCK` variable on the `magic.sh` script before running it.
* If you want to use a different hash for the accounts, please edit the `NEW_PASSWORD_HASH` variable on the `magic.sh` script before running it.

### Validated Hardware
* AHB7804R-MS-ZS with a MX25L6405D SPI flash chip.

