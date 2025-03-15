#!/bin/bash

# Configuration
VM_NAME="network-server"
VM_IMAGE="/var/lib/libvirt/images/${VM_NAME}.qcow2"
ISO_PATH="/var/lib/libvirt/images/ubuntu-24.04.2.iso"
BRIDGE_NAME="br0"
VM_USER="romanmlm"
VM_PASSWORD="admin"
VM_RAM="4096"
VM_CPU="2"
VM_DISK_SIZE="25"
#NFS_SHARE="/srv/nfs"
#NFS_MOUNT_POINT="/mnt/share"

# Automatically detect the current user's SSH key
SSH_KEY_NAME="${VM_NAME}"
SSH_KEY_FILE="/home/${VM_USER}/.ssh/${SSH_KEY_NAME}"
SSH_PUBLIC_KEY_FILE="${SSH_KEY_FILE}.pub"

# Check if the VM already exists
if virsh list --all | grep -q "${VM_NAME}"; then
    echo "VM ${VM_NAME} already exists. Destroying it first."
    virsh destroy "${VM_NAME}" 2>/dev/null
    virsh undefine "${VM_NAME}" --remove-all-storage
    rm -f "${VM_IMAGE}"
    echo delete SSH key pair "${SSH_KEY_FILE}" and "${SSH_PUBLIC_KEY_FILE}"
    rm -f "${SSH_KEY_FILE}" "${SSH_PUBLIC_KEY_FILE}"
fi

# Ensure the SSH key exists
if [ ! -f "${SSH_PUBLIC_KEY_FILE}" ]; then
    echo "No SSH key found. Generating one now..."
    ssh-keygen -t ed25519 -C "${VM_USER}@${VM_NAME}.com" -f ${SSH_KEY_FILE}
    cat "${SSH_PUBLIC_KEY_FILE}"
fi

# Create the disk image
#echo "Creating disk image for ${VM_NAME}..."
#qemu-img create -f qcow2 "${VM_IMAGE}" "${VM_DISK_SIZE}"

# Inject cloud-init configuration (user, password, SSH key)
#echo "Injecting cloud-init configuration..."
#
#mkdir -p /tmp/cloud-init
#cat > /tmp/cloud-init/meta-data <<EOF
#instance-id: ${VM_NAME}
#local-hostname: ${VM_NAME}
#EOF
#
#cat > /tmp/cloud-init/user-data <<EOF
##cloud-config
#preserve_hostname: false
#hostname: ${VM_NAME}
#
#users:
#  - name: ${VM_USER}
#    groups: sudo
#    shell: /bin/bash
#    sudo: ['ALL=(ALL) NOPASSWD:ALL']
#    lock_passwd: false
#    passwd: $(echo "${VM_PASSWORD}" | openssl passwd -6 -stdin)
#    ssh_authorized_keys:
#      - $(cat "${SSH_PUBLIC_KEY_FILE}")
#
#disable_root: false
##ssh_pwauth: false
#
##packages:
##  - nfs-common
#
#runcmd:
#  - ufw allow from 192.168.1.0/24 to any port 22 proto tcp
#  - ufw enable
##  - mkdir -p ${NFS_MOUNT_POINT}
##  - echo "${HOST_IP}:${NFS_SHARE} ${NFS_MOUNT_POINT} nfs defaults,_netdev 0 0" >> /etc/fstab
##  - mount -a
#EOF

#cloud-localds /var/lib/libvirt/images/${VM_NAME}-seed.iso /tmp/cloud-init/user-data /tmp/cloud-init/meta-data

# Install the VM
echo "Installing the VM..."
virt-install \
    --name "${VM_NAME}" \
    --ram "${VM_RAM}" \
    --vcpus "${VM_CPU}" \
    --disk path="${VM_IMAGE}",format=qcow2,size=${VM_DISK_SIZE} \
    --location "${ISO_PATH}" \
    --graphics none \
    --console pty,target_type=serial \
    --network bridge=${BRIDGE_NAME},model=virtio \
    --noautoconsole \
    --extra-args console=ttyS0 -v #\
#    --cloud-init user-data=/tmp/cloud-init/user-data,meta-data=/tmp/cloud-init/meta-data \
#    --os-variant ubuntu24.04

# Wait for the VM to start the installer
echo "Waiting for VM to be created..."
sleep 10

# Attach cloud-init image to the VM
#virsh detach-disk ${VM_NAME} --target vdb --persistent || true
#virsh attach-disk "${VM_NAME}" /var/lib/libvirt/images/${VM_NAME}-seed.iso --target vdb --persistent

#virsh attach-interface \
#  --domain $VM_NAME \
#  --type bridge \
#  --source br0 \
#  --model virtio \
#  --config \
#  --live \
#  --persistent

# Reboot the VM
echo "Rebooting the VM..."
virsh reboot "${VM_NAME}"
virsh autostart "${VM_NAME}"

#Clean up
#rm -rf /tmp/cloud-init
echo "Waiting for IP address..."
virsh domifaddr "${VM_NAME}" | grep ipv4 | awk '{print $4}'

# DETACH THE CLOUD-INIT DISK AFTER FIRST BOOT
#echo "Detaching cloud-init disk..."
#virsh detach-disk "${VM_NAME}" vdb --persistent

# DELETE THE SEED IMAGE
#echo "Deleting cloud-init disk..."
#rm -f "${CLOUD_INIT_IMAGE}"

echo "✅ VM installation complete."
echo "IP address should be available via DHCP on the bridge."
echo "SSH access: ssh ${VM_USER}@<IP_ADDRESS>"
