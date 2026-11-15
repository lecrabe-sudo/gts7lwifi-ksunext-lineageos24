#!/usr/bin/env bash
# =====================================================================
# Build LineageOS 24.0 + KernelSU-Next for Samsung Galaxy Tab S7 Wi-Fi
#   SM-T870 / gts7lwifi  (Snapdragon 865+, kona, kernel 4.19, non-GKI)
#
# A exécuter DANS WSL2 (Ubuntu 24.04), pas sous PowerShell.
# Reprend la même logique que le workflow GitHub Actions du projet,
# mais tout en local, et réutilise le boot.img officiel déjà présent
# dans C:\tablette (vu depuis WSL comme /mnt/c/tablette/boot.img).
#
# Usage :
#   chmod +x build-local.sh
#   ./build-local.sh
#
# Résultat : C:\tablette\out\
#   - KernelSU-Next-gts7lwifi-...-ak3.zip   (à flasher en sideload)
#   - boot-lineage24-...-gts7lwifi-ksunext.img
#   - SHA256SUMS.txt
# =====================================================================
set -euo pipefail

# --- Réglages (modifiables) ------------------------------------------
PROJECT_WIN="/mnt/c/tablette"          # dossier C:\tablette vu depuis WSL
KERNEL_BRANCH="lineage-24.0"           # branche de android_kernel_samsung_sm8250
# Dépendances tierces épinglées (mêmes valeurs que le workflow GitHub Actions).
# Pour mettre à jour : git ls-remote <url> <branche>, relire le diff, puis changer le SHA.
KSU_REF="e5f5ec998de88b9fc43c62cff8f7ae12d3f4800a"   # KernelSU-Next, branche legacy (4.19 non-GKI)
AK3_COMMIT="41f04bdb4ee30a44e429c2c1131d5e8bb32b15f1" # osm0sis/AnyKernel3
KSU_MANAGER_TAG="v3.4.2"
KSU_MANAGER_APK="KernelSU_Next_v3.4.2_33355-release.apk"
KSU_MANAGER_SHA256="774a5511f7034a4930e881114e202319cbdc34c5aaaa5c7c6b6d2902364e4c58"
WORK="${HOME}/gts7lwifi-build"          # on compile sur ext4 (~), PAS sur /mnt/c (lent)
CLANG_TAG="android-17.0.0_r1"
CLANG_PKG="clang-r596125"
# ---------------------------------------------------------------------

log() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
die() { printf '\n\033[1;31mERREUR: %s\033[0m\n' "$*" >&2; exit 1; }

[ -d "${PROJECT_WIN}/ksunext-gts7lwifi" ] || die "Dossier introuvable : ${PROJECT_WIN}/ksunext-gts7lwifi (lance ce script depuis WSL)"
[ -f "${PROJECT_WIN}/boot.img" ] || die "boot.img officiel introuvable dans ${PROJECT_WIN}"

# --- 1. Dépendances ---------------------------------------------------
log "Installation des dépendances (sudo)"
sudo apt-get update
sudo apt-get install -y --no-install-recommends \
  bc bison build-essential ca-certificates cpio curl flex \
  gcc-aarch64-linux-gnu git jq kmod libelf-dev libssl-dev libxml2 \
  lz4 python3 rsync tar xz-utils zip

mkdir -p "${WORK}"
cd "${WORK}"

# --- 2. Toolchain Clang (AOSP) ---------------------------------------
if [ ! -x "${WORK}/clang/bin/clang" ]; then
  log "Téléchargement d'AOSP ${CLANG_PKG}"
  mkdir -p "${WORK}/clang"
  curl -fsSL \
    "https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/tags/${CLANG_TAG}/${CLANG_PKG}.tar.gz" \
    | tar -xz -C "${WORK}/clang"
fi
"${WORK}/clang/bin/clang" --version | head -n1
export PATH="${WORK}/clang/bin:${PATH}"

# --- 3. Sources -------------------------------------------------------
clone_ref() {  # url ref dest [shallow=true|false]
  local url="$1" ref="$2" dest="$3" shallow="${4:-true}"
  local depth_args=()
  [ "${shallow}" = "true" ] && depth_args=(--depth=1)
  if [ -d "${dest}/.git" ]; then
    log "Déjà cloné : ${dest}"
    if [ "${shallow}" = "false" ] && [ -f "${dest}/.git/shallow" ]; then
      git -C "${dest}" fetch --unshallow --tags origin || true
    fi
    return
  fi
  if ! git clone "${depth_args[@]}" --branch "${ref}" "${url}" "${dest}" 2>/dev/null; then
    rm -rf "${dest}"; git init "${dest}"
    git -C "${dest}" remote add origin "${url}"
    git -C "${dest}" fetch "${depth_args[@]}" --tags origin "${ref}"
    git -C "${dest}" checkout FETCH_HEAD
  fi
}

