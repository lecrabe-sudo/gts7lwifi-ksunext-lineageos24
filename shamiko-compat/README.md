# Shamiko Compat (`shamiko_compat`) — SM-T870

Module compagnon **léger et sans conflit** conçu pour compléter **Zygisk Assistant** sur **KernelSU-Next (`33327+`)** + **Zygisk Next (`1.5.3+`)** (Samsung Galaxy Tab S7 `SM-T870` / LineageOS 24).

## Rôle exact

Contrairement à Shamiko (`v1.2.5-414`, closed-source, obfusqué et dépendant de l'ancien hook noyau `prctl` supprimé de KernelSU-Next), ce module n'injecte **aucune** bibliothèque Zygisk concurrente à `Zygisk Assistant`. Il apporte les couches complémentaires de Shamiko :

1. **`sepolicy.rule`** (règles SELinux Zygote) : autorise `zygote` à accéder à `adb_data_file` (`search`), `unlabeled` (`open read getattr`), `nsfs` (`open read`) et la capacité `sys_chroot`.
2. **Durcissement `resetprop` pré-Zygote (`post-fs-data.sh`) et post-boot (`service.sh`)** via [`common_props.sh`](common_props.sh) : normalisation complète des propriétés vérifiées par Shamiko (`ro.boot.vbmeta.device_state`, `ro.boot.verifiedbootstate`, `ro.boot.flash.locked`, `ro.boot.veritymode`, `warranty_bit`, `ro.debuggable`, `ro.force.debuggable`, `ro.secure`, `ro.adb.secure`, `ro.*.build.type`/`tags`, `sys.oem_unlock_allowed`, masquage `recovery` dans `*bootmode`) sans écraser `ro.boot.vbmeta.digest` ni falsifier l'identité matérielle.
3. **Vérification d'intégrité SHA-256 à l'installation (`verify.sh`)** : chaque fichier du `.zip` est contrôlé contre son `.sha256` avant extraction.
4. **Bouton `Action` KernelSU-Next (`action.sh`) & statut dynamique (`module.prop`)** : affiche l'état temps réel (SELinux, `Zygisk Assistant`, `sepolicy.rule`, propriétés vérifiées/corrigées, éventuels AVC `zygote`).

## Compilation du `.zip`

```powershell
wsl -e python3 /mnt/c/tablette-shamiko-compat/shamiko-compat/build.py
```

Le paquet compilé et son empreinte `.sha256` sont générés dans `out/Shamiko-Compat-v1.0.0-SM-T870.zip`.
