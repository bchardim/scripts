dnf remove -y firefox
curl https://download-installer.cdn.mozilla.net/pub/firefox/releases/133.0.3/linux-x86_64/en-US/firefox-133.0.3.tar.bz2 -o firefox-133.0.3.tar.bz2
tar xjf firefox-133.0.3.tar.bz2 
mv firefox /opt
ln -s /opt/firefox/firefox /usr/local/bin/firefox
rm -rf firefox-133.0.3.tar.bz2
#wget https://raw.githubusercontent.com/mozilla/sumo-kb/main/install-firefox-linux/firefox.desktop -P /usr/local/share/applications
