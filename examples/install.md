
# Installation on a Raspberry Pi 4 (2 GB)

Set time zone

```
sudo dpkg-reconfigure tzdata
```


```bash
sudo apt update
sudo apt install git python3-distutils python3-matplotlib libnetcdf-dev netcdf-bin sox
sudo apt install libusb-1.0-0-dev
```

## Julia

I had some issues with julia (version 1.0.3) on Rasbian.

```bash
wget https://julialang-s3.julialang.org/bin/linux/armv7l/1.2/julia-1.2.0-linux-armv7l.tar.gz
tar xf julia-1.2.0-linux-armv7l.tar.gz
sudo mv julia-1.2.0 /opt/
rm julia-1.2.0-linux-armv7l.tar.gz
sudo ln -s /opt/julia-1.2.0/bin/julia /usr/local/bin/julia
julia --eval 'using Pkg; pkg"dev https://github.com/Alexander-Barth/APTDecoder.jl"'
dev SatelliteToolbox
add JSON
add ImageMagick
add Twitter
```


## RTL-SDR

`rtl_fm` with support WAV output format

```bash
git clone https://github.com/keenerd/rtl-sdr keenerd-rtl-sdr
cd keenerd-rtl-sdr
mkdir build
cd build
cmake ../ -DINSTALL_UDEV_RULES=ON
make
sudo make install
sudo ldconfig
```

Check udev rules:

```bash
cat /etc/udev/rules.d/rtl-sdr.rules
```

It is necessary to either restart `udev` or the whole system:

```bash
sudo service udev restart
```


# Add systemd service

sudo cp APTDecoder.service /etc/systemd/system/
sudo systemctl start APTDecoder.service
