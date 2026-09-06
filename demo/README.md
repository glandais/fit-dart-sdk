# fit_dart_sdk browser demo

A Flutter web app that decodes a FIT file **in the page**: no upload, no server,
no network call once the app has loaded. It is the app behind
<https://glandais.github.io/fit-dart-sdk/>.

Drop a `.fit` file on it (or pick one, or load the bundled sample) and it shows:

- a summary read through the typed accessors — file type, manufacturer, product,
  sport, distance, moving time, ascent, average heart rate and power, calories;
- anything the decoder could not make sense of, alongside everything it *could*
  — `decode` never throws;
- the GPS track, drawn flat, with start and end marked;
- record fields over the file — altitude, speed, heart rate, cadence, power —
  each scaled to its own range, any subset on screen at once;
- every message, by type, in a generic table: profile names, units, enum values
  as names, timestamps as instants, developer fields marked `*`, and the fields
  the profile does not know when *include unknown data* is on;
- a JSON download of the whole decode.

## Running it

```sh
flutter run -d chrome                     # development
flutter build web --wasm                  # what CI publishes
```

`flutter build web --wasm` produces a WebAssembly build with a JavaScript
fallback for browsers without WasmGC, so both compilers have to accept the SDK.

## What is hand-written here, and what is not

Everything under `lib/` is hand-written and safe to edit — unlike the package one
directory up, which fitgen generates — with one exception:

`lib/src/profile_labels.dart` is produced by `tool/gen_profile_labels.dart` from
the SDK sources next door, and `check.yml` fails if the two disagree. It carries
what a *generic* message table needs and the typed API has no use for: the
profile type of each field, and the name of each value of those types.
`SessionMesg.sport` already returns `Sport.cycling`; a table that only ever sees
a `Mesg` and a field name needs the same knowledge as data. Regenerate it after
a profile bump:

```sh
dart run tool/gen_profile_labels.dart
dart format lib/src/profile_labels.dart
```

`lib/src/browser.dart` is the one web-only file: the file dialog, the page-wide
drag-and-drop, the JSON download. The app builds for the web and nothing else,
which is what it is for.