log "Clonage du noyau, KernelSU-Next, AnyKernel3, mkbootimg"
clone_ref https://github.com/LineageOS/android_kernel_samsung_sm8250.git "${KERNEL_BRANCH}" "${WORK}/kernel" true
clone_ref https://github.com/KernelSU-Next/KernelSU-Next.git            "${KSU_REF}"       "${WORK}/KernelSU-Next" false
clone_ref https://github.com/osm0sis/AnyKernel3.git                    "${AK3_COMMIT}"    "${WORK}/AnyKernel3" true

# Un clone déjà présent (build précédent) peut être sur un autre commit :
# on force le commit épinglé, puis on vérifie.
pin_commit() {  # dest sha
  local dest="$1" sha="$2"
  if [ "$(git -C "${dest}" rev-parse HEAD)" != "${sha}" ]; then
    log "Passage de ${dest} sur le commit épinglé ${sha}"
    git -C "${dest}" fetch --tags origin "${sha}"
    git -C "${dest}" checkout --detach "${sha}"
  fi
  [ "$(git -C "${dest}" rev-parse HEAD)" = "${sha}" ] || die "${dest} n'est pas sur ${sha}"
}
pin_commit "${WORK}/KernelSU-Next" "${KSU_REF}"
pin_commit "${WORK}/AnyKernel3"    "${AK3_COMMIT}"
echo "KernelSU-Next HEAD: $(git -C "${WORK}/KernelSU-Next" rev-parse HEAD) (commits=$(git -C "${WORK}/KernelSU-Next" rev-list --count HEAD))"
[ -d "${WORK}/mkbootimg/.git" ] || git clone --depth=1 --branch lineage-23.0 \
  https://github.com/LineageOS/android_system_tools_mkbootimg.git "${WORK}/mkbootimg"

# --- 4. Intégration KernelSU-Next + hooks manuels --------------------
log "Intégration KernelSU-Next (hooks manuels)"
python3 "${PROJECT_WIN}/ksunext-gts7lwifi/apply_ksu_hooks.py" \
  --kernel-dir "${WORK}/kernel" \
  --ksu-dir "${WORK}/KernelSU-Next"
cp "${PROJECT_WIN}/ksunext-gts7lwifi/ksu.config" \
  "${WORK}/kernel/arch/arm64/configs/vendor/ksu.config"

# --- 5. Configuration + compilation ----------------------------------
log "Configuration du noyau"
MAKE_ARGS=(
  O=out ARCH=arm64 SUBARCH=arm64 LLVM=1 LLVM_IAS=1
  CROSS_COMPILE=aarch64-linux-gnu- CLANG_TRIPLE=aarch64-linux-gnu-
  KCFLAGS=-Wno-error      # 4.19 + Clang récent : ne pas transformer les warnings en erreurs
)

make -C "${WORK}/kernel" "${MAKE_ARGS[@]}" \
  vendor/kona-perf_defconfig \
  vendor/samsung/kona-sec-common.config \
  vendor/samsung/gts7lwifi.config \
  vendor/ksu.config

log "Vérification des flags de config"
grep -qx "CONFIG_KSU=y"             "${WORK}/kernel/out/.config" || die "CONFIG_KSU manquant"
grep -qx "CONFIG_KSU_MANUAL_HOOK=y" "${WORK}/kernel/out/.config" || die "CONFIG_KSU_MANUAL_HOOK manquant"
grep -qx "CONFIG_CFI_CLANG=y"       "${WORK}/kernel/out/.config" || die "CONFIG_CFI_CLANG manquant"
grep -qx "CONFIG_OVERLAY_FS=y"      "${WORK}/kernel/out/.config" || die "CONFIG_OVERLAY_FS manquant"
! grep -q "^CONFIG_KSU_KPROBES_HOOK="       "${WORK}/kernel/out/.config" || die "CONFIG_KSU_KPROBES_HOOK ne doit pas être actif"
! grep -q "^CONFIG_KSU_SYSCALL_TABLE_HOOK=" "${WORK}/kernel/out/.config" || die "CONFIG_KSU_SYSCALL_TABLE_HOOK ne doit pas être actif"

