#!/usr/bin/env python3
"""Build a deterministic Shamiko-Compat KernelSU/Magisk module zip with per-file SHA-256 checks."""

from __future__ import annotations

import hashlib
import pathlib
import sys
import zipfile

MODULE_DIR = pathlib.Path(__file__).resolve().parent
REPO_ROOT = MODULE_DIR.parent
DEFAULT_OUT = pathlib.Path("/mnt/c/tablette/out/Shamiko-Compat-v1.1.0-SM-T870.zip")

PAYLOAD_FILES = [
    "META-INF/com/google/android/update-binary",
    "META-INF/com/google/android/updater-script",
    "module.prop",
    "customize.sh",
    "verify.sh",
    "common_props.sh",
    "whitelist.sh",
    "post-fs-data.sh",
    "service.sh",
    "action.sh",
    "cleanup.sh",
    "uninstall.sh",
    "sepolicy.rule",
]

FIXED_ZIP_TIME = (2026, 11, 15, 20, 52, 0)


def normalize_lf(data: bytes) -> bytes:
    """Normalize CRLF line endings to LF for Android/Linux shell scripts."""
    return data.replace(b"\r\n", b"\n")


def add_zip_bytes(zf: zipfile.ZipFile, arcname: str, data: bytes, mode: int = 0o644) -> None:
    """Write a deterministic entry with normalized Unix permissions."""
    info = zipfile.ZipInfo(arcname, date_time=FIXED_ZIP_TIME)
    info.create_system = 3  # Unix
    info.external_attr = (0o100000 | mode) << 16
    zf.writestr(info, data, compress_type=zipfile.ZIP_DEFLATED)


def verify_zip_hashes(zip_path: pathlib.Path) -> None:
    """Verify every payload entry inside the generated zip matches its .sha256 sidecar."""
    with zipfile.ZipFile(zip_path, "r") as zf:
        names = set(zf.namelist())
        for rel in PAYLOAD_FILES:
            if rel not in names or f"{rel}.sha256" not in names:
                raise RuntimeError(f"Missing entry or sidecar in zip: {rel}")
            actual = hashlib.sha256(zf.read(rel)).hexdigest()
            recorded = zf.read(f"{rel}.sha256").decode("ascii").strip()
            if actual != recorded:
                raise RuntimeError(f"Checksum mismatch for {rel}: {actual} != {recorded}")


def main() -> int:
    out_zip = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else (
        DEFAULT_OUT if DEFAULT_OUT.parent.exists() else REPO_ROOT / "out" / "Shamiko-Compat-v1.1.0-SM-T870.zip"
    )
    out_zip.parent.mkdir(parents=True, exist_ok=True)

    with zipfile.ZipFile(out_zip, "w") as zf:
        for rel in PAYLOAD_FILES:
            src = MODULE_DIR / rel
            if not src.is_file():
                raise FileNotFoundError(f"Missing module source file: {src}")
            raw = normalize_lf(src.read_bytes())
            digest = hashlib.sha256(raw).hexdigest().encode("ascii")
            mode = 0o755 if rel.endswith(".sh") or rel.endswith("update-binary") else 0o644
            add_zip_bytes(zf, rel, raw, mode=mode)
            add_zip_bytes(zf, f"{rel}.sha256", digest, mode=0o644)

    verify_zip_hashes(out_zip)
    zip_sha = hashlib.sha256(out_zip.read_bytes()).hexdigest()
    sha_file = out_zip.with_suffix(out_zip.suffix + ".sha256")
    sha_file.write_text(f"{zip_sha}  {out_zip.name}\n", encoding="utf-8")

    print(f"Built : {out_zip} ({out_zip.stat().st_size} bytes)")
    print(f"SHA256: {zip_sha}")
    print(f"Files : {len(PAYLOAD_FILES)} payload + {len(PAYLOAD_FILES)} .sha256 verified OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
