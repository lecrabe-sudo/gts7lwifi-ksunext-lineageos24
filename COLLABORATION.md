# Collaboration Claude ↔ Gemini (Antigravity)

Deux assistants travaillent dans ce dossier (`C:\tablette`). Ils ne se parlent pas
directement : **ce fichier est le seul canal**. Lis-le en entier avant de commencer,
mets-le à jour en finissant.

## Règles

1. **Les deux assistants partagent la même copie de travail (`C:\tablette`).** Ne change
   donc jamais de branche ici (`git switch` / `checkout`) : ça modifierait les fichiers sous
   les pieds de l'autre. Pour une branche à toi, crée un worktree séparé :
   `git worktree add ..\tablette-gemini -b gemini/<sujet>` (Claude : `..\tablette-claude`).
   Jamais de commit direct sur `main`, jamais de `push --force`.
2. **Avant de travailler** : réserver la tâche dans le tableau ci-dessous
   (colonne « Qui » + « En cours ») en éditant ce fichier.
3. **Un fichier = un seul assistant à la fois.** Si un fichier est réservé par l'autre,
   n'y touche pas : ajoute une note dans « Messages ».
4. **Ne jamais publier** `backup/` (EFS, identifiants uniques de la tablette), ni les
   `.img` / `.zip` (déjà dans `.gitignore`). Ne jamais lire ni envoyer `backup/` à un service en ligne.
5. **Tablette (adb)** : un seul assistant connecté à la fois. Aucune écriture,
   aucun flash, aucune suppression sur la tablette sans accord explicite de l'utilisateur.
6. **Modules root** : seulement ceux de `integrity/` (empreintes vérifiées). Les zips de
   `out/tmp_integrity/` et `out/tmp_shamiko/` ne sont pas vérifiés.
7. En finissant : passer la tâche en « Fait », résumer en une ligne dans le journal.

## Tâches

| # | Tâche | Qui | État |
|---|-------|-----|------|
| 1 | Durcissement du build (seccomp, épinglage, droits minimaux) | Claude | Fait — branche `harden/seccomp-and-pinning`, build CI OK |
| 2 | Sauvegarde tablette (18 partitions + stockage, sans APK ni Android/data) | Claude | Fait — `backup/20261115-1839-SM-T870/` |
| 3 | Fusionner `harden/seccomp-and-pinning` dans `main` | Utilisateur | À faire |
| 4 | Image-guide des réglages Play Integrity pour KernelSU-Next | — | Libre |
| 5 | Lot de modules compatible dans `integrity/` (Zygisk Next + PIF + un seul Tricky Store) + mise à jour de `install-modules.bat` | — | Libre |
| 6 | Patch seccomp : remettre `ksu_allow_reboot` à zéro dans les processus enfants (`copy_seccomp`) | — | Libre |

## État connu (2026-11-15)

- Tablette : SM-T870, LineageOS 24 (Android 17), patch 2026-10-05, kernel KernelSU-Next `acf15abe` (root OK).
- Fichiers LineageOS du dossier : SHA-256 identiques au serveur officiel.
- Dépôt GitHub : `lecrabe-sudo/gts7lwifi-ksunext-lineageos24` — **ne pas renommer** (demande de l'utilisateur).

## Messages

<!-- Format : [date heure] Claude|Gemini → l'autre : message -->

## Journal

- [2026-11-15] Claude : création de ce fichier.
