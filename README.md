# NeuroCalm — Starter iOS Project

**Student Stress & Focus Companion**

A SwiftUI + SwiftData MVP scaffold for the NeuroCalm app: guided breathing, daily routine planning, deadline reminders, a supportive chat assistant, mood tracking, weekly streaks, and optional Apple Health integration for Mindful Minutes.

This README assumes you're new to Swift — every step is written out.

---

## 1. What you need

- **A Mac** (Xcode is Mac-only)
- **Xcode 15 or later** — free from the Mac App Store
- About 30 minutes for first-time setup

> You do **not** need a paid Apple Developer account to run this in the simulator. You only need one ($99/year) if you want to install on a real iPhone or publish to the App Store later.

---

## 2. Open the Xcode project

There's already a real `NeuroCalm.xcodeproj` in this folder — just double-click it (or run `open NeuroCalm.xcodeproj` from Terminal) to open it in Xcode. No manual project creation needed.

```
NeuroCalm/
├── project.yml                 ← source of truth for project settings (XcodeGen)
├── NeuroCalm.xcodeproj         ← generated from project.yml, safe to regenerate
├── NeuroCalm/
│   ├── NeuroCalmApp.swift
│   ├── RootView.swift
│   ├── Assets.xcassets/        ← app icon + accent color
│   ├── Models/
│   ├── Views/
│   ├── Services/
│   └── Theme/
└── NeuroCalmUITests/
    └── ScreenTourUITests.swift ← taps every tab and screenshots each screen
```

If you ever add, remove, or rename a Swift file, re-run `xcodegen generate` from this folder to regenerate `NeuroCalm.xcodeproj` (install XcodeGen once with `brew install xcodegen`). The `.xcodeproj` itself is disposable — `project.yml` is what actually defines the target, bundle ID, deployment target, and Info.plist keys.

To sanity-check the whole app visually after a change without manually clicking through the simulator, run the screen-tour UI test (⌘U in Xcode, or from Terminal):

```
xcodebuild -project NeuroCalm.xcodeproj -scheme NeuroCalm \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -resultBundlePath TourResults.xcresult test
xcrun xcresulttool export attachments --path TourResults.xcresult --output-path ./screenshots
```

That taps through Home → Breathe → Planner → Assistant → Progress and saves a screenshot of each into `./screenshots`.

---

## 3. Enable HealthKit (optional)

The `Info.plist` usage-description strings are already set up via `project.yml` (`INFOPLIST_KEY_NSHealthShareUsageDescription` / `INFOPLIST_KEY_NSHealthUpdateUsageDescription`), so `HealthKitService` won't crash when it asks for authorization. To actually let it write Mindful Minutes to Apple Health, add the capability:

1. Click your **project name** at the top of the sidebar.
2. Select the **NeuroCalm target** (middle pane).
3. Go to the **Signing & Capabilities** tab.
4. Click **+ Capability** → double-click **HealthKit**.

> If you skip this, the app still runs fine — the Settings toggle just won't be able to grant access until the capability is added.

---

## 4. Enable Notifications (optional)

No setup needed — `UserNotifications` is built into iOS. The first time the user toggles notifications on in Settings, iOS will show the permission prompt automatically.

---

## 4b. Firebase backend (Login · Team challenges)

NeuroCalm is **local-first** — everything works offline on-device (breathing, relax audio, practices, badges, the Calm Ring, solo challenges). Firebase adds the account-based features on top:

| Feature | Needs | Cost |
|---|---|---|
| Sign in (Apple / Google / school code) | Firebase **Authentication** | Free (Spark plan) |
| **Team challenges** (join-by-code + leaderboard) | Firebase **Firestore** | Free (Spark plan) |

