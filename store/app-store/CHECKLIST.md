# App Store release checklist — Veha Booking Driver (iOS)

Account: **IT SOLUTION DIGITAL CO., LTD** (Team ID `9LQ2SJ97JQ`) · Bundle ID: `com.vehabooking.driver`
App Store Connect app ID: `6817576515` · Seller/company name shown on store: **Veha Booking** (permanent)
⚠️ = likely App Review rejection if skipped.

**Status:** 1.0.2 (10) submitted 1 Oct 2026 — Waiting for Review. See [Review log](#review-log).

---

## Quick guide — shipping the next update (1.0.3+)

Everything in sections 1–4 below is one-time setup and already done. For each update:

1. **Code ready** → bump `pubspec.yaml` version, e.g. `1.0.3+11` (build number must always go up, across both stores).
2. **Check** `.env` → `APP_URL=https://app.vehabooking.com` (production).
3. **Stop** any running `flutter run` (simulator or phone) — they share a build cache with the release build.
4. **Build:**
   ```bash
   flutter clean && flutter pub get
   flutter build ipa --release
   ```
5. **Verify** the archive (must print `platform IOS`, not `IOSSIMULATOR`):
   ```bash
   vtool -show-build build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app/Frameworks/objective_c.framework/objective_c | grep platform
   ```
6. **Upload:** `open build/ios/archive/Runner.xcarchive` → Organizer → **Distribute App → App Store Connect → Distribute**.
   The "Upload Symbols Failed … objective_c.framework" warning is harmless (Flutter ships that framework stripped).
7. Wait 10–30 min until TestFlight shows the build **Complete**. Optionally test it on a phone via TestFlight.
8. App Store Connect → Distribution → **+ (new version)** e.g. `1.0.3` → fill **What's New** → **Add Build** (pick the new number) → Save.
9. Check the demo account still has **future trips** → **Add for Review → Submit to App Review**.
10. Log the result in the [Review log](#review-log).

---

## 1. Account & certificates (developer.apple.com)
- [x] Apple Developer Program (organization) active
- [x] Apple Distribution certificate — created 30 Sep 2026 (Xcode › Settings › Accounts)
- [x] Free Apps agreement (active by default; paid apps would need banking + tax)
- [x] EU trader status — **not needed**: app is available in Cambodia only (Digital Services Act applies only to EU distribution)
- [x] Identifiers › App ID `com.vehabooking.driver` with **Push Notifications**
- [x] Keys › **APNs Auth Key** `PPMZ3QC952` → uploaded to Firebase (project `vehabooking-app`, app "Veha Booking Driver iOS") for **both** development and production. The `.p8` file downloads only once — keep it in a safe place, never in the repo.
- [x] Firebase iOS app Team ID set to `9LQ2SJ97JQ`
- [x] Devices › at least one iPhone registered (needed for Xcode automatic signing on a new team)

## 2. Xcode project (`ios/Runner.xcworkspace`)
- [x] Signing: Automatic, Team `9LQ2SJ97JQ` (`DEVELOPMENT_TEAM` in `project.pbxproj`)
- [x] `Runner.entitlements` → `aps-environment` (Xcode switches it to `production` on App Store export) ⚠️ no push without it
- [x] Background Modes: `location` + `remote-notification` (`Info.plist`)
- [x] iPhone only (`TARGETED_DEVICE_FAMILY = 1`) — no iPad screenshots / iPad review
- [x] `ITSAppUsesNonExemptEncryption = false` — skips the export-compliance question
- [x] `UIUserInterfaceStyle = Light` — native keyboard/alerts stay light (app default theme is Light)
- [x] `PrivacyInfo.xcprivacy` — required-reason APIs + 9 collected data types (keep in sync with App Privacy below) ⚠️ ITMS-91053
- [x] `vehabooking.test` ATS exception — local dev host only, harmless in release
- [x] `ios/Flutter/MapsKeys.xcconfig` has the iOS Maps key (git-ignored)
- [ ] Before next build: confirm the Maps key is restricted to bundle ID `com.vehabooking.driver` in Google Cloud Console

## 3. App Review requirements (guidelines) ⚠️
- [x] **Privacy Policy link inside the app** — Profile › Support › Privacy Policy (5.1.1(i), build 10+)
- [x] Privacy policy URL live: https://vehabooking.com/privacy
- [x] Support URL live: https://vehabooking.com/contact
- [x] **Demo account** `apple.review@vehabooking.com` (password in git-ignored `review_information/demo_password.txt`) — 2.1
  - [x] Separate from the Google Play review account (`play.review@…`) so the two reviewers never log each other out
  - [x] No OTP on sign-in
  - [x] Has trips assigned — **keep at least one future trip** whenever a version is in review (TX-000469, 15 Oct 2026)
- [x] Review notes explain: no sign-up, how to test, **"I've arrived" is distance-gated** (reviewer is outside Cambodia), background location, account deletion
- [ ] **iPhone screen recording of a full trip** (Start → Arrived → Meet → Drop) — have it ready in case Review asks — 2.5.4
- [x] Permission strings clear (location when-in-use / always, camera, photos)
- [x] Account deletion — not required (no in-app sign-up); notes say drivers request deletion via operator or /contact — 5.1.1(v)
- [ ] Next update: add in-app **Delete account** (needs a driver API endpoint; also expected by Google Play)
- [x] Production API, no staging URLs or placeholder text in the build
- [x] Force-update minimum version on backend ≤ submitted version

## 4. App Store Connect — listing (Distribution tab)
- [x] New App: iOS · `Veha Booking Driver` · English (U.S.) · SKU `veha-driver-ios` · Full Access
- [x] **App Information**: subtitle `Trips, pickups & live tracking` · Travel / Navigation · no third-party content
- [x] **Age rating**: all "None/No" (incl. social-media questions) → **4+** · Age category **Not Applicable**
- [x] **Pricing and Availability**: Free · **Cambodia only** · Mac ☐ · Vision Pro ☐ · Distribution **Public** (permanent once approved)
- [x] **App Privacy** published — 9 types, each *App Functionality · Linked to user · Not tracking*:
  Name, Email Address, Phone Number, Physical Address, Precise Location, Photos or Videos, User ID, Device ID, Other Data (date of birth, gender)
- [x] Version page text from `metadata/en-US/*.txt` (promo, description, keywords, URLs)
- [x] Copyright `2026 IT SOLUTION DIGITAL CO., LTD` (editable with the next version)
- [x] Screenshots: **6.5" slot** uses `screenshots/en-US-6.5/` (1284x2778); 6.9" originals in `screenshots/en-US/` (1320x2868)
  - Generator: `tool/appstore_screenshot.html?shot=1..4`; raw iPhone 17 Pro Max captures in `screenshots/source/` (email blurred)
  - Play screenshots (900x1600) are **not valid** for iOS
- [x] App Review Information: demo login, contact (+855 95 255 577 · vehabooking@gmail.com), notes from `review_information/notes.txt`
- [x] Release: **Manually release this version**

## 5. Build & upload history
- [x] 1.0.2 (9) — 30 Sep 2026 — first upload; **not submitted** (no in-app privacy link, followed system dark mode)
- [x] 1.0.2 (10) — 1 Oct 2026 — privacy link, Light default, welcome screen fix, light native UI → **submitted**

## 6. TestFlight
- [ ] Internal group `Veha Team` (automatic distribution) + testers
- [ ] Real-device test: login, push received, start trip, **lock screen 5+ min → tracking still posts**, finish → tracking stops
- [ ] Test on the oldest supported iOS (15.x) if possible

## 7. Submit
- [x] Build 10 selected · Manual release · Submitted 1 Oct 2026 11:01 (submission `a647fd3c-1348-4bee-8b6c-63eb004583d5`)
- [ ] Approved → **Release This Version**
- [ ] Rejected → read Resolution Center, fix, log it below

## Known gotchas
- **White screen on simulator/phone:** device and simulator builds share Flutter's `objective_c` native-asset cache. Fix: stop other `flutter run`, then `flutter clean`.
- **dSYM warning for `objective_c.framework`** on every upload: harmless, ignore.
- **Simulator screenshots:** set region to `en_US` (Cambodia English shows "9:41 in the morning") and override the status bar:
  `xcrun simctl status_bar <udid> override --time "2026-09-30T02:41:00.000Z" --batteryState discharging --batteryLevel 100 --cellularBars 4 --wifiBars 3 --dataNetwork wifi`
- **New team, "Communication with Apple failed":** register one iPhone (plug it in and pick it as the run target).

## Review log
| Date | Build | Result | Notes |
|---|---|---|---|
| 2026-10-01 | 1.0.2 (10) | Waiting for Review | First submission. Cambodia only, iPhone only, manual release. |
