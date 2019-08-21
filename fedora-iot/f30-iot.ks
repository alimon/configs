#version=DEVEL
ignoredisk --only-use=sda
autopart --type=lvm

# Partition clearing information
clearpart --all --initlabel --drives=sda
# OSTree setup
ostreesetup --osname="fedora-iot" --remote="fedora-iot" --url="file:///ostree/repo" --ref="fedora/stable/aarch64/iot" --nogpg
# Use network installation
url --url="https://kojipkgs.fedoraproject.org/compose/iot/Fedora-IoT-30-20190730.0/compose/IoT/aarch64/os/"
# Use graphical install
text
# Keyboard layouts
keyboard --vckeymap=us --xlayouts='us'
# System language
lang en_CA.UTF-8

# Root password
rootpw fedora

# Run the Setup Agent on first boot
# firstboot --enable
# Do not configure the X Window System
skipx
# System services
services --enabled="chronyd"
# System timezone
timezone America/Rainy_River --isUtc
user --groups=wheel --name=tester --password=fedora --plaintext

%post --erroronfail

rm -f /etc/ostree/remotes.d/fedora-iot.conf
ostree remote add --set=gpg-verify=true --set=gpgkeypath=/etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-iot-2019 fedora-iot 'https://dl.fedoraproject.org/iot/repo/'
cp /etc/skel/.bash* /root
%end

%addon com_redhat_kdump --disable --reserve-mb='128'

%end

%anaconda
pwpolicy root --minlen=6 --minquality=1 --notstrict --nochanges --notempty
pwpolicy user --minlen=6 --minquality=1 --notstrict --nochanges --emptyok
pwpolicy luks --minlen=6 --minquality=1 --notstrict --nochanges --notempty
%end
