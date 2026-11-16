# iPhone: show caller name (Call Directory) — setup on a Mac

The Swift files here are written but **not added to the Xcode project and not
built or tested** (they were written on Windows). iOS needs a native
extension, an Apple Developer account and a TestFlight/App Store build; the
website cannot do this. Do these steps once on a Mac with Xcode:

1. Open `ios/Runner.xcworkspace`.
2. **File > New > Target > Call Directory Extension**. Name it `CallDirectory`
   (bundle id `com.sabtawya.sabtawya.CallDirectory`). Delete the generated
   `CallDirectoryHandler.swift` and add `ios/CallerId/CallDirectoryHandler.swift`
   to the new target instead.
3. **App Group**: on both the `Runner` and `CallDirectory` targets add the
   capability *App Groups* with `group.com.sabtawya.sabtawya` (create it in
   the Apple Developer portal first).
4. Add `ios/CallerId/CallerIdChannel.swift` to the `Runner` target. In
   `Runner/AppDelegate.swift`, inside `didInitializeImplicitFlutterEngine`, add:
   ```swift
   CallerIdChannel.register(with: engineBridge.applicationRegistrar.messenger())
   ```
   (If that accessor does not exist in your Flutter version, use the
   registrar's messenger the way the other plugins get theirs.)
5. Build to a real iPhone (the extension does not run in the simulator).
6. On the phone: Settings > Phone > Call Blocking & Identification: switch on
   **سبتاوية**. Then in the app: Settings > show caller name.

Notes
- Only numbers with a country code are matched (`2010…`); the Dart side
  already sends them that way. Landlines written without a code are skipped.
- iOS decides when the list is loaded; a new list can take a moment to apply.
- The numbers live only in the App Group file on the phone; switching the
  feature off, or signing out, empties it.
