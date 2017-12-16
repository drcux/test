#!/bin/bash

# buildroot
buildroot="/home/pbuild/buildroot"

# break
trap "cleanupandexit" 0 1 2 3 15

cleanupandexit()
{
    # save exit code
    rc=$?

    echo -e $message

    # umount /dev & /proc
    if [[ -n "${buildroot}" ]]
        then
            while [ -e "${buildroot}/proc/uptime" ]
                do umount "${buildroot}/proc"
                done
            while [ -e "${buildroot}/dev/urandom" ]
                do umount "${buildroot}/dev"
                done
    fi

    echo -e "# STOP:\t\t\t $(date)"

    exit $rc
}

# start
echo -e "# START:\t\t $(date)"

# check if we're running as UID 0
if [ $UID -ne 0 ]
    then
        message="# ERROR:\t\t Not running as UID=0!"
        exit 1
fi

# read pkgbuild
if [ -e PKGBUILD ]
    then
        . PKGBUILD
        echo -e "# Package:\t\t" $pkgname
    else
        message="# ERROR:\t\t No PKGBUILD in `pwd`!"
        exit 1
fi

# delete/create buildroot
echo -e "# Create buildroot:\t" "${buildroot}"

if [ -d "${buildroot}" ]
    then
        rm -rf "${buildroot}"
fi

# create /dev & /proc
mkdir -p "${buildroot}/dev"
mkdir "${buildroot}/proc"

# mount /dev & /proc
mount --bind /dev "${buildroot}/dev"
mount --bind /proc "${buildroot}/proc"

# install buildroot
mkdir -p "${buildroot}/var/lib/pacman"
pacman -r "${buildroot}" -Sy
pacman -r "${buildroot}" --noconfirm --noscriptlet --noprogressbar -S base-devel ${makedepends[@]} ${depends[@]}

# create build user
echo 'build::1000:1000:build:/home/build:/bin/bash' >> "${buildroot}/etc/passwd"
echo 'build::1000:' >>"${buildroot}/etc/group"
mkdir -p "${buildroot}/home/build"
chown -R 1000:1000 "${buildroot}/home/build"

# copy resolv.conf
cp /etc/resolv.conf "${buildroot}/etc"

# copy pkg-files to buildroot
cp -R ./. "${buildroot}/home/build/"

# build package
chroot "${buildroot}" su -l build -c "cd /home/build; makepkg"

# build error?
if [ $? -ne 0 ]
    then
        message="# ERROR:\t\t Build failed!"
        exit 1
fi

# copy built package to $PWD
find "${buildroot}/home/build" -name "*.pkg.*" -exec cp {} . \;

# done
message="# SUCCESS:\t\t Buildjob done!"

exit 0
