Rhino 8 on Android (experimental, unofficial)
=============================================

Needs: a 64-bit ARM phone, 6 GB RAM or more, ~8 GB free storage, Android 12+.
Tested on a Samsung Galaxy A24 (Android 16). Not supported by McNeel.

1. Uninstall Termux if you have it from the Play Store (that version cannot
   run this). Install both APKs from this folder:
     termux-app_v0.118.3+github_arm64-v8a.apk
     termux-x11-universal-debug.apk
2. Developer options (tap Settings > About phone > Software information >
   Build number 7 times): turn ON "Disable child process restrictions".
   Without it Android stops Rhino after a while.
3. Download the Rhino 8 installer for Windows from rhino3d.com into Download/
   (rhino_en-us_8.x.exe). You need your own license; the 90-day evaluation works.
4. Copy this whole folder to the phone (e.g. Download/rhino-android/).
5. Open Termux and run:
     termux-setup-storage
     sh ~/storage/downloads/rhino-android/install.sh
   It takes 15-20 minutes. Keep the phone awake and plugged in.
6. Start Rhino any time with:   rhino
   then switch to the Termux:X11 app. First start takes about a minute.
7. Sign in: Licensing > Login > Copy URL, open the link in the phone's browser.

Use a mouse and keyboard (Bluetooth or USB-C) for real work.
If Rhino draws wrongly: start it with  RHINO_GL=llvmpipe rhino  (CPU drawing,
slower but safe). Close other apps before starting Rhino.
