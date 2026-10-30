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
# version du système : numéro de construction GitHub (12, 13…), sinon date de la construction locale
NOVA_OS_VERSION="${NOVA_OS_VERSION:-local-$(date +%Y%m%d%H%M)}"
NOVA_OS_DEPOT="${NOVA_OS_DEPOT:-Emptyrl/nova-os}"
# fichiers du système publiés à côté de l'image, pour les mises à jour d'un Nova OS installé sur disque
PUBLIE="$HERE/publie"
# options du noyau communes à la clé et au disque (le disque ajoute l'emplacement A/B et sa persistance)
NOVA_CMDLINE="quiet splash loglevel=3 noeject noprompt user-default-groups=audio,video,plugdev,netdev,bluetooth,dialout,sudo,input,render,adm,systemd-journal username=nova user-fullname=Nova hostname=nova locales=fr_FR.UTF-8 keyboard-layouts=fr timezone=Europe/Paris"
[ "$(id -u)" = "0" ] || { echo "À lancer en administrateur (sudo)."; exit 1; }
# tout est noté dans construction.log, dès la première ligne
exec > >(tee "$HERE/construction.log") 2>&1
trap 'echo "ÉCHEC à la ligne $LINENO : $BASH_COMMAND"' ERR

echo "== Outils de construction"
# dépôts Debian complets (dont non-free-firmware) pour vérifier quels paquets existent
# on complète les dépôts déjà configurés au lieu d'en ajouter un second (apt refuse les doublons)
rm -f /etc/apt/sources.list.d/nova-complet.sources
for f in /etc/apt/sources.list.d/*.sources; do
  if [ -f "$f" ]; then sed -i -E 's/^Components:.*/Components: main contrib non-free non-free-firmware/' "$f"; fi
done
if [ -f /etc/apt/sources.list ]; then sed -i -E '/^deb /{/non-free-firmware/!s/ main( |$)/ main contrib non-free non-free-firmware\1/}' /etc/apt/sources.list; fi
apt-get update
apt-get install -y live-build debootstrap unzip ca-certificates

rm -rf "$WORK"
mkdir -p "$WORK"
cd "$WORK"

echo "== Configuration de l'image"
# zstd : le système se décompresse beaucoup plus vite au démarrage que le xz par défaut
ZSTD=()
if lb config --help 2>&1 | grep -q -- "--chroot-squashfs-compression-type"; then
  ZSTD=(--chroot-squashfs-compression-type zstd --chroot-squashfs-compression-level 15)
fi
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
  "${ZSTD[@]}" \
  --bootappend-live "boot=live components persistence $NOVA_CMDLINE"

# ---------- paquets ----------
# Sans les « recommandés », il faut citer tout ce qui compte : pilotes graphiques (sinon tout est
# dessiné par le processeur et ça rame), wpasupplicant (sinon pas de Wi-Fi), Bluetooth, téléphone.
PKGS="
live-boot live-config live-config-systemd user-setup sudo systemd-sysv dbus dbus-user-session dbus-x11
locales tzdata keyboard-configuration console-setup ca-certificates curl unzip zstd pciutils usbutils
xserver-xorg xserver-xorg-core xserver-xorg-video-all xserver-xorg-input-all xserver-xorg-input-libinput
xinit x11-xserver-utils x11-utils xdotool unclutter
libgl1-mesa-dri libglx-mesa0 libegl-mesa0 libgbm1 mesa-vulkan-drivers mesa-va-drivers mesa-vdpau-drivers
va-driver-all intel-media-va-driver-non-free i965-va-driver
lightdm xfce4 xfwm4 xfce4-terminal thunar mousepad
network-manager network-manager-gnome wpasupplicant iw wireless-regdb rfkill iproute2 usb-modeswitch
bluez bluez-obexd libspa-0.2-bluetooth
pipewire pipewire-pulse pipewire-alsa wireplumber pulseaudio-utils alsa-utils alsa-ucm-conf firmware-sof-signed
playerctl kdeconnect adb scrcpy
chromium chromium-l10n chromium-sandbox fonts-dejavu-core fonts-noto-color-emoji
zenity plymouth plymouth-themes mesa-utils systemd-zram-generator e2fsprogs dosfstools b43-fwcutter wget bzip2
nodejs npm can-utils
intel-microcode amd64-microcode
firmware-linux-free firmware-misc-nonfree firmware-linux-nonfree
firmware-iwlwifi firmware-realtek firmware-atheros firmware-brcm80211 firmware-libertas firmware-mediatek
firmware-ti-connectivity firmware-intel-sound firmware-intel-graphics firmware-intel-misc
firmware-amd-graphics firmware-nvidia-graphics firmware-bnx2 firmware-bnx2x firmware-netronome
firmware-qlogic firmware-cavium firmware-myricom firmware-netxen firmware-qcom-soc
polkitd
grub-pc-bin grub-efi-amd64-bin grub2-common parted rsync efibootmgr ntfs-3g
"
OK=(); MANQUE=()
for p in $PKGS; do
  if apt-cache show "$p" >/dev/null 2>&1; then OK+=("$p"); else MANQUE+=("$p"); fi
