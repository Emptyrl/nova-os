#!/usr/bin/env bash
# Construit l'image de Nova OS (nova-os.iso) avec live-build, sur une base Debian 13 (trixie).
# Au démarrage de l'image : menu « Nova OS », animation du logo TT, puis Nova en plein écran.
# Pas de bureau visible ; le bureau Xfce reste caché derrière le menu Nova OS pour la maintenance.
#
# Lancé automatiquement par GitHub (voir .github/workflows/construire.yml), ou à la main sur un Debian 13 :
#   sudo bash construire-nova-os.sh
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="${WORK:-/tmp/nova-os-build}"
OUT="${OUT:-$HERE/nova-os.iso}"
[ "$(id -u)" = "0" ] || { echo "À lancer en administrateur (sudo)."; exit 1; }
# tout est noté dans construction.log, dès la première ligne
exec > >(tee "$HERE/construction.log") 2>&1
trap 'echo "ÉCHEC à la ligne $LINENO : $BASH_COMMAND"' ERR

echo "== Outils de construction"
apt-get update
apt-get install -y live-build debootstrap unzip ca-certificates

rm -rf "$WORK"
mkdir -p "$WORK"
cd "$WORK"

echo "== Configuration de l'image"
lb config \
  --distribution trixie \
  --archive-areas "main contrib non-free non-free-firmware" \
  --architectures amd64 \
  --binary-images iso-hybrid \
  --debian-installer none \
  --memtest none \
  --apt-recommends false \
  --iso-application "Nova OS" \
  --iso-publisher "Nova" \
  --iso-volume "NOVA_OS" \
  --bootappend-live "boot=live components quiet splash persistence username=nova user-fullname=Nova hostname=nova locales=fr_FR.UTF-8 keyboard-layouts=fr timezone=Europe/Paris"

# ---------- paquets ----------
cat > config/package-lists/nova.list.chroot <<'EOF'
live-boot
live-config
live-config-systemd
user-setup
sudo
systemd-sysv
locales
tzdata
keyboard-configuration
console-setup
ca-certificates
curl
unzip
zstd
dbus-x11
xserver-xorg
xserver-xorg-video-all
xserver-xorg-input-all
xinit
x11-xserver-utils
lightdm
xfce4
xfce4-terminal
thunar
mousepad
network-manager
network-manager-gnome
pipewire
pipewire-pulse
pipewire-alsa
wireplumber
pulseaudio-utils
alsa-utils
chromium
chromium-l10n
fonts-dejavu-core
zenity
plymouth
plymouth-themes
nodejs
npm
can-utils
firmware-linux-free
firmware-misc-nonfree
firmware-iwlwifi
firmware-realtek
firmware-atheros
firmware-brcm80211
EOF

# ---------- fichiers de Nova OS ----------
INC=config/includes.chroot
mkdir -p "$INC/opt" "$INC/usr/share/plymouth/themes/nova" "$INC/usr/share/xsessions" \
  "$INC/etc/lightdm/lightdm.conf.d" "$INC/etc/udev/rules.d" "$INC/usr/share/backgrounds/nova" \
  "$INC/etc/skel/Desktop" "$INC/etc/plymouth"
unzip -q "$HERE/nova-auto.zip" -d "$INC/opt"
mv "$INC/opt/nova-auto" "$INC/opt/nova"
rm -rf "$INC/opt/nova/node_modules"
# les fichiers peuvent être rangés dans nova-os/ ou posés à plat à côté du script (envoi par le site GitHub)
asset() {
  for p in "$HERE/nova-os/plymouth/$1" "$HERE/nova-os/$1" "$HERE/$1"; do [ -f "$p" ] && { echo "$p"; return; }; done
  echo "Fichier manquant : $1" >&2; exit 1
}
for f in nova.plymouth nova.script logo.png glow.png; do cp "$(asset "$f")" "$INC/usr/share/plymouth/themes/nova/"; done
cp "$(asset fond-nova.png)" "$INC/usr/share/backgrounds/nova/fond-nova.png"
printf '[Daemon]\nTheme=nova\n' > "$INC/etc/plymouth/plymouthd.conf"

