# Declarative disk layout for Alcatraz OS (bare-metal)
#
# Used by disko to partition, format, and mount disks during install.
# The device path is a placeholder — override at install time with:
#   disko ... --disk main /dev/sdX
#
# Layout (GPT, UEFI):
#   ESP   – 512 MB, FAT32, mounted at /boot
#   swap  – 8 GB, linux-swap
#   root  – remainder, ext4, mounted at /

{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/disk/by-id/to-be-filled-at-install-time";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            swap = {
              size = "8G";
              content = {
                type = "swap";
              };
            };
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };
    };
  };
}