done
printf '%s\n' "${OK[@]}" > config/package-lists/nova.list.chroot
echo "Paquets retenus : ${#OK[@]}. Absents de Debian 13, ignorés : ${MANQUE[*]:-aucun}"

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
# aucun gestionnaire de modem ne doit toucher aux câbles de diagnostic
SUBSYSTEM=="tty", KERNEL=="ttyUSB[0-9]*", ENV{ID_MM_DEVICE_IGNORE}="1"
SUBSYSTEM=="tty", KERNEL=="ttyACM[0-9]*", ENV{ID_MM_DEVICE_IGNORE}="1"
EOF

# mémoire compressée (zram) : évite que tout rame quand la mémoire est pleine
mkdir -p "$INC/etc/systemd"
cat > "$INC/etc/systemd/zram-generator.conf" <<'EOF'
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
EOF
# journal du système gardé d'un démarrage à l'autre (pour comprendre les plantages)
mkdir -p "$INC/var/log/journal" "$INC/etc/systemd/journald.conf.d" "$INC/etc/sudoers.d"
cat > "$INC/etc/systemd/journald.conf.d/90-nova.conf" <<'EOF'
[Journal]
Storage=persistent
SystemMaxUse=150M
EOF
# Nova règle l'affichage et exporte ses journaux sur la clé sans mot de passe
cat > "$INC/etc/sudoers.d/90-nova" <<'EOF'
nova ALL=(ALL) NOPASSWD: ALL
EOF
chmod 440 "$INC/etc/sudoers.d/90-nova"

# Extinction : la clé USB ne doit pas être détachée avant la toute fin, sinon le système ne peut
# plus lire le programme qui coupe le courant et reste bloqué (« Failed to execute shutdown binary »).
mkdir -p "$INC/usr/local/sbin" "$INC/etc/systemd/system/multi-user.target.wants"
cat > "$INC/usr/local/sbin/nova-garder-cle" <<'EOF'
#!/bin/sh
# pour chaque montage de la clé live (/run/live/...), systemd ne le démonte plus à l'arrêt
findmnt -rn -o TARGET | grep '^/run/live' | while read -r m; do
  u="$(systemd-escape --path --suffix=mount "$m")"
  mkdir -p "/run/systemd/system/$u.d"
  printf '[Unit]\nDefaultDependencies=no\n' > "/run/systemd/system/$u.d/90-nova.conf"
done
systemctl daemon-reload
EOF
chmod +x "$INC/usr/local/sbin/nova-garder-cle"
cat > "$INC/etc/systemd/system/nova-garder-cle.service" <<'EOF'
[Unit]
Description=Nova OS : garder la clé montée jusqu'à l'extinction
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/nova-garder-cle
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
ln -sf /etc/systemd/system/nova-garder-cle.service "$INC/etc/systemd/system/multi-user.target.wants/nova-garder-cle.service"

