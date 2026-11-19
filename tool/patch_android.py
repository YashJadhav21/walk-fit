"""Applies WalkFit's Android settings on top of the files `flutter create` makes.

Run from the project root after `flutter create`.
"""
import pathlib
import re
import shutil

root = pathlib.Path(__file__).resolve().parent.parent
android = root / "android"
manifest = android / "app/src/main/AndroidManifest.xml"

PERMISSIONS = [
    "android.permission.INTERNET",
    "android.permission.ACCESS_COARSE_LOCATION",
    "android.permission.ACCESS_FINE_LOCATION",
    "android.permission.FOREGROUND_SERVICE",
    "android.permission.FOREGROUND_SERVICE_LOCATION",
    "android.permission.POST_NOTIFICATIONS",
    "android.permission.WAKE_LOCK",
]

text = manifest.read_text()
lines = "".join(
    f'    <uses-permission android:name="{p}"/>\n'
    for p in PERMISSIONS
    if p not in text
)
text = re.sub(r"(<manifest[^>]*>\n)", r"\1" + lines.replace("\\", "\\\\"), text, count=1)
text = re.sub(r'android:label="[^"]*"', 'android:label="WalkFit"', text, count=1)
manifest.write_text(text)
print(text)

# Icons (launcher + notification).
overlay = root / "android_overlay/res"
res = android / "app/src/main/res"
for f in overlay.rglob("*"):
    if f.is_file():
        dest = res / f.relative_to(overlay)
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(f, dest)
        print("copied", dest.relative_to(root))

# gradle.properties: AndroidX (required by geolocator).
props = android / "gradle.properties"
p = props.read_text()
if "android.useAndroidX" not in p:
    p += "\nandroid.useAndroidX=true\n"
props.write_text(p)

# Some plugins (permission_handler) need a newer compileSdk than Flutter's
# default. compileSdk only affects compilation, not which phones can install.
gradle = android / "app/build.gradle.kts"
g = gradle.read_text()
g = g.replace("compileSdk = flutter.compileSdkVersion", "compileSdk = 37")
gradle.write_text(g)
print(g)
