# cli clients download
rm -rf trojan-client/
mkdir trojan-client
cli_linux_download_address=https://github.com/trojan-gfw/trojan/releases/download/v1.14.1/trojan-1.14.1-linux-amd64.tar.xz
cli_mac_download_address=https://github.com/trojan-gfw/trojan/releases/download/v1.14.1/trojan-1.14.1-macos.zip
cli_win_download_address=https://github.com/trojan-gfw/trojan/releases/download/v1.14.1/trojan-1.14.1-win.zip
wget $cli_linux_download_address -O linux.tar.xz
wget $cli_mac_download_address -O mac.zip
wget $cli_win_download_address -O windows.zip
tar xf linux.tar.xz -C trojan-client
mkdir -p trojan-client/linux/cli
mv -f trojan-client/trojan/* trojan-client/linux/cli
unzip mac.zip -d trojan-client
mkdir -p trojan-client/mac/cli
mv -f trojan-client/trojan/* trojan-client/mac/cli
unzip windows.zip -d trojan-client
mkdir -p trojan-client/windows/cli
mv -f trojan-client/trojan/* trojan-client/windows/cli
rm linux.tar.xz
rm mac.zip
rm windows.zip

# gui clients download
cli_linux_download_address=https://github.com/TheWanderingCoel/Trojan-Qt5/releases/download/v0.0.4a/Trojan-Qt5-Linux.AppImage
cli_mac_download_address=https://github.com/TheWanderingCoel/Trojan-Qt5/releases/download/v0.0.4a/Trojan-Qt5-macOS.dmg
cli_win_download_address=https://github.com/TheWanderingCoel/Trojan-Qt5/releases/download/v0.0.4a/Trojan-Qt5-Windows.zip
wget $cli_linux_download_address -P trojan-client/linux/gui/
wget $cli_mac_download_address -P trojan-client/mac/gui/
wget $cli_win_download_address -O windowsgui.zip
unzip windowsgui.zip -d trojan-client/trojan
mkdir -p trojan-client/windows/gui
mv -f trojan-client/trojan/* trojan-client/windows/gui
rm windowsgui.zip

# clean up
rm trojan-client/trojan -r
zip trojan-client.zip -r trojan-client/
rm -rf trojan-client/

rm -rf dist
mkdir dist
mv trojan-client.zip dist/trojan-client.zip

cd web
zip -r web.zip .
cd ..
mv web/web.zip dist/web.zip

# tun2socks-linux-amd64 -tunAddr 10.0.0.2 -tunGw 10.0.0.1 -proxyType socks -proxyServer 192.168.1.174:1080
# https://github.com/TheWanderingCoel/Trojan-Qt5/releases/download/v0.0.4a/Trojan-Qt5-Linux.AppImage