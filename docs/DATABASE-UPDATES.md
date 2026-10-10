# Publishing database updates

How to publish an update to the Saklolo on-device database (keywords and first-aid scripts). Written for Jayson, the only publisher. Everything here comes from `tools/dbtool.sh`, `tools/dbtool/main.swift`, and the files under `Saklolo/Services/Database/`.

## 1. What the database is and how the app uses it

- One file, `database.json`: an integer `version` and a `scripts` array. Each script has `id`, `title`, `keywords`, `steps`, `source`. Script order is classifier priority (first script with a matching keyword wins). `general` is the fallback and its keywords are ignored.
- The copy in the app bundle (`Saklolo/Resources/database.json`, version 1) is the baseline and the fallback.
- A downloaded update is verified (signature, then the validator in section 4) and cached in one file under Application Support. The cache is re-verified on every load.
- The highest version wins, and a newer one must be strictly greater than the one in use. Equal or older files are ignored. A cache not newer than the bundle (for example after an app update) is ignored.
- Failure is silent. A bad, missing, or unreachable update changes nothing the person sees, and the bundle is always there.
- The check never runs on the alert path. It starts in the background when there is signal and the app comes to the foreground (or signal returns), at most once per 6 hours. The alert and the classifier only read an already-loaded snapshot. A guide that is already open keeps the steps it opened with.

## 2. One-time setup

1. Generate the keypair and write the public half into the app:

   ```
   tools/dbtool.sh keygen --public-out Saklolo/Resources/database-public-key.txt
   ```

2. The private key goes to `~/.saklolo/database-signing-key` by default (directory mode 700, file mode 600). Use `--key <path>` for another location. The tool refuses to put it inside the repo and refuses to overwrite an existing key.
3. Back it up now, somewhere private and separate from this Mac. Never commit it.
4. Commit only `Saklolo/Resources/database-public-key.txt`, and ship an app build that includes it.

The public key is bundled (`Saklolo/Resources/database-public-key.txt`), so the app checks for updates. Without that file the app would make no update request at all and use the bundle only. Until you publish a signed `database/database.json`, the check gets a 404 and the bundle stays in use.

## 3. Publishing an update

1. Work on a copy of the current database (for example the last file in `database/`, or `Saklolo/Resources/database.json`). Do not bump the version inside the bundled file itself: `sign` rejects any version not greater than the bundled one.
2. Edit keywords or steps in the copy. Keep all five known scripts.
3. Raise `version` above the bundled version and above the last published version. The first update must be 2 or more.
4. Validate and sign:

   ```
   tools/dbtool.sh sign path/to/database.json
   ```

   Add `--key <path>` if the key is not at the default path, or `--out <dir>` to write somewhere other than `database/`. `sign` runs the app's own validator, refuses an invalid file or a version that is not newer than the bundled or already-published one, signs the exact bytes, and writes `database/database.json` and `database/database.json.sig`.
5. Check the pair against the public key:

   ```
   tools/dbtool.sh verify database/database.json database/database.json.sig Saklolo/Resources/database-public-key.txt
   ```

   Expected output: `ok: version N, signature valid, 5 scripts`.
6. Commit both files together and push to `main`. The app fetches these URLs:

   - `https://raw.githubusercontent.com/jisundr/saklolo-ph/main/database/database.json`
   - `https://raw.githubusercontent.com/jisundr/saklolo-ph/main/database/database.json.sig`

   If a phone catches the pair half-published, verification fails and it is ignored; the next check picks the pair up.
7. Do not edit `database/database.json` by hand after signing. Any change to the bytes breaks the signature.

## 4. What the app rejects, and why

Rejected files are ignored and the database in use stays. Rules are in `DatabaseValidator.swift`, applied in this order:

- Signature missing, not base64 of 64 bytes, over 256 bytes, or not made by the bundled key. Checked before the JSON is parsed.
- Response over 256 KB, a non-200 status, or a non-HTTPS URL.
- JSON that does not match the schema (malformed).
- `version` below 1, or not strictly greater than the version in use.
- Duplicate script ids.
- A missing known script. Known ids: `fall`, `bleeding`, `unconscious`, `head_injury`, `general`. All five must be present, so an update cannot remove content.
- Per script:
  - empty title;
  - empty keywords (non-`general`), or a blank keyword;
  - not 3 to 6 steps, or a blank step;
  - any step containing "count" (case-insensitive substring, so "account" also trips it), because the app does not count compressions;
  - source that lacks "IFRC" or contains "TODO";
  - first step that lacks "help" or "911".

An unknown script id is not an error: that script is dropped and the rest of the file still applies.

## 5. Rollback and key loss

- Rollback: there is no way to push a lower version, because phones ignore lower and equal versions. To undo a bad update, publish a corrected file with a higher version number.
- If the private key is lost or leaked: updates signed with the old key cannot be replaced remotely. A leaked key means someone else can sign files that phones accept (they still must pass the validator). The fix is a new app release that bundles a new public key, with a new keypair generated first. Phones on the old build keep trusting the old key until they update the app. There is no remote key rotation.

## 6. Review first-aid wording before signing

Steps update without an App Store review, so nothing else checks them. Have someone with first-aid training read any change to step wording before you sign it. The validator only checks shape (counts, source tag, first step), not whether the advice is right.

## 7. Known unverified items

- How long `raw.githubusercontent.com` takes to serve a newly pushed file (it is cached; the lag has not been measured).
- Airplane-mode launch with a cached update on a real phone.
- The live signal-return trigger (`NWPathMonitor`) has no unit test; it was meant to be checked by hand with the public key present.
