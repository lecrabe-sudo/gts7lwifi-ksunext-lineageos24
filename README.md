# LineageOS 24.0 + KernelSU-Next — Samsung Galaxy Tab S7 Wi-Fi (`SM-T870` / `gts7lwifi`)

Ce dossier contient :
1. Les 6 fichiers officiels **LineageOS 24.0 (`2026-11-09`)** pour `gts7lwifi` (`SM-T870`), vérifiés par SHA-256.
2. Un workflow **GitHub Actions** prêt à l'emploi basé sur les projets XDA Developers ([thread `4792755` de `itz_reesa`](https://xdaforums.com/t/kernel-ksu-next-lineageos-kernel-for-tab-s7-s7-lte-wi-fi.4792755/), `itzreesa/kernel-builder`, `osm0sis/AnyKernel3`, et la branche `legacy` de `KernelSU-Next`) mis à jour pour **LineageOS 24.0** (`CONFIG_CFI_CLANG=y` + AOSP `clang-r596125` + hooks manuels `KernelSU-Next` `legacy`).

## Contenu du projet

- `.github/workflows/build-gts7lwifi-ksunext.yml` : workflow GitHub Actions compilant le noyau sous Ubuntu `24.04` et empaquetant un zip **AnyKernel3** (+ une image `boot-*-ksunext.img` repaquetée à partir du dernier `boot.img` officiel LineageOS 24.0 + l'APK gestionnaire `KernelSU_Next_*.apk`).
- `build-local.sh` : script équivalent pour compiler localement sous WSL2 (Ubuntu `24.04`) en déposant le résultat dans `out/`.
- `ksunext-gts7lwifi/apply_ksu_hooks.py` : intègre `drivers/kernelsu` et applique les 6 hooks manuels (`reboot.c`, `exec.c`, `open.c`, `read_write.c`, `stat.c`, `input.c`).
- `ksunext-gts7lwifi/ksu.config` : fragment de configuration (`CONFIG_KSU=y`, `CONFIG_KSU_MANUAL_HOOK=y`).
- `ksunext-gts7lwifi/anykernel.sh` : script d'installation AnyKernel3 ciblant `gts7lwifi` (`/dev/block/by-name/boot`).
- `.gitignore` : exclut les gros fichiers `.zip` / `.img` de Git pour permettre le push sur GitHub.

## Étapes pour compiler sur GitHub Actions

1. Créez un dépôt GitHub vide (public ou privé).
2. Depuis `c:\tablette`, initialisez Git et poussez uniquement les fichiers du workflow et du builder (`.gitignore` ignore automatiquement la ROM et les `.img`) :
   ```powershell
   git init -b main
   git add .gitignore README.md .github ksunext-gts7lwifi build-local.sh
   git config user.name "<Votre Nom>"
   git config user.email "<votre@email>"
   git commit -m "Add LineageOS 24.0 KernelSU-Next workflow for gts7lwifi"
   git remote add origin https://github.com/<VOTRE_COMPTE>/<VOTRE_REPO>.git
   git push -u origin main
   ```
3. Sur GitHub : onglet **Actions** → **Build LineageOS 24 KernelSU-Next (SM-T870 / gts7lwifi)** → **Run workflow**.
4. Une fois terminé, téléchargez l'artefact `gts7lwifi-ksunext-...` contenant :
   - `KernelSU-Next-gts7lwifi-...-ak3.zip` (zip flashable **AnyKernel3** — méthode XDA recommandée)
   - `boot-lineage24-...-gts7lwifi-ksunext.img` (image boot complète repaquetée)
   - `KernelSU_Next_*.apk` (application gestionnaire récupérée automatiquement, pour que l'artefact soit complet)

## Installation sur la tablette (`SM-T870`)

1. Installez d'abord LineageOS 24.0 + `vbmeta.img` + `dtbo.img` + `recovery.img` selon le guide officiel LineageOS pour `gts7lwifi`.
2. Dans **Lineage Recovery** : `Apply update` → `Apply from ADB`, puis :
   ```powershell
   adb sideload KernelSU-Next-gts7lwifi-...-ak3.zip
   ```
   *(Acceptez si Lineage Recovery signale que la signature du zip AnyKernel3 n'est pas signée avec la clé LineageOS.)*
3. Redémarrez sous Android et installez l'application gestionnaire `KernelSU_Next_*.apk` fournie dans l'artefact (sans patcher `boot.img`). Si elle affiche **« Non pris en charge »**, c'est que sa version interne ne correspond pas au pilote compilé : installez une version du gestionnaire **KernelSU-Next** correspondant au commit du pilote indiqué dans le journal de compilation (visible sur la page du run GitHub Actions), depuis <https://github.com/KernelSU-Next/KernelSU-Next/releases>.
