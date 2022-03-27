# This Dockerfile builds an image with Ardour and some other goodies installed.


# Pull the base image and install the dependencies per the source package;
# this is a good approximation of what is needed.

from ubuntu:20.04 as base-ubuntu

env ardvers=6.9
env ardsub=0

env msvers=v3.6.2

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

# Build MuseScore

# Build Musescore from git

from base-ubuntu as mscore

run env DEBIAN_FRONTEND=noninteractive apt-fast -y install cmake qtbase5-dev qtwebengine5-dev qttools5-dev \
                        libqt5svg5-dev libqt5xmlpatterns5-dev qtquickcontrols2-5-dev lame libmp3lame-dev \
                        libqt5webenginecore5 qt5-default git qml-module-qtgraphicaleffects qml-module-qtquick-controls 

workdir /bld_mscore

run git clone https://github.com/musescore/MuseScore.git

workdir MuseScore

run git checkout $msvers

run env DEBIAN_FRONTEND=noninteractive apt-fast -y install g++ libasound2-dev libsndfile1-dev \
                        zlib1g-dev portaudio19-dev libportmidi-dev libaudiofile-dev


add musescore-1.diff .

run patch -p1 <musescore-1.diff

workdir my-build-dir


run sed -i 's/QuickTemplates2/\#QuickTemplates2/g' ../build/FindQt5.cmake


run cmake .. -DCMAKE_INSTALL_PREFIX=/install-mscore -DBUILD_PULSEAUDIO=OFF \
             -DBUILD_TELEMETRY_MODULE=OFF -DBUILD_LAME=OFF

run cmake -j4 --build . 

run cmake --build . --target install



# Build Audacity

from base-ubuntu as audacity

run apt -y install build-essential git cmake python3-pip
run pip3 install conan
run apt -y install libgtk2.0-dev libasound2-dev libavformat-dev uuid-dev libjack-jackd2-dev

run git clone https://github.com/audacity/audacity/

workdir audacity

run git checkout Audacity-3.1.3

workdir /

workdir build

run cmake -G "Unix Makefiles" -Daudacity_use_ffmpeg=loaded -DCMAKE_INSTALL_PREFIX=/usr  ../audacity

run make -j 4

run make DESTDIR=/install_audacity install

# Build B-sequencer

from base-ubuntu as bseq

run apt -y install build-essential git
run apt -y install pkg-config libx11-dev libcairo2-dev lv2-dev

run git clone https://github.com/sjaehn/BSEQuencer.git

workdir BSEQuencer

run git checkout 1.8.10

run make
run make install

# Based on the dependencies, butld Ardour proper. In the end create a tar binary bundle.

from base-ubuntu as ardour

run apt-fast install -y libboost-dev libasound2-dev libglibmm-2.4-dev libsndfile1-dev
run apt-fast install -y libcurl4-gnutls-dev libarchive-dev liblo-dev libtag-extras-dev
run apt-fast install -y vamp-plugin-sdk librubberband-dev libudev-dev libnfft3-dev
run apt-fast install -y libaubio-dev libxml2-dev libusb-1.0-0-dev libreadline-dev
run apt-fast install -y libpangomm-1.4-dev liblrdf0-dev libsamplerate0-dev
run apt-fast install -y libserd-dev libsord-dev libsratom-dev liblilv-dev
run apt-fast install -y libgtkmm-2.4-dev libsuil-dev libcwiid-dev python

run apt-fast install -y wget curl git

run mkdir /build-ardour
workdir /build-ardour

run git clone https://github.com/Ardour/ardour.git

workdir ardour

run git checkout $ardvers

workdir /build-ardour/ardour
run ./waf configure --no-phone-home --with-backend=alsa --optimize --ptformat --cxx11 --luadoc
run ./waf build -j 4
run ./waf install
run apt-fast install -y chrpath rsync unzip
run ln -sf /bin/false /usr/bin/curl
workdir tools/linux_packaging
run ./build --public --strip some
run ./package --public --singlearch

# Pull custom LUA scripts

from base-ubuntu as ardlua

run apt-fast install -y git

workdir /

run git clone https://github.com/dmgolubovsky/ardlua.git

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
copy --from=ardour /build-ardour/ardour/tools/linux_packaging/Ardour-$ardvers.$ardsub-x86_64.tar .
run tar xvf Ardour-$ardvers.$ardsub-x86_64.tar
workdir Ardour-$ardvers.$ardsub-x86_64

# Install some libs that were not picked by bundlers - mainly X11 related.

run apt -y install gtk2-engines-pixbuf libxfixes3 libxinerama1 libxi6 libxrandr2 libxcursor1 libsuil-0-0
run apt -y install libxcomposite1 libxdamage1 liblzo2-2 libkeyutils1 libasound2 libgl1 libusb-1.0-0
run apt -y install libglibmm-2.4-1v5 libsamplerate0 libsndfile1 libfftw3-single3 libvamp-sdk2v5 \
                   libvamp-hostsdk3v5
run apt -y install liblo7 libaubio5 liblilv-0-0 libtag1v5-vanilla libpangomm-1.4-1v5 libcairomm-1.0-1v5
run apt -y install libgtkmm-2.4-1v5 libcurl3-gnutls libarchive13 liblrdf0 librubberband2 libcwiid1

# First time it will fail because one library was not copied properly.

# It will ask questions, say no.

run echo -ne "n\nn\nn\nn\nn\nn\nn\nn\n" | env NOABICHECK=1 ./.stage2.run

# Copy the missing libraries

run cp /usr/lib/x86_64-linux-gnu/gtk-2.0/2.10.0/engines/libpixmap.so /opt/Ardour-$ardvers.$ardsub/lib
run cp /usr/lib/x86_64-linux-gnu/suil-0/libsuil_x11_in_gtk2.so /opt/Ardour-$ardvers.$ardsub/lib
run cp /usr/lib/x86_64-linux-gnu/suil-0/libsuil_qt5_in_gtk2.so /opt/Ardour-$ardvers.$ardsub/lib

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

run env DEBIAN_FRONTEND=noninteractive apt-fast -y install kxstudio-meta-all \
                        guitarix-lv2 ir.lv2 lv2vocoder \
                        kxstudio-meta-audio-plugins kxstudio-meta-audio-plugins-collection \
                        vim alsa-utils yad mda-lv2 padthv1-lv2 samplv1-lv2 \
                        so-synth-lv2 swh-lv2 libportmidi0 libqt5xmlpatterns5 libqt5webenginewidgets5 \
                        iem-plugin-suite-vst hydrogen-drumkits hydrogen-data guitarix-common \
                        locales less 
                        

run apt-fast install -y dumb-init

run rm -rf /install-kx

run locale-gen en_US.UTF-8

copy --from=ardlua /ardlua/prod /opt/Ardour-$ardvers.$ardsub/share/scripts

copy --from=bseq /usr/local/lib/lv2 /usr/lib/lv2

copy --from=audacity /install_audacity/usr /usr

copy --from=mscore /install-mscore /usr/local

# Finally clean up

run apt-fast clean
run apt-get clean autoclean
run apt-get autoremove -y
run rm -rf /var/lib/apt
run rm -rf /var/lib/dpkg
run rm -rf /var/lib/cache
run rm -rf /var/lib/log
run rm -rf /var/cache
run rm -rf /tmp/*

from scratch

copy --from=adls / /