log "Compilation (Image) — ça peut prendre 20 à 45 min"
make -C "${WORK}/kernel" -j"$(nproc)" "${MAKE_ARGS[@]}" Image
IMG="${WORK}/kernel/out/arch/arm64/boot/Image"
[ -s "${IMG}" ] || die "Image non produite"
strings "${IMG}" | grep -m1 "Linux version" || true

# --- 6. Empaquetage ---------------------------------------------------
DIST="${PROJECT_WIN}/out"
mkdir -p "${DIST}"
KVER="$(git -C "${WORK}/kernel" rev-parse --short=8 HEAD)"
KSU_VER="$(git -C "${WORK}/KernelSU-Next" rev-parse --short=8 HEAD)"
TAG="lineage24-$(date -u +%Y%m%d)-k${KVER}-ksu${KSU_VER}"

log "Empaquetage AnyKernel3"
AK3="${WORK}/ak3-stage"; rm -rf "${AK3}"; mkdir -p "${AK3}"
cp -r "${WORK}/AnyKernel3/META-INF" "${WORK}/AnyKernel3/tools" "${WORK}/AnyKernel3/LICENSE" "${AK3}/"
cp "${PROJECT_WIN}/ksunext-gts7lwifi/anykernel.sh" "${AK3}/anykernel.sh"
chmod +x "${AK3}/anykernel.sh"
cp "${IMG}" "${AK3}/Image"
AK3_ZIP="KernelSU-Next-gts7lwifi-${TAG}-ak3.zip"
( cd "${AK3}" && zip -r9 "${DIST}/${AK3_ZIP}" . )

# --- 7. Repack du boot.img officiel local ----------------------------
log "Repack du boot.img officiel (local)"
rm -rf "${WORK}/unpacked_boot"; mkdir -p "${WORK}/unpacked_boot"
mapfile -d '' MKBOOTIMG_ARGS < <(python3 "${WORK}/mkbootimg/unpack_bootimg.py" \
  --boot_img "${PROJECT_WIN}/boot.img" \
  --out "${WORK}/unpacked_boot" \
  --format=mkbootimg -0)
cp "${IMG}" "${WORK}/unpacked_boot/kernel"
OUT_BOOT_NAME="boot-lineage24-${TAG}-gts7lwifi-ksunext.img"
OUT_BOOT="${DIST}/${OUT_BOOT_NAME}"
python3 "${WORK}/mkbootimg/mkbootimg.py" "${MKBOOTIMG_ARGS[@]}" --output "${OUT_BOOT}"
BOOT_SIZE="$(stat -c%s "${OUT_BOOT}")"
echo "Taille boot repack : ${BOOT_SIZE} octets (max partition : 71303168)"
[ "${BOOT_SIZE}" -le 71303168 ] || die "boot.img repacké trop gros pour la partition"

# --- 8. Téléchargement optionnel de l'APK gestionnaire ----------------
SUM_FILES=("${AK3_ZIP}" "${OUT_BOOT_NAME}")
log "APK gestionnaire ${KSU_MANAGER_TAG} (vérification SHA-256)"
APK_TMP="${WORK}/${KSU_MANAGER_APK}"
if curl -fsSL "https://github.com/KernelSU-Next/KernelSU-Next/releases/download/${KSU_MANAGER_TAG}/${KSU_MANAGER_APK}" -o "${APK_TMP}"; then
  echo "${KSU_MANAGER_SHA256}  ${APK_TMP}" | sha256sum -c - || die "Empreinte de l'APK gestionnaire incorrecte : fichier refusé"
  cp "${APK_TMP}" "${DIST}/${KSU_MANAGER_APK}"
  SUM_FILES+=("${KSU_MANAGER_APK}")
else
  echo "APK gestionnaire non téléchargé (hors ligne ?) : installe-le à la main depuis la release ${KSU_MANAGER_TAG}."
fi

# --- 9. Sommes de contrôle -------------------------------------------
( cd "${DIST}" && sha256sum "${SUM_FILES[@]}" > SHA256SUMS.txt )

log "TERMINÉ"
echo "Fichiers dans C:\\tablette\\out :"
ls -la "${DIST}"
echo
echo "Ensuite : flashe le zip AnyKernel3 via Lineage Recovery (adb sideload),"
echo "puis installe l'appli gestionnaire KernelSU-Next (voir README.md)."