cat > "$INC/usr/share/xsessions/nova.desktop" <<'EOF'
[Desktop Entry]
Name=Nova OS
Comment=Nova, l'IA de la TT, en plein écran
Exec=/opt/nova/scripts/pc/nova-session.sh --session
Type=Application
DesktopNames=Nova
EOF

cat > "$INC/etc/lightdm/lightdm.conf.d/90-nova-os.conf" <<'EOF'
[Seat:*]
autologin-user=nova
autologin-user-timeout=0
autologin-session=nova
user-session=nova
EOF

cat > "$INC/etc/udev/rules.d/99-nova-cables.rules" <<'EOF'
# Nova : câbles de diagnostic (KKL, ELM327) utilisables sans être administrateur
SUBSYSTEM=="tty", KERNEL=="ttyUSB[0-9]*", MODE="0666"
SUBSYSTEM=="tty", KERNEL=="ttyACM[0-9]*", MODE="0666"
# FTDI : latence 1 ms, indispensable au dialogue octet par octet de la ligne K
ACTION=="add", SUBSYSTEM=="usb-serial", DRIVER=="ftdi_sio", ATTR{latency_timer}="1"
EOF

cat > "$INC/etc/skel/Desktop/Nova.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Nova
Exec=/opt/nova/scripts/pc/nova-session.sh
Icon=/opt/nova/web/logo.png
EOF
chmod +x "$INC/etc/skel/Desktop/Nova.desktop"

# fond d'écran du bureau de maintenance
mkdir -p "$INC/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml"
cat > "$INC/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="backdrop" type="empty">
    <property name="screen0" type="empty">
      <property name="monitor0" type="empty">
        <property name="workspace0" type="empty">
          <property name="last-image" type="string" value="/usr/share/backgrounds/nova/fond-nova.png"/>
          <property name="image-style" type="int" value="5"/>
        </property>
      </property>
    </property>
  </property>
</channel>
EOF

# ---------- étapes exécutées dans l'image pendant la construction ----------
mkdir -p config/hooks/normal
cat > config/hooks/normal/0500-nova.hook.chroot <<'EOF'
#!/bin/sh
set -e
# modules de Nova (versions Linux 64 bits)
cd /opt/nova
npm install --omit=dev --no-audit --no-fund
chmod +x /opt/nova/scripts/pc/*.sh /opt/nova/lancer.sh
chmod -R a+rX /opt/nova
# session et animation de démarrage
plymouth-set-default-theme nova || ln -sf /usr/share/plymouth/themes/nova/nova.plymouth /usr/share/plymouth/themes/default.plymouth
update-initramfs -u -k all
# brltty s'empare des câbles CH340 : on s'assure qu'il n'est pas là
apt-get remove -y brltty 2>/dev/null || true
EOF
chmod +x config/hooks/normal/0500-nova.hook.chroot

# ---------- menu de démarrage : « Nova OS », sans attente ----------
if [ -d /usr/share/live/build/bootloaders ]; then
  cp -r /usr/share/live/build/bootloaders config/
  # (grep ne trouve parfois rien : ce n'est pas une erreur)
  { grep -rl "Live system" config/bootloaders || true; } | xargs -r sed -i 's/Live system/Nova OS/g'
  { grep -rl "Debian GNU/Linux" config/bootloaders || true; } | xargs -r sed -i 's#Debian GNU/Linux#Nova OS#g'
  for f in config/bootloaders/isolinux/isolinux.cfg config/bootloaders/syslinux/syslinux.cfg; do
    [ -f "$f" ] || continue
    if grep -q "^timeout" "$f"; then sed -i 's/^timeout.*/timeout 20/' "$f"; else echo "timeout 20" >> "$f"; fi
  done
  for f in config/bootloaders/grub-pc/config.cfg config/bootloaders/grub-efi/config.cfg; do
    [ -f "$f" ] || continue
    if grep -q "set timeout" "$f"; then sed -i 's/set timeout=.*/set timeout=2/' "$f"; else echo "set timeout=2" >> "$f"; fi
  done
fi

echo "== Construction (20 à 40 minutes)"
lb build

ISO="$(ls -1 "$WORK"/*.iso 2>/dev/null | head -1 || true)"
[ -n "$ISO" ] || { echo "Échec : pas d'image produite (voir construction.log)"; exit 1; }
mv "$ISO" "$OUT"
ls -lh "$OUT"
echo "Nova OS est prêt : $OUT"
