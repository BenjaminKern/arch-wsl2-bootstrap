#!/usr/bin/env bash
set -euo pipefail

USERNAME=""
USER_ID="1000"
GROUP_ID="1000"

for i in "$@"; do
  case $i in
    --username=*)
      USERNAME="${i#*=}"
      shift
      ;;
    --user-id=*)
      USER_ID="${i#*=}"
      shift
      ;;
    --group-id=*)
      GROUP_ID="${i#*=}"
      shift
      ;;
    *)
      echo "Unknown parameter passed: $1"
      exit 1
      ;;
  esac
done

if [ -z "$USERNAME" ]; then
  echo "Please provide a valid username via --username="
  exit 1
fi

if [[ ${EUID} -ne 0 ]]; then
    echo "$0 is not running as root."
    exit 1
fi

DESTDIR=rootfs
BOOTSTRAP_VERSION=2021.12.01
ARCH_CHROOT_BIN=/tmp/root.x86_64/bin/arch-chroot
ARCH_PACSTRAP_BIN=/tmp/root.x86_64/bin/pacstrap

curl -sL http://mirror.rackspace.com/archlinux/iso/latest/archlinux-bootstrap-${BOOTSTRAP_VERSION}-x86_64.tar.gz | tar xfz - --numeric-owner -C /tmp/

mkdir -p ${DESTDIR}
${ARCH_PACSTRAP_BIN} -c -G -M ${DESTDIR} base
${ARCH_PACSTRAP_BIN} -c -G -M -U ${DESTDIR} subsystemctl/subsystemctl-0.2.0-1-x86_64.pkg.tar.zst
sed -i -e "s/#en_US.UTF-8/en_US.UTF-8/" ${DESTDIR}/etc/locale.gen
sed -i -e "/hosteurope/s/^#//g" ${DESTDIR}/etc/pacman.d/mirrorlist
echo "LANG=en_US.UTF-8" > ${DESTDIR}/etc/locale.conf
echo "KEYMAP=de-latin1" > ${DESTDIR}/etc/vconsole.conf
${ARCH_CHROOT_BIN} ${DESTDIR} locale-gen
${ARCH_PACSTRAP_BIN} -c -G -M ${DESTDIR} docker sudo git
${ARCH_CHROOT_BIN} ${DESTDIR} pacman-key --init
${ARCH_CHROOT_BIN} ${DESTDIR} pacman-key --populate archlinux
${ARCH_CHROOT_BIN} ${DESTDIR} groupadd --gid ${GROUP_ID} ${USERNAME}
${ARCH_CHROOT_BIN} ${DESTDIR} useradd -c "" --no-log-init -u ${USER_ID} -g ${GROUP_ID} -m -G docker ${USERNAME}
${ARCH_CHROOT_BIN} ${DESTDIR} systemctl enable docker.service
${ARCH_CHROOT_BIN} ${DESTDIR} passwd ${USERNAME}
${ARCH_CHROOT_BIN} ${DESTDIR} passwd -l root
echo "${USERNAME} ALL=(ALL) ALL" > ${DESTDIR}/etc/sudoers.d/${USERNAME}
echo 'Defaults env_keep += "ftp_proxy http_proxy https_proxy no_proxy"' >> ${DESTDIR}/etc/sudoers
pushd ${DESTDIR} > /dev/null
tar -zcpf ../rootfs.tar.gz *
popd > /dev/null
echo "RUN via: wsl -d DISTRONAME -u root -- subsystemctl shell --start --uid=${USER_ID}"
