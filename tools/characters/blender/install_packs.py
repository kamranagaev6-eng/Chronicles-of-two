"""Install MakeHuman asset pack zips into MPFB's user data.

Run: blender --background --python install_packs.py -- <zip> [<zip> ...]
"""
import os
import sys

from bl_ext.user_default.mpfb.services.assetservice import AssetService
from bl_ext.user_default.mpfb.services.locationservice import LocationService

if "--" not in sys.argv:
    print("No arguments after --")
    sys.exit(1)

zips = sys.argv[sys.argv.index("--") + 1:]
target = LocationService.get_user_data()
for z in zips:
    problem = AssetService.check_asset_pack_zip(z)
    if problem not in (None, "STRUCTURE", "MACOS"):
        print("Asset pack problem:", z, problem)
        sys.exit(2)
    err = AssetService.fix_and_extract_asset_pack_zip(z, target)
    if err is not None:
        print("Extract failed:", z, err)
        sys.exit(3)

AssetService.rescan_pack_metadata()
AssetService.update_all_asset_lists()
if not AssetService.system_assets_pack_is_installed():
    print("Warning: system_assets_pack_is_installed() returned False")
