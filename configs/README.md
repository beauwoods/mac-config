# Config Files — Capture from Old Machine

These config files need to be exported from your current machine
before deployment day and committed to this repo.

## iTerm2 profile
- Open iTerm2
- Go to Preferences > General > Preferences
- Enable "Load preferences from a custom folder or URL"
- Set path to: `~/Documents/GitHub/dotfiles/configs/iterm2`
- Click "Save Current Settings to Folder"
- Commit the resulting `.json` file

## iStat Menus preferences
- Click iStat Menus icon in menu bar
- Open Preferences > Export/Import
- Export to: `~/Documents/GitHub/dotfiles/configs/istat/iStatMenusSettings.ismp`
- Commit the file

## VS Code
- Settings Sync is handled via GitHub account (no file needed here)
- If you have local snippets or keybindings not in sync:
  - Copy from `~/Library/Application Support/Code/User/`
  - Commit relevant files to `configs/vscode/`

## Apple Configurator 2 profile (if using)
- Build `.mobileconfig` for PPPC privacy permissions
- Export and save to `profiles/privacy_permissions.mobileconfig`
- Commit the file
