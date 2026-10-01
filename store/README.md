# Store release kit — Veha Booking Driver

Everything needed to ship the app to both stores. Each store has its own
console, asset sizes, review rules and upload tool, so each has its own folder.

```
store/
  app-store/                      # Apple — App Store Connect / Transporter / fastlane deliver
    CHECKLIST.md                  # iOS release tracker (start here)
    metadata/en-US/*.txt          # name, subtitle, keywords, description, URLs...
    metadata/review_information/  # App Review contact + notes (demo login NOT committed)
    screenshots/en-US-6.5/        # 6.5" iPhone screenshots (1284x2778) ← uploaded to App Store Connect
    screenshots/en-US/            # 6.9" iPhone screenshots (1320x2868)
    screenshots/source/           # raw simulator captures used by tool/appstore_screenshot.html
  google-play/                    # Google — Play Console / fastlane supply
    CHECKLIST.md                  # Android release tracker
    metadata/android/en-US/       # title, short/full description, changelogs, images
    source/                       # raw captures + videos (was /play-assets)
```

| | App Store | Google Play |
|---|---|---|
| Package / bundle ID | `com.vehabooking.driver` | `com.vehabooking.driver` |
| Build | `flutter build ipa --release` | `flutter build appbundle --release` |
| Upload | Xcode Organizer or Transporter | Play Console (or `fastlane supply`) |
| Test track | TestFlight | Internal testing |
| Account | IT SOLUTION DIGITAL CO., LTD (Team ID `9LQ2SJ97JQ`) | — |
| Languages | en-US (Khmer is **not** an App Store locale) | en-US, km-KH possible |

The folder layouts match fastlane `deliver` / `supply`, so uploads can be
automated later without moving files. Manual copy/paste from the `.txt` files
works just as well.

Version lives in `pubspec.yaml` (`version: 1.0.2+9` → name `1.0.2`, build `9`).
Bump the `+N` build number for every upload to either store.