The Firebase project is **`neurocalm-e61f4`** and `GoogleService-Info.plist` is already bundled in the app target, so `FirebaseApp.configure()` runs out of the box. To light up the account features, do the following once in the [Firebase console](https://console.firebase.google.com):

**1. Authentication** → *Sign-in method* → enable:
- **Apple**, **Google**, and **Anonymous** (Anonymous powers the school-code join).

**2. Firestore Database** → *Create database* → then set these **Rules**:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Team challenges: any signed-in user can create/join/update.
    match /teamChallenges/{id} {
      allow read, create, update: if request.auth != null;
    }
    // School lookup for the "join with a code" login.
    match /schools/{id} {
      allow read: if request.auth != null;
    }
  }
}
```

- To test the **school-code login**, add a `schools` collection with documents that have `name` and `code` fields (e.g. `{ name: "Lincoln High", code: "LINCOLN24" }`).
- **Team challenges** need no seed data — a student creates one in-app and shares the 6-character code.

**Assistant:** the app's assistant runs **on-device (Apple Intelligence)** and falls back to a built-in helper. Both are free and need no setup.

**Privacy note:** a student's private data (mood, breathing history, `CalmLog`, assistant chats) never leaves the device. Team challenges share only a member's *challenge count*.

---

## 5. Run it

1. At the top of Xcode, pick a simulator (e.g. **iPhone 17**) from the device dropdown.
2. Press **⌘R** (or the ▶ play button).
3. The simulator launches, the app builds, and NeuroCalm opens with the welcome screen.

First time: you'll go through the welcome → name → mood → goals onboarding. After that, the home dashboard appears with example tasks and deadlines already populated (from `SampleData.swift`).

---

## 6. The sections

| Section | What it does |
|---|---|
| **Home** | Greeting, mood, streak, next deadline, today's tasks, breathe + relax cards |
| **Breathe** | Animated breathing with a pattern picker (1:1, 1:2, 1:1:1, box, 4-7-8), duration, and optional spoken guidance |
| **Relax** | Guided-relaxation audio library (Shavasana + Yoga Nap), with a persistent player and bookmarks |
| **Planner** | Add and check off deadlines + today's routine tasks |
| **Assistant** | Rule-based supportive chat (no API needed) |
| **Progress** | Weekly stats, wellness score 0–100, settings gear icon |

On iPhone the bottom tab bar (`MainTabView`) shows five of these (Relax is reached from a Home card, since iOS caps the tab bar at five). On iPad — or an iPhone-size window widened on a big screen — all six show up as a persistent sidebar (`MainSplitView`), the same master-detail pattern Apple's own apps (Health, Notes, Settings) use once there's room. Both read from one shared `AppSection` list in `Views/MainSplitView.swift` (`sidebarItems` vs `tabItems`), so they can't drift out of sync. `Views/AdaptiveMainView.swift` is the one-line switch between them — it checks `horizontalSizeClass`, which SwiftUI reports as `.regular` on iPad (full-screen or a wide Split View) and `.compact` on iPhone (and on iPad in Slide Over or a narrow Split View) — so the sidebar automatically collapses to a tab bar in those narrower iPad contexts too. It also injects a shared `AudioPlayerService` so relaxation audio keeps playing as you move between sections.

Card/text/button columns are also capped at a max width (`AppTheme.maxContentWidth`, via the `.adaptiveContentWidth()` view modifier) so they stay readable and centered instead of stretching edge-to-edge on a 13" iPad — a no-op on iPhone, where the screen is already narrower than the cap.

iPad also gets landscape + all orientations (`project.yml`'s `~ipad`-suffixed orientation key); iPhone stays portrait-only, matching the mockup's design.

---

## 7. How the code is organized

**Models/** — your data. Each `@Model class` is a thing SwiftData saves to disk:
- `UserProfile`: name, goals, streak
- `MoodCheckIn`: one daily mood log
- `RoutineTask`: a task with a time
- `Deadline`: an assignment due on a date
- `BreathingSession`: a completed breathing exercise

**Views/** — each screen is a `struct` that conforms to `View`. SwiftUI re-renders these automatically when data changes.

**Services/** — anything that *isn't* UI: HealthKit, notifications, the rule-based assistant, encouragement messages.

**Theme/** — colors, gradients, the `.cardStyle()` modifier. Change these to re-skin everything at once.

---

## 8. What to build next

Suggested order, easiest → hardest:

1. **Personalize colors** in `AppTheme.swift` — try different gradients.
2. **Add more breathing techniques** in `BreathingSession.swift` (enum `BreathingTechnique`).
3. **Add more keywords/responses** in `AssistantService.swift`.
4. **Add focus music** — use `AVFoundation` to play calming loops.
5. **Teach the assistant more topics** — extend `KnowledgeBase` and the on-device prompt in `AppleIntelligenceService`.
6. **Add an Apple Watch companion** with a breathing complication.
7. **Read sleep / heart rate from HealthKit** to detect stressful days.

### Feature backlog (requested 2026-07-10)

- [x] **Health App integration** — HealthKit capability now enabled (`NeuroCalm.entitlements`); `HealthKitService` writes Mindful Sessions. Still needs a real device + the user granting Health permission to verify the write end-to-end.
- [x] **User notifications & reminders** — deadline reminders plus recurring routine-task reminders (scheduled on task creation) and a daily check-in nudge wired to the Settings Reminders toggle.
- [ ] **Admin/system push notifications** — a new category, distinct from the user-scheduled local notifications above: server-sent pushes (needs APNs + a backend) for things like new content or feature announcements, live streams on health topics, targeted at one user or the whole base. Related pushes:
  - [ ] Volunteer opportunities for high schoolers
  - [ ] Seminar announcements
- [x] **Bookmarks** — `Bookmark` SwiftData model; star relaxation tracks to pin them in a Saved section on the Relax screen.
- [x] **Guided breathing practices** — a Voice toggle speaks the phase cues (on-device TTS for now; recorded narration can drop in behind the same interface).
- [x] **Guided meditation / calming-the-mind practices (recorded audio)** — the **Relax** section: a bundled library (Shavasana 1–3, Power Nap, Yoga Nap) with a persistent player and background audio. A hosted/streamed catalog can replace the bundled files later.

Note: the push-notification and recorded-audio items need real backend/content infrastructure (APNs + a server to trigger admin-initiated pushes; hosted or bundled audio files) — bigger lifts than everything else in this list, which is why they're called out separately rather than folded into the "easiest → hardest" list above.

### Feature backlog (requested 2026-07-11)

- [ ] **Registration and Login screen** — currently there's no account system at all; `UserProfile` is a single local, unauthenticated SwiftData record. Adding real auth is a bigger structural change than it looks (needs a backend or an auth provider like Firebase/Supabase Auth to actually verify identity, not just collect a name).
  - [ ] Sign in with Apple
  - [ ] Sign in with Google
  - [ ] Sign in with School
- [ ] **School onboarding** — an *optional* step during onboarding for a student to associate their account with a school, via a school URL or a unique school code. Must stay optional — a student can finish onboarding and use the app fully without ever entering a school. This implies a school needs to exist as a record somewhere (a directory of valid school codes/URLs), which is really a sub-feature of the account system above — schools are meaningless without real accounts to attach them to, so this depends on Registration/Login shipping first, and probably a lightweight admin-side way to issue/manage school codes.
- [x] **Breathing page — guided (audio) option** — a Voice toggle speaks "Breathe in / Hold / Breathe out" in sync with the animation (on-device TTS; recorded narration can replace it later).
- [x] **Breathing page — duration + ratio picker** — pattern chips (1:1 default, 1:2, 1:1:1, box, 4-7-8) and duration chips (1/2/3/5 min); the session auto-finishes at the chosen length. Built on `BreathingRatio`/`BreathingDuration` in `Models/BreathingSession.swift`.

---

## 9. Common first-run problems

| Problem | Fix |
|---|---|
| "Cannot find type 'XYZ' in scope" after adding a new file | Re-run `xcodegen generate` — new files under `NeuroCalm/` are picked up automatically since `project.yml` sources the whole folder. |
| HealthKit toggle does nothing | Capability not enabled. See Step 3. |
| Build error about iOS deployment target | `project.yml` already sets iOS 17.0+ (SwiftData needs it) — if you changed it, re-run `xcodegen generate`. |
| App opens to blank screen | Delete the app from the simulator (long-press icon) and run again — sometimes SwiftData needs a clean install when models change. |

---

## 10. Architecture (current vs future)

```
Now (MVP — standalone, private, free)
────────────────────────────────────
SwiftUI Views ──► SwiftData (on-device) ──► Apple Health (optional)
                                       └──► Local Notifications

Later (Cloud version)
────────────────────────────────────
SwiftUI Views ──► SwiftData ──► CloudKit (Apple) or Supabase
                            └──► Apple Watch app
```

Stay standalone for v1.0 — it's faster to ship, more private, and good enough for the App Store.

---

## License

Yours. Build with it freely.

— Built as a starter scaffold for the NeuroCalm concept.
