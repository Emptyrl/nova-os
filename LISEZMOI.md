# Construire Nova OS

Ce dossier fabrique **nova-os.iso** : l'image de Nova OS à mettre dans Rufus.
Une fois écrite sur la clé, le PC démarre ainsi :

1. le menu « Nova OS » ;
2. l'animation du logo TT ;
3. Nova en plein écran.

Il n'y a ni Linux Mint ni bureau à l'écran. Nova OS est construit sur une base Debian 13, invisible.

La construction se fait gratuitement chez **GitHub**, sur leurs ordinateurs. Ton PC sous Windows 7 sert seulement à envoyer les fichiers et à récupérer l'image.

## 1. Créer le projet sur GitHub (une seule fois)

1. Crée un compte gratuit sur https://github.com (bouton « Sign up »).
2. En haut à droite, clique sur **+** puis **New repository**. Nom : `nova-os`, laisse « Private » si tu veux, puis **Create repository**.
3. Sur la page du projet, clique sur le lien **uploading an existing file**.
4. Dans l'Explorateur Windows, ouvre ce dossier `Nova-OS-Constructeur`, sélectionne **tout son contenu** et glisse-le dans la page :
   - le dossier `.github` ;
   - le dossier `nova-os` ;
   - le dossier `systeme` (installation sur disque et mises à jour du système) ;
   - `construire-nova-os.sh` ;
   - `nova-auto.zip` ;
   - ce fichier.
5. En bas, clique sur **Commit changes**.
6. Vérifie que le projet contient bien le dossier `.github` : sans lui, l'étape suivante n'apparaît pas.

## 2. Lancer la construction

1. Onglet **Actions**. Si GitHub demande d'activer les workflows, accepte.
2. À gauche, choisis **Construire Nova OS**, puis à droite **Run workflow** → **Run workflow**.
3. Attends 30 à 60 minutes. Le rond jaune devient une coche verte.
4. Sur la page d'accueil du projet, à droite, ouvre **Releases**. La dernière contient **nova-os.iso** (environ 1,5 Go) : télécharge-la.

Si la construction échoue (croix rouge), ouvre-la. En bas de la page, télécharge **journal-construction** et envoie-le-moi.

## 3. Mettre Nova OS sur la clé (Rufus 3.22 sous Windows 7)

1. **Périphérique** : la clé (16 Go minimum, elle sera effacée).
2. **SÉLECTION** : `nova-os.iso`.
3. **Taille de la partition persistante** : 8 Go ou plus. C'est ce qui garde tes réglages, ta clé Anthropic, la voix et les logs.
4. **Schéma de partition** : MBR, **système de destination** : « BIOS ou UEFI ».
5. **DÉMARRER**, puis choisis « Écrire en mode Image ISO » et réponds **Oui** aux téléchargements.

## 4. Démarrer

1. Clé branchée, redémarre le PC en tapant sur **F12** (ou F9, F11, Échap selon la marque).
2. Choisis la clé : c'est Nova OS.

La première fois, connecte le Wi-Fi :

1. Va dans **Réglages → Menu Nova OS → Bureau Linux** et clique sur l'icône réseau en haut ou en bas de l'écran.
2. Ferme ensuite la session du bureau : Nova revient.

Puis dans Nova, ouvre les Réglages :

- colle ta **clé Anthropic** ;
- **installe la voix** ;
- **télécharge la reconnaissance vocale**.

## Installer Nova OS sur le disque, à côté de Windows

Nova OS démarre plus vite depuis le disque, et la clé USB reste libre.

1. **Dans Windows, libère de la place** (20 Go minimum, 40 Go conseillés) :
   - clic droit sur **Ordinateur** → **Gérer** → **Gestion des disques** ;
   - clic droit sur **C:** → **Réduire le volume** ;
   - laisse l'espace en **« Non alloué »** : ne crée pas de partition dedans.
2. Démarre sur la clé Nova OS, puis va dans **Réglages → Menu Nova OS → Bureau Linux**.
3. Double-clique sur **« Installer Nova OS sur le disque »**. Vérifie le résumé, puis écris **INSTALLER** pour confirmer.
4. À la fin, éteins le PC, retire la clé et rallume. Le menu propose **Nova OS** (par défaut, au bout de 3 secondes) et **Windows**.

Les partitions de Windows ne sont pas touchées. Seul le menu de démarrage du PC est remplacé, et l'ancien est sauvegardé.

**Pour retirer Nova OS plus tard**, il faut d'abord remettre le démarrage de Windows, sinon le PC ne démarrera plus :

1. Dans Nova OS, ouvre un terminal du bureau Linux et lance `sudo nova-os-installer --restaurer-windows`.
2. Ensuite seulement, supprime les partitions `NOVA_SYSTEME` et `nova-donnees` dans la Gestion des disques de Windows.

## Mettre à jour le système installé sur disque

Chaque construction GitHub publie, à côté de l'image, les fichiers du système : `nova-os-systeme.txt`, `vmlinuz`, `initrd.img` et `filesystem.squashfs.part*`.

- **Par Internet** : dans Nova, va dans **Réglages → Système Nova OS → Chercher une version**, puis **Installer**. Il y a environ 2 Go à télécharger, et Nova reste utilisable pendant ce temps. Touche ensuite **Redémarrer pour l'essayer**.
- **Sans Internet** : sur une clé USB (FAT32, exFAT ou NTFS), crée un dossier **`nova-os-maj`** et mets-y tous ces fichiers depuis la page de la release. Branche la clé, puis fais la même chose dans les Réglages.

La nouvelle version s'installe **à côté** de celle qui tourne, et le PC démarre dessus **une seule fois** à l'essai :

- si elle tient 3 minutes, elle devient la version habituelle ;
- si elle plante ou bloque, éteins et rallume : **l'ancienne version reprend toute seule**.

Dans le menu de démarrage, « Nova OS (version precedente) » permet aussi de revenir en arrière à la main. Tes données (dossier Nova, clé Anthropic, Wi-Fi, Bluetooth) sont sur la partition `nova-donnees` et ne sont jamais touchées.

## Mettre à jour Nova OS plus tard

Remplace `nova-auto.zip` dans le projet GitHub par la nouvelle version de Nova (« Add file » → « Upload files »), puis relance **Run workflow**. Ensuite :

- pour la clé USB, réécris-la avec Rufus ;
- pour un Nova OS installé sur disque, va dans **Réglages → Système Nova OS** (voir plus haut).

Pour une simple mise à jour de Nova (le programme), Réglages → Mises à jour suffit, sans reconstruire l'image.

## Construire sans GitHub

Sur un PC sous Debian 13, avec 15 Go libres, lance `sudo bash construire-nova-os.sh` : l'image sort dans ce dossier.
