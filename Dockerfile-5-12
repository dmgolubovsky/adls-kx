# This Dockerfile builds an image with Ardour and some other goodies installed.
# Jack is omitted on purpose: ALSA gives better latency when playing on a MIDI keyboard
# and feeding MIDI to synth plugins.


# Pull the base image and install the dependencies per the source package;
# this is a good approximation of what is needed.

from ubuntu:18.04 as base-ubuntu

run cp /etc/apt/sources.list /etc/apt/sources.list~
run sed -Ei 's/^# deb-src /deb-src /' /etc/apt/sources.list
run apt -y update
run apt install -y --no-install-recommends software-properties-common apt-utils
run add-apt-repository ppa:apt-fast/stable
run apt -y update
run env DEBIAN_FRONTEND=noninteractive apt-get -y install apt-fast
run echo debconf apt-fast/maxdownloads string 16 | debconf-set-selections
run echo debconf apt-fast/dlflag boolean true | debconf-set-selections
run echo debconf apt-fast/aptmanager string apt-get | debconf-set-selections

run echo "MIRRORS=( 'http://archive.ubuntu.com/ubuntu, http://de.archive.ubuntu.com/ubuntu, http://ftp.halifax.rwth-aachen.de/ubuntu, http://ftp.uni-kl.de/pub/linux/ubuntu, http://mirror.informatik.uni-mannheim.de/pub/linux/distributions/ubuntu/' )" >> /etc/apt-fast.conf

run apt-fast -y update && apt-fast -y upgrade

# Based on the dependencies, butld Ardour proper. In the end create a tar binary bundle.

from base-ubuntu as ardour

run apt-fast install -y libboost-dev libasound2-dev libglibmm-2.4-dev libsndfile1-dev
run apt-fast install -y libcurl4-gnutls-dev libarchive-dev liblo-dev libtag-extras-dev
run apt-fast install -y vamp-plugin-sdk librubberband-dev libudev-dev libnfft3-dev
run apt-fast install -y libaubio-dev libxml2-dev libusb-1.0-0-dev
run apt-fast install -y libpangomm-1.4-dev liblrdf0-dev libsamplerate0-dev
run apt-fast install -y libserd-dev libsord-dev libsratom-dev liblilv-dev
run apt-fast install -y libgtkmm-2.4-dev libsuil-dev

run apt-fast install -y wget curl

run mkdir /build-ardour
workdir /build-ardour
run wget http://archive.ubuntu.com/ubuntu/pool/universe/a/ardour/ardour_5.12.0-3.dsc
run wget http://archive.ubuntu.com/ubuntu/pool/universe/a/ardour/ardour_5.12.0.orig.tar.bz2
run wget http://archive.ubuntu.com/ubuntu/pool/universe/a/ardour/ardour_5.12.0-3.debian.tar.xz

run dpkg-source -x ardour_5.12.0-3.dsc

workdir /tmp
run curl https://waf.io/waf-1.6.11.tar.bz2 | tar xj
workdir waf-1.6.11

run patch -p1 < /build-ardour/ardour-5.12.0/tools/waflib.patch
run ./waf-light -v --make-waf --tools=misc,doxygen,/build-ardour/ardour-5.12.0/tools/autowaf.py --prelude=''
run cp ./waf /build-ardour/ardour-5.12.0/waf

workdir /build-ardour/ardour-5.12.0
run ./waf configure --no-phone-home --with-backend=alsa
run ./waf build -j4
run ./waf install
run apt-fast install -y chrpath rsync unzip
run ln -sf /bin/false /usr/bin/curl
workdir tools/linux_packaging
run ./build --public --strip some
run ./package --public --singlearch


# Final assembly. Pull all parts together.

from base-ubuntu as adls

# No recommended and/or suggested packages here

run echo "APT::Get::Install-Recommends \"false\";" >> /etc/apt/apt.conf
run echo "APT::Get::Install-Suggests \"false\";" >> /etc/apt/apt.conf
run echo "APT::Install-Recommends \"false\";" >> /etc/apt/apt.conf
run echo "APT::Install-Suggests \"false\";" >> /etc/apt/apt.conf

# Install Ardour from the previously created bundle.

run mkdir -p /install-ardour
workdir /install-ardour
copy --from=ardour /build-ardour/ardour-5.12.0/tools/linux_packaging/Ardour-5.12.0-dbg-x86_64.tar .
run tar xvf Ardour-5.12.0-dbg-x86_64.tar
workdir Ardour-5.12.0-dbg-x86_64

# Install some libs that were not picked by bundlers - mainly X11 related.

run apt -y install gtk2-engines-pixbuf libxfixes3 libxinerama1 libxi6 libxrandr2 libxcursor1 libsuil-0-0
run apt -y install libxcomposite1 libxdamage1 liblzo2-2 libkeyutils1 libasound2 libgl1 libusb-1.0-0

# First time it will fail because one library was not copied properly.

run ./.stage2.run || true

# Copy the missing libraries

run cp /usr/lib/x86_64-linux-gnu/gtk-2.0/2.10.0/engines/libpixmap.so Ardour_x86_64-5.12.0-dbg/lib
run cp /usr/lib/x86_64-linux-gnu/suil-0/libsuil_x11_in_gtk2.so Ardour_x86_64-5.12.0-dbg/lib
run cp /usr/lib/x86_64-linux-gnu/suil-0/libsuil_qt5_in_gtk2.so Ardour_x86_64-5.12.0-dbg/lib

# It will ask questions, say no.

run echo -ne "n\nn\nn\nn\nn\n" | ./.stage2.run

# Delete the unpacked bundle

run rm -rf /install-ardour

# Install kx-studio packages

workdir /install-kx

# Install required dependencies if needed
run apt-fast -y install apt-transport-https gpgv wget

# Download package file
run wget https://launchpad.net/~kxstudio-debian/+archive/kxstudio/+files/kxstudio-repos_10.0.3_all.deb

# Install it
run dpkg -i kxstudio-repos_10.0.3_all.deb

run apt-fast -y update

run apt-fast -y install kxstudio-meta-all kxstudio-meta-audio-applications \
                        kxstudio-meta-audio-plugins kxstudio-meta-audio-plugins-collection

run rm -rf /install-kx

# Finally clean up

run apt-fast clean
run apt-get clean autoclean
run apt-get autoremove -y
run rm -rf /var/lib/apt
run rm -rf /var/lib/dpkg
run rm -rf /var/lib/cache
run rm -rf /var/lib/log
run rm -rf /tmp/*
copy .qmidiarprc /root

from scratch

copy --from=adls / /

