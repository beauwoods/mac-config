# SSH Keys

Shell SSH keys are captured here by `preflight.sh` from `~/.ssh/`.

## Strategy

Private keys should be stored in **1Password**, not committed to this repo
— even a private GitHub repo is a weaker security boundary than a
dedicated secrets manager. The workflow is:

- Public keys (`*.pub`) → commit to this repo (safe to share)
- `~/.ssh/config` → commit to this repo (no secrets)
- Private keys → store in 1Password as SSH Key items
- On new machine → 1Password SSH Agent serves keys directly; no key files
  needed on disk at all

---

## Step 1: Store each private key in 1Password (old machine, before freeze)

For each private key in `~/.ssh/`:

1. Open **1Password** and create a new item: **+ New Item > SSH Key**
2. Give it a descriptive name matching the key's purpose
   (e.g. "SSH Key — GitHub", "SSH Key — DigitalOcean VPS")
3. In the **Private Key** field, click the import icon and select the
   key file from `~/.ssh/` — or paste the contents directly
4. 1Password will auto-populate the public key and fingerprint
5. Add a note with where this key is authorized
   (e.g. "GitHub account", "root@147.182.216.55")
6. Save the item

Repeat for every private key. When done, verify each item shows the
correct fingerprint by comparing with:
```bash
ssh-keygen -lf ~/.ssh/your_key
```

---

## Step 2: Enable the 1Password SSH Agent (old machine — verify it works first)

1. Open **1Password > Settings > Developer**
2. Enable **"Use the SSH agent"**
3. Enable **"Integrate with 1Password CLI"** (optional but useful)
4. Edit `~/.ssh/config` to use the 1Password agent socket.
   Add this at the top of the file:

```
Host *
  IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
```

5. Test that the agent can see your keys:
```bash
ssh-add -l
```
You should see your key fingerprints listed. If prompted, approve in
1Password.

6. Test an actual connection:
```bash
ssh -T git@github.com
```

Once this works on the old machine, commit the updated `~/.ssh/config`
(with the IdentityAgent line) to this repo. On the new machine, no key
files will be needed — 1Password serves everything.

---

## Step 3: Restore on new machine (deployment day)

The Ansible playbook copies `configs/ssh/config` to `~/.ssh/config` and
sets permissions. Since private keys live in 1Password, no key files need
to be restored. The sequence is:

1. Install 1Password (Stage 2 of MANUAL_STEPS.md) and sign in
2. Enable the SSH agent: **1Password > Settings > Developer > Use the SSH agent**
3. Run Ansible — it will restore `~/.ssh/config` with the IdentityAgent line
4. Test: `ssh-add -l` — your keys should appear after approving in 1Password
5. Test a real connection: `ssh -T git@github.com`

No copying of key files, no `chmod 600` dance, no risk of accidentally
committing a private key.

---

## Termius keys

Termius stores keys in its own encrypted database, separate from `~/.ssh/`.
Export and store these in 1Password as SSH Key items using the same
process above, then import into Termius on the new machine:

**Export from old machine:**
1. Open Termius > Preferences > Keychain
2. Select each key > Export > save the file temporarily
3. Create a 1Password SSH Key item for it (Step 1 above)
4. Delete the exported file once it's in 1Password

**Import to new machine:**
1. Open Termius after install and sign in
2. Go to Preferences > Keychain > Import
3. You can either: export from 1Password temporarily and import, or
   configure Termius to use the 1Password SSH agent directly:
   Termius > Preferences > Keychain > Use SSH agent

---

## What's in this directory

After preflight runs, this directory contains:

- `README.md` — this file
- `config` — SSH client config (commit this; it now contains the
  IdentityAgent line pointing to 1Password)
- `*.pub` — public keys (safe to commit)
- Private key files may also be here from preflight capture — these are
  **superseded by 1Password** and can be deleted from the repo once
  you've verified 1Password serves them correctly via `ssh-add -l`
