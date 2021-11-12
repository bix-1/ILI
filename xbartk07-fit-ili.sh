echo "1) Creating loop devices"
dd if=/dev/zero of=~/disk0 bs=200MiB count=1
for i in {1..3}; do cp disk0 disk$i; done
echo "...created files"
for p in {0..3} ; do losetup "loop$p" "disk$p" && echo "...created loop device" || echo "...failed"; done

echo ""
echo "2) Creating RAIDs on loop devices"
echo y | mdadm --create /dev/md0 --level=mirror --raid-devices=2 /dev/loop0 /dev/loop1 && echo "...created RAID1 on loop0 & loop1" || echo "...failed"
echo y | mdadm --create /dev/md1 --level=stripe --raid-devices=2 /dev/loop2 /dev/loop3 && echo "...created RAID0 on loop2 & loop3" || echo "...failed"

echo ""
echo "3) Creating volume group"
vgcreate FIT_vg /dev/md0 /dev/md1 && echo "...created VG \"FIT_vg\" on RAID devs \"/dev/md0\" & \"/dev/md1\"" || echo "...failed"

echo ""
echo "4) Creating LVs"
lvcreate FIT_vg -n FIT_lv1 --size 100M && echo "...created FIT_lv1 on FIT_vg" || echo "...failed"
lvcreate FIT_vg -n FIT_lv2 --size 100M && echo "...created FIT_lv2 on FIT_vg" || echo "...failed"

echo ""
echo "5) Creating EXT4 fs on FIT_lv1"
mkfs.ext4 /dev/FIT_vg/FIT_lv1 || echo "...failed"
echo ""
echo "6) Creating XFS  fs on FIT_lv2"
mkfs.xfs /dev/FIT_vg/FIT_lv2 || echo "...failed"

echo ""
echo "7) Mounting..."
mkdir /mnt/test1
mkdir /mnt/test2
echo "...FIT_lv1 to \"/mnt/test1\""
mount /dev/FIT_vg/FIT_lv1 /mnt/test1 || echo "...failed"
echo "...FIT_lv2 to \"/mnt/test2\""
mount /dev/FIT_vg/FIT_lv2 /mnt/test2 || echo "...failed"

echo ""
echo "8) Resizing fs on FIT_lv1"
echo "...unmounting"
umount /mnt/test1 || echo "...failed"
echo "...resizing LV"
lvextend -L +388M /dev/FIT_vg/FIT_lv1 || echo "...failed"
echo "...resizing FS"
resize2fs /dev/FIT_vg/FIT_lv1 || echo "...failed"
echo "...re-mounting"
mount /dev/FIT_vg/FIT_lv1 /mnt/test1 || echo "...failed"

echo ""
echo "9) Creating big_file"
dd if=/dev/urandom of=/mnt/test1/big_file bs=300M count=1 || echo "...failed"
echo "...creating checksum"
sha512sum /mnt/test1/big_file || echo "...failed"

echo ""
echo "10) Replacing faulty disk"
echo "...creating new loop device"
dd if=/dev/zero of=~/disk4 bs=200M count=1 || echo "...failed"
losetup "loop4" "disk4" || echo "...failed"
echo "...failing device \"loop2\""
mdadm --manage /dev/md1 --fail /dev/loop2 || echo "...failed"
echo "...removing faulty device"
mdadm --manage /dev/md1 --remove /dev/loop2 || echo "...failed"
echo "...adding replacement device"
mdadm --manage /dev/md1 --add /dev/loop4 || echo "...failed"
mdadm --detail /dev/md1 || echo "...failed"
