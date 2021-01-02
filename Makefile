SHELL := /bin/bash
LFS := /mnt/lfs
LFS_DISK := disk.img
LFS_DISK_LOOPDEV = $(shell losetup --associated $(LFS_DISK) | cut -f1 -d:)
LFS_DISK_MAPDEV = /dev/mapper/$(patsubst /dev/%,%,$(LFS_DISK_LOOPDEV))

$(LFS_DISK):
	dd if=/dev/zero of=$@ count=62914560
	parted --script $@ \
		unit s \
		mklabel gpt \
		mkpart fat32 2048s 1050623s \
		mkpart ext4 1050624s 42993663s \
		mkpart ext4 42993664s 58720255s \
		mkpart linux-swap\(v1\) 58720256s 62914526s \
		set 1 boot on \
		set 4 swap on \
		print

wget-list:
	wget http://www.linuxfromscratch.org/lfs/downloads/10.0-systemd/$@

md5sums:
	wget http://www.linuxfromscratch.org/lfs/downloads/10.0-systemd/$@
	cp $@ $(LFS)/sources


.PHONY: version-check attach-loopdev detach-loopdev make-filesystem mount umount check-swap

version-check:
	./version-check.sh

attach-loopdev: $(LFS_DISK)
	kpartx -v -a $(LFS_DISK)

detach-loopdev:
	kpartx -v -d $(LFS_DISK)

make-filesystem: attach-loopdev
	mkfs.vfat -v -F32 $(LFS_DISK_MAPDEV)p1
	mkfs -v -text4 $(LFS_DISK_MAPDEV)p2
	mkfs -v -text4 $(LFS_DISK_MAPDEV)p3
	mkswap -v1 $(LFS_DISK_MAPDEV)p4

mount: attach-loopdev
	mkdir -pv $(LFS)
	mount -v -text4 $(LFS_DISK_MAPDEV)p2 $(LFS)
	mkdir -pv $(LFS)/boot
	mkdir -pv $(LFS)/home
	mount -v -tvfat $(LFS_DISK_MAPDEV)p1 $(LFS)/boot
	mount -v -text4 $(LFS_DISK_MAPDEV)p3 $(LFS)/home
	mount | grep $(LFS_DISK_MAPDEV)

umount:
	umount -v $(LFS)/home
	umount -v $(LFS)/boot
	umount -v $(LFS)

check-swap:
	-swapon -v $(LFS_DISK_MAPDEV)p4
	-swapoff -v $(LFS_DISK_MAPDEV)p4

prepare-download:
	mkdir -pv $(LFS)/sources
	chmod -v a+wt $(LFS)/sources

download: wget-list md5sums
	wget --input-file=wget-list --continue --directory-prefix=$(LFS)/sources
	pushd $(LFS)/sources; \
	md5sum -c md5sums; \
	popd
