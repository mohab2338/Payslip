# Salary Tracker (Flutter + Firebase)

Track your salary, a savings goal, and every purchase within a pay cycle that
starts on whatever day you choose — not a fixed calendar month. Data lives in
Firebase (Auth + Firestore), so your history follows you across devices, and
you can export any past month as a CSV.

## Features

- Email/password sign-up with fingerprint (biometric) unlock afterwards
- Light, modern UI (Poppins font, soft cards, progress ring)
- Enter salary + savings target → app shows what you're "allowed to spend"
- Log purchases; see amount spent so far and spent-percentage of your allowance
- Custom cycle start day (e.g. the 25th of each month, not the 1st)
- Full history of previous cycles, stored in Firestore
- Export any month's data (salary, saving goal, items) as a CSV file to share

---

## 1. Project layout

```
salary_tracker/
├── lib/
│   ├── main.dart              # entry point, auth/lock/setup routing
│   ├── firebase_options.dart  # PLACEHOLDER — regenerate, see step 3
│   ├── theme.dart
│   ├── models/                # ExpenseItem, MonthData
│   ├── services/               # Auth, Firestore, biometrics, cycle math, export
│   ├── widgets/                # SpendRing, StatCard
│   └── screens/                 # Auth, Setup, Home, AddItem, History, MonthDetail, Settings
├── android_overlay/            # The few Android files we customize (see note below)
├── .github/workflows/android.yml  # CI: builds debug + release APK
└── pubspec.yaml
```

> **Note on the Android folder:** this project intentionally does **not**
> commit a full `android/` folder. Android build tooling (Gradle, the
> Android Gradle Plugin, Kotlin) has strict, fast-moving version
> requirements tied to whatever Flutter version builds it — a folder
> generated for one Flutter release can fail to build with a newer one.
> Instead, `.github/workflows/android.yml` generates a brand-new `android/`
> folder from scratch on every run, using Flutter's own template for
> whichever Flutter version the workflow installs — guaranteeing the
> versions always match. It then copies in the handful of files under
> `android_overlay/` (fingerprint permissions, the `MainActivity` class
> `local_auth` needs, and the Firebase Gradle plugin) on top of that fresh
> project. You never need to touch Gradle/AGP/Kotlin versions yourself.

---

## 1. What you need

Just two free accounts — nothing to install on your machine:

- A **Firebase** account (console.firebase.google.com) — sign in with any Google account.
- A **GitHub** account, and optionally the **GitHub Desktop** app
  (desktop.github.com) if you don't want to type any git commands.

Everything below is done by clicking around in the Firebase console and
editing two text files in this project — no terminal, no Flutter SDK, no
Android Studio required. GitHub Actions (already configured in this repo)
does the actual building for you.

---

## 2. Create the Firebase project

1. Go to https://console.firebase.google.com → **Add project** → give it a
   name (e.g. `salary-tracker`) → finish the wizard (Google Analytics is
   optional, skip it if you like).
2. **Enable email/password sign-in:**
   Left sidebar → **Build → Authentication** → **Get started** → click
   **Email/Password** in the provider list → toggle **Enable** → **Save**.
3. **Create the database:**
   Left sidebar → **Build → Firestore Database** → **Create database** →
   choose **Start in production mode** → pick a region → **Enable**.
4. **Lock the database down to each user's own data:**
   Still in Firestore, go to the **Rules** tab, delete everything there, and
   paste this in its place:

   ```
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /users/{userId} {
         allow read, write: if request.auth != null && request.auth.uid == userId;

         match /months/{monthId} {
           allow read, write: if request.auth != null && request.auth.uid == userId;
         }
       }
     }
   }
   ```
   Click **Publish**.

---

## 3. Register the Android app and get your config

1. In the Firebase console, click the **gear icon (⚙) → Project settings**.
2. Scroll to **Your apps** → click the **Android icon** to add an app.
3. For **Android package name**, enter exactly:
   ```
   com.example.salary_tracker
   ```
   (This must match the `--project-name`/`--org` combination the workflow
   passes to `flutter create` — already set to produce exactly this
   application id, in `.github/workflows/android.yml`. Don't change this
   package name unless you also update that workflow file to match.)
