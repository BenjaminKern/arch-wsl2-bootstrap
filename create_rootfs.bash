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

mkdir -p ${DESTDIR}
pacstrap -c -G -M ${DESTDIR} base
pacstrap -c -G -M -U ${DESTDIR} subsystemctl/subsystemctl-0.2.0-1-x86_64.pkg.tar.zst
sed -i -e "s/#en_US.UTF-8/en_US.UTF-8/" ${DESTDIR}/etc/locale.gen
sed -i -e "/hosteurope/s/^#//g" ${DESTDIR}/etc/pacman.d/mirrorlist
echo "LANG=en_US.UTF-8" > ${DESTDIR}/etc/locale.conf
echo "KEYMAP=de-latin1" > ${DESTDIR}/etc/vconsole.conf
arch-chroot ${DESTDIR} locale-gen
pacstrap -c -G -M ${DESTDIR} docker sudo git
arch-chroot ${DESTDIR} pacman-key --init
arch-chroot ${DESTDIR} pacman-key --populate archlinux
arch-chroot ${DESTDIR} groupadd --gid ${GROUP_ID} ${USERNAME}
arch-chroot ${DESTDIR} useradd -c "" --no-log-init -u ${USER_ID} -g ${GROUP_ID} -m -G docker ${USERNAME}
arch-chroot ${DESTDIR} systemctl enable docker.service
arch-chroot ${DESTDIR} passwd ${USERNAME}
arch-chroot ${DESTDIR} passwd -l root
echo "${USERNAME} ALL=(ALL) ALL" > ${DESTDIR}/etc/sudoers.d/${USERNAME}
echo 'Defaults env_keep += "ftp_proxy http_proxy https_proxy no_proxy"' >> ${DESTDIR}/etc/sudoers
pushd ${DESTDIR} > /dev/null
tar -zcpf ../rootfs.tar.gz *
popd > /dev/null
echo "RUN via: wsl -d DISTRONAME -u root -- subsystemctl shell --start --uid=${USER_ID}"
