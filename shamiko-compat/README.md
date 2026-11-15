# Shamiko Compat (`shamiko_compat` v1.1.0) — SM-T870

Module compagnon **léger et sans conflit** conçu pour compléter **Zygisk Assistant** sur **KernelSU-Next (`33327+`)** + **Zygisk Next (`1.5.3+`)** (Samsung Galaxy Tab S7 `SM-T870` / LineageOS 24).

## Rôle exact

Contrairement à Shamiko (`v1.2.5-414`, closed-source, obfusqué et dépendant de l'ancien hook noyau `prctl` supprimé de KernelSU-Next), ce module n'injecte **aucune** bibliothèque Zygisk concurrente à `Zygisk Assistant`. Il apporte les couches complémentaires de Shamiko :

1. **Mode `whitelist` (`/data/adb/shamiko_compat/whitelist` via [`whitelist.sh`](whitelist.sh))** : par défaut, KernelSU-Next applique `umount_modules=true` à toutes les applications non-root (et `Zygisk Assistant` y masque le root). Tout nom de paquet ajouté dans `/data/adb/shamiko_compat/whitelist` (un par ligne, `#` pour commenter) passe automatiquement son profil non-root en `umount_modules=false` via `ksud profile`, et revient au profil par défaut dès qu'il est retiré (ou à la désinstallation). Appliqué au démarrage (`service.sh`) et à la demande via `Action` (`action.sh`).
2. **Aucune règle SELinux** (v1.1.1) : le `sepolicy.rule` des versions 1.0.0 à 1.1.0 (accès `zygote` à `adb_data_file`, `unlabeled`, `nsfs` et `sys_chroot`) servait au `.so` de Shamiko, absent ici. Il a été retiré pour ne pas affaiblir la politique SELinux. Il disparaît de la tablette au premier redémarrage après la mise à jour.
3. **Durcissement `resetprop` pré-Zygote (`post-fs-data.sh`) et post-boot (`service.sh`)** via [`common_props.sh`](common_props.sh) : normalisation complète des propriétés vérifiées par Shamiko (`ro.boot.vbmeta.device_state`, `ro.boot.verifiedbootstate`, `ro.boot.flash.locked`, `ro.boot.veritymode`, `warranty_bit`, `ro.debuggable`, `ro.force.debuggable`, `ro.secure`, `ro.adb.secure`, `ro.*.build.type`/`tags`, `sys.oem_unlock_allowed`, masquage `recovery` dans `*bootmode`) sans écraser `ro.boot.vbmeta.digest` ni falsifier l'identité matérielle.
4. **Contrôle anti-corruption à l'installation (`verify.sh`)** : chaque fichier du `.zip` est comparé à son `.sha256` rangé dans le même zip. Ça détecte un fichier abîmé, pas une modification volontaire : pour l'authenticité, vérifier le SHA-256 du zip publié dans `out/*.zip.sha256`.
5. **Bouton `Action` KernelSU-Next (`action.sh`) & statut dynamique (`module.prop`)** : synchronise `whitelist` et affiche l'état temps réel (SELinux, `Zygisk Assistant`, `whitelist`, `sepolicy.rule`, propriétés vérifiées/corrigées, éventuels AVC `zygote`).

## Compilation du `.zip`

```powershell
wsl -e python3 /mnt/c/tablette-shamiko-compat/shamiko-compat/build.py
```

Le paquet compilé et son empreinte `.sha256` sont générés dans `out/Shamiko-Compat-v1.1.0-SM-T870.zip`.
