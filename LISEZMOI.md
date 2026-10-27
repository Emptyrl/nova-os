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

## Mettre à jour Nova OS plus tard

Remplace `nova-auto.zip` dans le projet GitHub par la nouvelle version de Nova (« Add file » → « Upload files »), relance **Run workflow**, puis réécris la clé avec Rufus.

## Construire sans GitHub

Sur un PC sous Debian 13, avec 15 Go libres, lance `sudo bash construire-nova-os.sh` : l'image sort dans ce dossier.
