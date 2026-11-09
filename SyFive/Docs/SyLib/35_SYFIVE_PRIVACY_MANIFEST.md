# SyFive: a privacy manifest, as Syderal and Score It \*

**Status:** **35.1 done and checked, 8 November 2026; open for V1** (Pops, at the next archive). The
ledger row is filed when V1 passes. Version 1.0, 8 November 2026.

**Scope:** `syfive-ios`. One new file in the app's folder. SyLib is read, not changed.

**Ship with every prompt:** `00_DECISION_LEDGER.md`, `00A_STUDIO_CONVENTIONS.md` (v1.12),
`00B_SYFIVE_GUARDRAILS.md`, this document. `00A` §6: the session's row goes at the top of §5. §7:
`00B`'s pinned command. §8: fix your own errors and warnings without stopping.

---

## 1. Why

Found on 8 November 2026, comparing Score It \* with SyFive and Syderal (Score It \* `27`):
**SyFive has no `PrivacyInfo.xcprivacy`**, though Syderal and Score It \* each ship one. App Store
Connect expects an app to declare, with an approved reason, each "required reason" API it uses,
SyLib's included, since SyLib is compiled into the app.

## 2. Decision (Pops, 8 November 2026)

**2.1 SyFive ships a privacy manifest, the same as Syderal's** (D-195). What it declares, read from
SyFive's code and the SyLib modules it imports on 8 November 2026:

| Declared | Reason | Why SyFive needs it |
|---|---|---|
| No tracking, no tracking domains, no collected data types | | Nothing leaves the device but the player's own iCloud data, which the developer never receives; as Syderal and Score It \* |
| `NSPrivacyAccessedAPICategoryUserDefaults` | `CA92.1` (the app's own defaults) | SyFive's settings, and SyLib's (`AppUpdateState`'s acknowledged version, commentary, theme). No app group |
| `NSPrivacyAccessedAPICategorySystemBootTime` | `35F9.1` (measuring time within the app) | SyLibFeel's `FeelAudioEngine` reads `ProcessInfo.systemUptime`; SyFive links SyLibFeel |

**Not declared:** file timestamps. SyLibCache's `ImageCache` reads files' modification dates, and
SyFive lists SyLibCache among its package products, but no SyFive file imports it. If SyFive ever
uses `ImageCache`, add `NSPrivacyAccessedAPICategoryFileTimestamp` with `C617.1` (files in the app's
own container).

---

## 3. Task 35.1 · The manifest

- **Inputs:** §2; for reference only, Syderal's `Syderal/Syderal/PrivacyInfo.xcprivacy`.
- **Change:** a new `SyFive/PrivacyInfo.xcprivacy` (beside `Info.plist`), exactly:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSPrivacyTracking</key>
	<false/>
	<key>NSPrivacyTrackingDomains</key>
	<array/>
	<key>NSPrivacyCollectedDataTypes</key>
	<array/>
	<key>NSPrivacyAccessedAPITypes</key>
	<array>
		<dict>
			<key>NSPrivacyAccessedAPIType</key>
			<string>NSPrivacyAccessedAPICategoryUserDefaults</string>
			<key>NSPrivacyAccessedAPITypeReasons</key>
			<array>
				<string>CA92.1</string>
			</array>
		</dict>
		<dict>
			<key>NSPrivacyAccessedAPIType</key>
			<string>NSPrivacyAccessedAPICategorySystemBootTime</string>
			<key>NSPrivacyAccessedAPITypeReasons</key>
			<array>
				<string>35F9.1</string>
			</array>
		</dict>
	</array>
</dict>
</plist>
```

  The `SyFive` folder is synchronized, and its only membership exception is `Info.plist`, so the
  file joins the SyFive target as a resource with no project edit. Don't edit `project.pbxproj`.
- **Must not touch:** anything else.
- **Done when:**
  1. The build passes with no new warnings (`00A` §8).
  2. `00B`'s pinned command passes at its previous total, no tests added or removed.
  3. The built `SyFive.app` holds `PrivacyInfo.xcprivacy` at its top level (checked in the build
     products, by path).
  4. The row is at the top of §5.
  5. Pops checks V1.

## 4. Validation (Pops)

| # | Check | Pass |
|---|---|---|
| V1 | Archive SyFive; in the Organizer, the archive's ⋯ › Generate Privacy Report | The report lists SyFive's UserDefaults (CA92.1) and System Boot Time (35F9.1), and no tracking; the next upload to App Store Connect brings no missing-API-declaration email |

## 5. Results log

| Task / V | Date | Result | Totals | Notes |
|---|---|---|---|---|
| 35.1 | 8 Nov 2026 | complete (the agent); **checked by Claude against the tree**: the file matches §3 byte for byte, `project.pbxproj` untouched, nothing else changed. The staging was Xcode's, not a concern. V1 waits for Pops's next archive | Before: `** TEST SUCCEEDED **`, 23 test cases passed, 0 failed. After: `** TEST SUCCEEDED **`, 23 passed, 0 failed, identical case list (xcodebuild prints no summary total; counted from the run's `Test case … passed` lines). Destination `platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.6` | **Files:** new `SyFive/PrivacyInfo.xcprivacy` (816 bytes, extracted from §3's XML block by script, `plutil -lint` OK); this row. `project.pbxproj` untouched. **Build:** `BuildProject` passed before and after, 0 warnings both times; no fixes needed. **Bundle:** `~/Library/Developer/Xcode/DerivedData/SyFive-ashdkjxedghcihbnensovofiuvrf/Build/Products/Debug-iphonesimulator/SyFive.app/PrivacyInfo.xcprivacy` exists at the top level, byte-identical to the source. **Git (read-only):** `git status`, `git branch --list`, `git status --short`, `git diff --stat`. **Report:** after the file was created, `git status` showed it staged (`A`), and 34's unstaged edit was staged too; this session ran no git write (Xcode's auto-add, or Pops?). Left as found. Staged 33–35 at start were taken as Pops's docs. V1 is Pops's |

## 6. Ledger row (Claude files it when 35 closes)

| ID | Ruling | Source |
|---|---|---|
| D-195 | **SyFive ships a privacy manifest, as Syderal and Score It \***: no tracking, no collected data types; UserDefaults (`CA92.1`) and system boot time (`35F9.1`, SyLibFeel's audio clock). File timestamps only if SyFive ever uses SyLibCache's `ImageCache` (`C617.1`). *Why:* found missing on 8 Nov 2026; App Store Connect expects every required-reason API declared. | `35 §2` (Pops, 8 Nov 2026) |

## Changelog

| Version | Date | Change |
|---|---|---|
| 1.0 | 8 Nov 2026 | First version, from Score It \* `27`'s comparison of the apps |
