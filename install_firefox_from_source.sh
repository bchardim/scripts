VER=133.0.3
dnf remove -y firefox
rm -rf /opt/firefox
rm -rf /home/student/.cache/mozilla/firefox
curl https://download-installer.cdn.mozilla.net/pub/firefox/releases/${VER}/linux-x86_64/en-US/firefox-${VER}.tar.bz2 -o firefox-${VER}.tar.bz2
tar xjf firefox-${VER}.tar.bz2 
mv firefox /opt
ln -s /opt/firefox/firefox /usr/local/bin/firefox
sudo -u student sh -c "/usr/local/bin/firefox -CreateProfile student"
rm -rf firefox*
wget https://raw.githubusercontent.com/mozilla/sumo-kb/main/install-firefox-linux/firefox.desktop -P /usr/local/share/applications
sed -i 's/Exec=firefox/Exec=firefox -P student/mg' /usr/local/share/applications/firefox.desktop
echo $?
