How to Expand the Root Filesystem in LVM

Since your VM uses LVM (Logical Volume Manager), follow these steps:
1️⃣ Check Available Space on the Disk

Run:

lsblk

Look for vda or vdb to see if the full allocated space is available but unassigned.
2️⃣ Resize the Physical Volume (PV)

If lsblk shows free space, extend the LVM physical volume:

sudo pvresize /dev/vda3  # Use correct partition

3️⃣ Extend the Logical Volume (LV)

Find the logical volume name:

lvdisplay

Then extend it:

sudo lvextend -l +100%FREE /dev/mapper/ubuntu--vg-ubuntu--lv

This will use all available space.
4️⃣ Resize the Filesystem

Finally, grow the filesystem:

sudo resize2fs /dev/mapper/ubuntu--vg-ubuntu--lv

5️⃣ Verify the Changes

Check df -h again:

df -h
