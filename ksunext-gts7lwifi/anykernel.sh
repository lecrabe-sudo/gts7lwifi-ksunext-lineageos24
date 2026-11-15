### AnyKernel3 Ramdisk Mod Script
## osm0sis @ xda-developers
## Adapted for Samsung Galaxy Tab S7 Wi-Fi (gts7lwifi / SM-T870)
## Based on itzreesa/kernel-builder (XDA thread 4792755)

### AnyKernel setup
# global properties
properties() { '
kernel.string=LineageOS 24.0 + KernelSU-Next for SM-T870 (gts7lwifi)
do.devicecheck=1
do.modules=0
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=gts7lwifi
device.name2=
device.name3=
device.name4=
device.name5=
supported.versions=
supported.patchlevels=
supported.vendorpatchlevels=
'; } # end properties


### AnyKernel install
## boot files attributes
boot_attributes() {
set_perm_recursive 0 0 755 644 $RAMDISK/*;
set_perm_recursive 0 0 750 750 $RAMDISK/init* $RAMDISK/sbin;
} # end attributes

# boot shell variables
BLOCK=/dev/block/by-name/boot;
IS_SLOT_DEVICE=0;
RAMDISK_COMPRESSION=auto;
PATCH_VBMETA_FLAG=auto;

# import functions/variables and setup patching - see for reference (DO NOT REMOVE)
. tools/ak3-core.sh;

# boot install
dump_boot;

write_boot;
## end boot install