4. Nickname is optional. Leave the SHA-1 field empty (only needed for
   Google Sign-In, which this app doesn't use). Click **Register app**.
5. Click **Download google-services.json**. Save it somewhere you can find
   it.
6. Click **Next** → **Next** → **Continue to console** (you can skip the
   SDK code snippets it shows you — the project already has all that code).

### 3a. Put the downloaded file in the project

Move/copy the `google-services.json` you just downloaded into the project
folder at exactly this path (create the `android/app/` folders if they
don't exist yet in your copy of the project — that's expected, since the
Android project itself is generated by the workflow, not committed here):
```
salary_tracker/android/app/google-services.json
```

### 3b. Fill in lib/firebase_options.dart

Open the `google-services.json` file you downloaded in any text editor —
it's plain JSON. You'll see something like this (values shortened here):

```json
{
  "project_info": {
    "project_number": "123456789012",
    "project_id": "salary-tracker-xxxxx",
    "storage_bucket": "salary-tracker-xxxxx.firebasestorage.app"
  },
  "client": [
    {
      "client_info": {
        "mobilesdk_app_id": "1:123456789012:android:abcd1234efgh5678"
      },
      "api_key": [
        { "current_key": "AIzaSyABCDEFG-your-real-key-here" }
      ]
    }
  ]
}
```

> **Note on `storage_bucket`:** newer Firebase projects use the format
> `your-project-id.firebasestorage.app`; older ones use
> `your-project-id.appspot.com`. Either is fine — **copy the value exactly
> as it appears in your own `google-services.json`**, don't type it out by
> hand or guess the pattern.

Now open `salary_tracker/lib/firebase_options.dart` in a text editor and
replace the placeholder values in the `android` block only, using the
matching fields from the JSON:

| In `firebase_options.dart`   | Comes from `google-services.json`              |
|-------------------------------|-------------------------------------------------|
| `apiKey`                      | `client[0].api_key[0].current_key`               |
| `appId`                       | `client[0].client_info.mobilesdk_app_id`         |
| `messagingSenderId`           | `project_info.project_number`                    |
| `projectId`                   | `project_info.project_id`                        |
| `storageBucket`               | `project_info.storage_bucket`                    |

So the `android` block ends up looking like (with your real values):

```dart
static const FirebaseOptions android = FirebaseOptions(
  apiKey: 'AIzaSyABCDEFG-your-real-key-here',
  appId: '1:123456789012:android:abcd1234efgh5678',
  messagingSenderId: '123456789012',
  projectId: 'salary-tracker-xxxxx',
  storageBucket: 'salary-tracker-xxxxx.firebasestorage.app',
);
```

You can leave the `ios` block untouched — it's unused since we're only
building the Android APK. Save the file.

That's the **only** code edit you need to make. Everything else (Gradle
setup, app icons, the Gradle wrapper, biometric permissions) is already in
place in the project.

---

## 4. Push the project to GitHub (no terminal needed)

**Option A — GitHub Desktop (easiest, all clicks):**
1. Install GitHub Desktop from https://desktop.github.com and sign in.
2. **File → Add local repository** → point it at the unzipped
   `salary_tracker` folder.
3. It will offer to **create a repository** here since it isn't one yet —
   click that, keep the defaults, click **Create repository**.
4. Click **Publish repository** (top bar) → choose public or private →
   **Publish**.

**Option B — GitHub's website, drag-and-drop:**
1. Go to https://github.com/new → name the repo → **Create repository**.
2. On the new repo's page, click **uploading an existing file**.
3. Drag the entire contents of the `salary_tracker` folder into the browser
   window (select all files/folders inside it and drag them in together —
   GitHub preserves the folder structure).
4. Scroll down → **Commit changes**.

Either way, once the files are on GitHub, the workflow in
`.github/workflows/android.yml` is already part of the repo and needs no
extra setup — it triggers automatically.

---

## 5. Build the APK

Pushing/publishing in step 4 automatically starts the build. To watch it or
trigger it again later:

1. On your repo's GitHub page, click the **Actions** tab.
2. You'll see a run of **Build Android APK** — click it to watch the steps
   live (it takes a few minutes: sets up Flutter, sets up Gradle, generates
   the Gradle wrapper, then builds).
3. To re-run it any time without pushing new code: **Actions** tab →
   **Build Android APK** (left sidebar) → **Run workflow** button → **Run
   workflow**.

If the run shows a red ✗, click into it to see which step failed — the most
common cause is `firebase_options.dart` still having a placeholder value
(the workflow checks for this explicitly and will tell you).

---

## 6. Download and install the APK

1. Once the run finishes with a green check, click into it.
2. Scroll to the **Artifacts** section at the bottom.
3. Download **app-release-apk** (or **app-debug-apk** for a quicker test
   build) — it downloads as a `.zip` containing the `.apk` file.
4. Unzip it, transfer the `.apk` to your Android phone (email it to
   yourself, use a cloud drive, or a USB cable), and open it on the phone.
   You may need to allow **"Install unknown apps"** for whichever app you
   used to open the file (Android will prompt you if so).

> Note: this APK is **debug-signed**, which is fine for installing on your
> own phone for testing but not for publishing to the Play Store. Play
> Store publishing needs a proper release keystore, which isn't set up in
> this project.

---

## 7. How the "custom month start day" works

`lib/services/cycle_calculator.dart` computes which cycle "today" belongs to
based on your chosen start day (1–31, clamped to the number of days in a
given month, e.g. day 31 becomes the 28th/29th in February). Each cycle is
stored as its own Firestore document (`users/{uid}/months/{cycleStartDate}`),
so changing your start day later doesn't corrupt past history — it only
affects how new purchases are grouped going forward.

## 8. Exporting data

Open **History** → tap any past (or current) cycle → tap the share icon in
the top right. This generates a CSV (salary, saving goal, allowed-to-spend,
total spent, and every line item) and opens your device's share sheet so you
can save it, email it, or send it anywhere.

---

## Troubleshooting

- **Actions run fails at "Fail early with a clear message..."** — you
  missed step 3b or 3a: `firebase_options.dart` still has placeholder
  `REPLACE_WITH_...` values, or `google-services.json` isn't at
  `android/app/google-services.json`. Go back and check both files got
  committed/pushed with your real values.
- **App installs but crashes immediately on launch** — same cause as above;
  double check every placeholder in `lib/firebase_options.dart` was
  replaced, with no stray quotes or extra spaces.
- **Fingerprint option never appears in the app** — your phone needs at
  least one fingerprint (or Face unlock) enrolled in its Android Settings
  first; the app can't add one for you.
- **Play Store rejects the APK** — expected; this build is debug-signed.
  You'd need to set up a real release keystore, which is a manual step not
  covered here (see the Flutter docs link in section 6).
- **Gradle build errors about `google-services.json` missing** — you skipped
  step 4; run `flutterfire configure` again.
