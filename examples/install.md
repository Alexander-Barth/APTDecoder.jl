
Installation on a Raspberry Pi 4 (2 GB)

Set time zone

```
rm /etc/localtime
ln -s /usr/share/zoneinfo/Europe/Brussels /etc/localtime
```



I had some issues with julia on Rasbian

```bash
sudo apt update
sudo apt install git python3-distutils python3-matplotlib rtl-sdr librtlsdr-dev libnetcdf-dev netcdf-bin sox
wget https://julialang-s3.julialang.org/bin/linux/armv7l/1.2/julia-1.2.0-linux-armv7l.tar.gz
tar xf julia-1.2.0-linux-armv7l.tar.gz
sudo mv julia-1.2.0 /opt/
rm julia-1.2.0-linux-armv7l.tar.gz
julia --eval 'using Pkg; pkg"dev "
dev https://github.com/Alexander-Barth/APTDecoder.jl
dev SatelliteToolbox
add JSON
add ImageMagick
add Twitter
```

/etc/udev/rules.d/20.rtlsdr.rules

as root

cat > /etc/udev/rules.d/20.rtlsdr.rules <<EOF
SUBSYSTEM=="usb", ATTRS{idVendor}=="0bda", ATTRS{idProduct}=="2838", GROUP="adm", MODE="0666", SYMLINK+="rtl_sdr"
EOF
sudo service udev restart



sudo apt-get install libusb-1.0-0-dev
git clone git://git.osmocom.org/rtl-sdr.git

cd rtl-sdr/
mkdir build
cd build
cmake ../ -DINSTALL_UDEV_RULES=ON
make
sudo make install
sudo ldconfig


# rtl_fm supports WAV output format

git clone https://github.com/keenerd/rtl-sdr keenerd-rtl-sdr
cd keenerd-rtl-sdr
mkdir build
cd build
cmake ../ -DINSTALL_UDEV_RULES=ON
make
sudo make install
sudo ldconfig
