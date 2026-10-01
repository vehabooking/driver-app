# Google Play release checklist — Veha Booking Driver (Android)

Package: `com.vehabooking.driver` · Upload key: `android/key.properties` (never commit the keystore)

## 1. Build
- [ ] Bump build number in `pubspec.yaml` (`+N` = versionCode, must be higher than last upload)
- [ ] `.env` + Maps key point at production
- [ ] `flutter build appbundle --release` → `build/app/outputs/bundle/release/app-release.aab`
- [ ] Play App Signing enrolled (upload key ≠ app signing key; SHA-1 of **app signing key** added to Firebase + Maps key restrictions)

## 2. Store listing (`metadata/android/en-US/`)
- [ ] `title.txt` (≤30) · `short_description.txt` (≤80) · `full_description.txt` (≤4000)
- [x] `images/icon.png` 512x512
- [x] `images/featureGraphic.png` 1024x500
- [ ] `images/phoneScreenshots/` — 2–8 images, pick finals from `source/` and name `1_*.png`, `2_*.png`… in display order
- [ ] `video.txt` — YouTube URL (optional)
- [ ] `changelogs/<versionCode>.txt` for each release (≤500)
- [ ] Optional: `km-KH/` listing in Khmer

## 3. App content (Policy › App content)
- [ ] Privacy policy URL
- [ ] App access → demo credentials with OTP disabled
- [ ] Data safety form (Location, personal info, photos, device ID)
- [ ] **Location permissions declaration** for background location + video (`source/tracking-play-console.mp4`)
- [ ] **Foreground service** declaration (`flutter_foreground_task`, type location) + video
- [ ] Content rating questionnaire · Target audience (18+) · Ads: none
- [ ] Account deletion URL (Play requires one for apps with accounts)

## 4. Release
- [ ] Internal testing → test on real device (background tracking, push)
- [ ] Closed testing if required (new personal accounts: 12 testers / 14 days)
- [ ] Production → staged rollout %

## Release log
| Date | Version | Track | Result | Notes |
|---|---|---|---|---|
| | | | | |