# Nova pilote elle-même le Wi-Fi, le Bluetooth, l'écran et l'extinction, sans mot de passe
mkdir -p "$INC/etc/polkit-1/rules.d" "$INC/etc/NetworkManager/conf.d"
cat > "$INC/etc/polkit-1/rules.d/50-nova.rules" <<'EOF'
polkit.addRule(function (action, subject) {
  if (subject.user == "nova") return polkit.Result.YES;
});
EOF
cat > "$INC/etc/NetworkManager/conf.d/90-nova.conf" <<'EOF'
[main]
plugins=keyfile
[device]
wifi.scan-rand-mac-address=no
[ifupdown]
managed=true
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

# ---------- installation sur disque et mises à jour du système (dossier systeme/) ----------
mkdir -p "$INC/etc/nova-os" "$INC/usr/local/sbin" "$INC/etc/systemd/system/timers.target.wants"
echo "$NOVA_OS_VERSION" > "$INC/etc/nova-os/version"
echo "$NOVA_OS_DEPOT" > "$INC/etc/nova-os/depot"
echo "components $NOVA_CMDLINE" > "$INC/etc/nova-os/cmdline"
for f in nova-os-commun nova-os-installer nova-os-maj; do
  src=""
  for p in "$HERE/systeme/$f" "$HERE/$f"; do [ -f "$p" ] && { src="$p"; break; }; done
  [ -n "$src" ] || { echo "Fichier manquant : systeme/$f" >&2; exit 1; }
  cp "$src" "$INC/usr/local/sbin/$f"
  chmod 755 "$INC/usr/local/sbin/$f"
done
# trois minutes après le démarrage, une nouvelle version qui a tenu devient la version habituelle
cat > "$INC/etc/systemd/system/nova-os-valider.service" <<'EOF'
[Unit]
Description=Nova OS : garder la nouvelle version du système si elle a démarré
[Service]
Type=oneshot
ExecStart=/usr/local/sbin/nova-os-maj valider
EOF
cat > "$INC/etc/systemd/system/nova-os-valider.timer" <<'EOF'
[Unit]
Description=Nova OS : validation de la version du système
[Timer]
OnBootSec=3min
[Install]
WantedBy=timers.target
EOF
ln -sf /etc/systemd/system/nova-os-valider.timer "$INC/etc/systemd/system/timers.target.wants/nova-os-valider.timer"
cat > "$INC/etc/skel/Desktop/Installer-Nova-OS.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Installer Nova OS sur le disque
Comment=Installe Nova OS à côté de Windows, dans l'espace libre du disque
Exec=sh -c 'sudo -n env DISPLAY="$DISPLAY" XAUTHORITY="$XAUTHORITY" /usr/local/sbin/nova-os-installer'
Icon=drive-harddisk
EOF
chmod +x "$INC/etc/skel/Desktop/Installer-Nova-OS.desktop"

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
# Wi-Fi Broadcom anciens (BCM43xx, pilote b43, ex. Dell Wireless 1397 / BCM4312) : leur microprogramme
# n'est pas dans Debian, on l'extrait du pilote Broadcom d'origine (si le téléchargement échoue, on continue)
if command -v b43-fwcutter >/dev/null; then
  ( cd /tmp && wget -q --tries=3 --timeout=30 -O wl.tar.bz2 https://www.lwfinger.com/b43-firmware/broadcom-wl-5.100.138.tar.bz2 \
    && tar xjf wl.tar.bz2 && b43-fwcutter -w /lib/firmware broadcom-wl-5.100.138/linux/wl_apsta.o \
    && echo "b43 : microprogramme installé" ) || echo "b43 : microprogramme non installé"
  rm -rf /tmp/wl.tar.bz2 /tmp/broadcom-wl-5.100.138
