# Pause Here — Complete These Steps

Bootstrap has finished installing all apps. Complete the items below,
then return to the terminal and press Enter to continue.

---

## 1. Adobe Creative Cloud (~5 min)
Open Adobe Creative Cloud → sign in → install Acrobat, Photoshop, Lightroom.

## 2. SetApp (~3 min)
Open SetApp → sign in → install: Paste, CleanMyMac, Timing, iStat Menus.

## 3. Little Snitch (~5 min)
- Open Little Snitch → enter license key (1Password: Little Snitch License)
- Settings > Security → enable "Allow access via Terminal"
- Rule Groups sidebar > + > Subscribe to Rule Group (add each URL):
  - https://frabjous-cucurucho-6b35d1.netlify.app/core_os_networking_security.lsrules
  - https://frabjous-cucurucho-6b35d1.netlify.app/misc_apps.lsrules
  - https://frabjous-cucurucho-6b35d1.netlify.app/apple_apps.lsrules
  - https://frabjous-cucurucho-6b35d1.netlify.app/adobe.lsrules
  - https://frabjous-cucurucho-6b35d1.netlify.app/browsers.lsrules
  - https://frabjous-cucurucho-6b35d1.netlify.app/microsoft_google.lsrules

## 4. 1Password (~2 min)
Open 1Password → sign in → Settings > Developer → enable "Use the SSH agent".

## 5. Trackpad Scroll Direction
System Settings > Trackpad > Scroll & Zoom → turn off "Natural Scrolling".
(The `defaults write` for this setting does not persist through reboot on macOS Tahoe —
toggle it here so macOS syncs it properly.)

## 6. Mail Layout (~1 min)
Mail.app is sandboxed on macOS Tahoe — preferences can only be set from within the app.
Open Mail, then configure:

- **Mail > Settings > Viewing**: enable "Organize by conversation"
- **Mail > Settings > Composing**: uncheck "Include original message in reply"
- **View menu**: ensure Toolbar is visible
- **View > Favorites Bar**: hide (or leave visible if preferred)
- **Compose window**: show CC, BCC, Priority fields; show Format Bar
- **Mail > Settings > General**: set notification sound to None
- **Swipe**: leave default (archive on swipe)

The migration report will verify these settings were applied correctly.

---

When all done, return to the terminal and press Enter.
