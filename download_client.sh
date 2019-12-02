rm -rf trojan-client/
mkdir trojan-client
linux_download_address=https://github.com/trojan-gfw/trojan/releases/download/v1.13.0/trojan-1.13.0-linux-amd64.tar.xz
mac_download_address=https://github.com/trojan-gfw/trojan/releases/download/v1.13.0/trojan-1.13.0-macos.zip
win_download_address=https://github.com/trojan-gfw/trojan/releases/download/v1.13.0/trojan-1.13.0-windows.zip

wget $linux_download_address -O linux.tar.xz
wget $mac_download_address -O mac.zip
wget $win_download_address -O windows.zip
tar xf linux.tar.xz -C trojan-client
mv -f trojan-client/trojan trojan-client/linux
unzip mac.zip -d trojan-client
mv -f trojan-client/trojan trojan-client/mac
unzip windows.zip -d trojan-client
mv -f trojan-client/trojan trojan-client/windows
rm linux.tar.xz
rm mac.zip
rm windows.zip

zip trojan-client.zip -r trojan-client/
rm -rf trojan-client/