fi
# langue française déjà prête (live-config n'a plus à la générer à chaque démarrage)
sed -i 's/^# *fr_FR.UTF-8 UTF-8/fr_FR.UTF-8 UTF-8/' /etc/locale.gen 2>/dev/null || true
locale-gen 2>/dev/null || true
printf 'LANG=fr_FR.UTF-8\n' > /etc/default/locale
ldconfig
# démarrage plus rapide : on n'attend pas le réseau, ni les services inutiles en voiture
systemctl mask NetworkManager-wait-online.service systemd-networkd-wait-online.service 2>/dev/null || true
systemctl disable apt-daily.timer apt-daily-upgrade.timer man-db.timer e2scrub_all.timer 2>/dev/null || true
systemctl enable bluetooth.service NetworkManager.service 2>/dev/null || true
# Bluetooth allumé au démarrage, visible sous le nom « Nova »
if [ -f /etc/bluetooth/main.conf ]; then
  sed -i -E 's/^#? *AutoEnable *=.*/AutoEnable=true/; s/^#? *Name *=.*/Name = Nova/; s/^#? *FastConnectable *=.*/FastConnectable = true/' /etc/bluetooth/main.conf
fi
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

# Fichiers du système pour les mises à jour d'un Nova OS installé sur disque : noyau, initrd et système
# en morceaux de 1,9 Go (limite de 2 Go par fichier sur GitHub), décrits par nova-os-systeme.txt.
echo "== Fichiers de mise à jour du système"
rm -rf "$WORK/chroot" "$WORK/cache" 2>/dev/null || true
rm -rf "$HERE/publie"
mkdir -p "$PUBLIE"
LIVE="$WORK/binary/live"
cp "$(ls -1 "$LIVE"/vmlinuz* | sort -V | tail -1)" "$PUBLIE/vmlinuz"
cp "$(ls -1 "$LIVE"/initrd.img* | sort -V | tail -1)" "$PUBLIE/initrd.img"
SQ_SUM="$(sha256sum "$LIVE/filesystem.squashfs" | cut -d' ' -f1)"
split -b 1900M -d -a 1 "$LIVE/filesystem.squashfs" "$PUBLIE/filesystem.squashfs.part"
{
  echo "nova-os $NOVA_OS_VERSION"
  echo "tag nova-os-$NOVA_OS_VERSION"
  echo "date $(date -u +%F)"
  for f in vmlinuz initrd.img $(cd "$PUBLIE" && ls -1 filesystem.squashfs.part* | sort -V); do
    echo "fichier $f $(stat -c %s "$PUBLIE/$f") $(sha256sum "$PUBLIE/$f" | cut -d' ' -f1)"
  done
  echo "somme filesystem.squashfs $SQ_SUM"
} > "$PUBLIE/nova-os-systeme.txt"
cat "$PUBLIE/nova-os-systeme.txt"
# l'image fait plus de 2 Go : on libère d'abord la place prise par la construction
# (le système de travail, les caches) avant de la déplacer, sinon le disque est plein
echo "== Rangement de l'image ($(du -h "$ISO" | cut -f1))"
rm -rf "$WORK/chroot" "$WORK/binary" "$WORK/cache" "$WORK/.build" 2>/dev/null || true
apt-get clean
df -h "$WORK" "$(dirname "$OUT")" || true
mv "$ISO" "$OUT"
ls -lh "$OUT"
# GitHub refuse les fichiers de plus de 2 Go dans une release : au-delà, l'image est coupée en
# morceaux à recoller sous Windows avec recoller-nova-os.bat (fourni à côté)
LIMIT=$((2000 * 1024 * 1024))
if [ "$(stat -c %s "$OUT")" -gt "$LIMIT" ]; then
  echo "== Image > 2 Go : découpage en morceaux"
  split -b 1900M -d -a 1 "$OUT" "$OUT.morceau"
  rm -f "$OUT"
  PARTS="$(ls -1 "$OUT".morceau* | xargs -n1 basename | paste -sd+ -)"
  printf '@echo off\r\ncd /d "%%~dp0"\r\necho Recollage de nova-os.iso...\r\ncopy /b %s nova-os.iso\r\necho Termine : nova-os.iso est pret pour Rufus.\r\npause\r\n' "$PARTS" > "$(dirname "$OUT")/recoller-nova-os.bat"
  ls -lh "$(dirname "$OUT")"/nova-os.iso.morceau* "$(dirname "$OUT")/recoller-nova-os.bat"
fi
echo "Nova OS est prêt : $OUT"
