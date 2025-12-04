#! /usr/bin/bash

set -e

CURDIR=$(pwd)

if [[ -z $PKG_NAME ]]; then
	PKG_NAME=non-btf
fi

if [[ -z $VERSION ]]; then
	VERSION=$(curl -sL https://api.github.com/repos/kubearmor/kubearmor/releases/latest | jq -r '.tag_name')
fi

# change the SSH key
if [[ -z $SSH_KEY ]]; then
	echo "$\SSH_KEY cannot be empty"
	exit 1
fi

echo "Compiling version $VERSION"

# compile system monitor on profiling-vm (Linux 5.4.0-42-generic)
SSH_COMMAND="sudo docker run --rm --name=kubearmor-init --privileged -v '/tmp:/opt/kubearmor/BPF:rw' -v '/lib/modules:/lib/modules:ro' -v '/sys/kernel/security:/sys/kernel/security:ro' -v '/sys/kernel/debug:/sys/kernel/debug:ro' -v '/media/root/etc/os-release:/media/root/etc/os-release:ro' -v '/usr/src:/usr/src' kubearmor/kubearmor-init:${VERSION}; echo MD5SUM; md5sum /tmp/system_monitor.bpf.o"

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i $SSH_KEY ziggy@159.89.175.183 -C $SSH_COMMAND

scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i $SSH_KEY 159.89.175.183:/home/ziggy/test/KubeArmor/KubeArmor/BPF/system_monitor.bpf.o  /tmp/system_monitor.bpf.o

echo "MD5SUM of COPIED SYSTEM MONITOR"
md5sum /tmp/system_monitor.bpf.o

if [[ $VERSION == "latest" ]]; then
	VERSION=$(curl -sL https://api.github.com/repos/kubearmor/kubearmor/releases/latest | jq -r '.tag_name')
fi

UNTAGGED_VERSION=${VERSION#v}
KA_TAR="kubearmor_${UNTAGGED_VERSION}_linux-amd64.tar.gz"

# download KA tar
curl -sLO https://github.com/kubearmor/KubeArmor/releases/download/${VERSION}/${KA_TAR}

tar xvzf ${KA_TAR}
rm -rf ${KA_TAR}
cp /tmp/system_monitor.bpf.o opt/kubearmor/BPF/system_monitor.bpf.o
tar czf ${KA_TAR} opt/ usr/
oras push --artifact-type=application/x-tar docker.io/kubearmor/kubearmor-systemd-${PKG_NAME}:${UNTAGGED_VERSION}_linux-amd64 ${KA_TAR}

echo "COMPLETE!"
