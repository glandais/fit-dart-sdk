# FIT Dart SDK

An **unofficial** Dart and Flutter SDK for Garmin's [FIT
protocol](https://developer.garmin.com/fit) — decode and encode activity,
workout and course files, with the whole generated profile: 21.217.0.

Garmin ships eight FIT SDKs. Dart is not one of them, so this one is generated
by [`fitgen`](../fitgen), a rebuilt-from-source copy of Garmin's own code
generator, from the same profile the official SDKs are built from. Every file
under `lib/` is generated; see [Regenerating](#regenerating).

- **No dependencies.** `dart:core`, `dart:typed_data`, `dart:convert` and
  `dart:async`, and nothing else. `dart:io` and `dart:isolate` are never
  imported, so the package runs unchanged on the Dart VM, on Flutter and on the
  web.
- **`decode()` never throws.** A truncated or corrupt file returns everything
  that decoded before the problem, alongside a description of it — as the
  Python and JavaScript SDKs do.
- **Off the UI thread, two ways.** `Isolate.run` where it exists, and
  `decodeAsync()` — the same decode, yielding to the event loop every few
  hundred messages — where it does not.
- **Try it in a browser.** [glandais.github.io/fit-dart-sdk](https://glandais.github.io/fit-dart-sdk/)
  decodes a FIT file in the page — summary, track, series and every message,
  with nothing uploaded. It is a Flutter web app; its source is in
  [`demo/`](demo).

## Install

Published on pub.dev as
[`fit_dart_sdk`](https://pub.dev/packages/fit_dart_sdk):

```yaml
dependencies:
  fit_dart_sdk: ^21.217.0
```

## Decoding

```dart
import 'package:fit_dart_sdk/fit_dart_sdk.dart';

final result = FitDecoder(bytes).decode();

for (final error in result.errors) {
  print('decode error: $error');   // empty when the whole file decoded cleanly
}

for (final session in result.messages.sessionMesgs) {
  print('${session.sport?.name}: ${session.totalDistance} m');
}

for (final record in result.messages.recordMesgs) {
  print('${record.timestamp}: ${record.heartRate} bpm');
}
```

`result.messages` sorts the file by message type; `result.mesgs` is the same
messages in file order. A message the profile does not know goes into
`unknownMesgs` rather than being dropped — pass
`DecodeOptions(includeUnknownData: true)` to keep it.

### On the UI thread

`decode()` is synchronous and CPU-bound, so a large activity will drop frames if
it runs on Flutter's UI isolate:

```dart
// Another isolate. Fastest, but not available on the web.
final result = await Isolate.run(() => FitDecoder(bytes).decode());

// Same isolate, yielding to the event loop every `chunkSize` messages.
// Slower overall, and the UI keeps painting. Works everywhere.
final result = await FitDecoder(bytes).decodeAsync();
```

### Streaming

`asIterable()` and `stream()` decode lazily and retain nothing, for files too
large to hold decoded in memory. Both throw on malformed input, having no result
object to carry an error; `read()` takes a callback and reports through its
return value like `decode()` does.

```dart
for (final record in FitDecoder(bytes).asIterable().whereType<RecordMesg>()) {
  print(record.heartRate);
}

await for (final mesg in FitDecoder(bytes).stream()) {
  // a StreamBuilder can render an activity as it decodes
}

// A file, an HTTP response and a platform channel all hand you a
// Stream<List<int>>; this collects one and decodes it.
final result = await decodeFitStream(file.openRead());
```

`DecodeOptions.mergeHeartRates` cannot apply while streaming: merging needs the
whole file, which is what streaming avoids holding.

## Encoding

```dart
final bytes = encodeFit((encoder) {
  encoder.write(FileIdMesg()
    ..type = FitFile.activity
    ..manufacturer = Manufacturer.development
    ..serialNumber = 1234
    ..timeCreated = DateTime.timestamp());

  for (var i = 0; i < 60; i++) {
    encoder.write(RecordMesg()
      ..timestamp = start.add(Duration(seconds: i))
      ..heartRate = 120 + i
      ..speed = 3.0);
  }
});
```

A FIT file must open with a `file_id` message; nothing here enforces that, but
readers will reject a file without one. `close()` — which `encodeFit` calls for
you — is not optional: the header states the size of the data that follows it,
which is only known once the last message is written.

Developer fields are FIT's sanctioned extension mechanism, and the way to add
data of your own. **Never redefine an existing profile field**; it breaks every
other reader.

```dart
final bytes = encodeFit((encoder) {
  encoder.registerDeveloperField(description);   // declares it in the file
  encoder.write(RecordMesg()..setDeveloperField(description.createField()..setValue(3.5)));
});
```

A `DeveloperFieldDescription` obtained from
`result.messages.developerFieldDescriptions` closes the decode → re-encode loop.

## The data model

The untyped `Mesg` — a bag of numbered `Field`s — is the real model. The 124
generated `RecordMesg`/`SessionMesg` classes are thin typed views over the same
field numbers and hold no state of their own, so anything reachable through them
is reachable underneath:

```dart
record.heartRate                                   // 140
record.getFieldValue(RecordMesg.heartRateFieldNum) // 140
record.getField(RecordMesg.heartRateFieldNum)!.units // 'bpm'
```

A few things worth knowing, all of them properties of FIT rather than of this
SDK:

- **FIT has no null.** Each base type reserves one value as its invalid
  sentinel, which the API surfaces as `null` — so "absent" and "invalid" are
  indistinguishable through it. Use `hasField` when the difference matters.
- **Every field holds an array**, even where the profile declares one value.
  `getX(index)` / `numX` reach the rest.
- **Subfields**: a field whose meaning depends on a sibling's value.
  `event.data` is `gear_change_data` only when `event` is `rear_gear_change`,
  and the generated accessor for it reads `null` otherwise.
- **Components**: bit-packed fields unpacked into the fields they represent.
  `record.speed` on a file that only stores `compressed_speed_distance` comes
  from expansion; turn it off with `DecodeOptions(expandComponents: false)`.
- **The FIT epoch** is 1989-12-31T00:00:00Z. Every `DateTime` this SDK produces
  is in UTC; a timestamp below `FitDateTime.systemTimeThreshold` is seconds
  since device power-on rather than a date, and reads as `null`.

### Dart's two numeric types

Dart has one integer type and one floating-point type, so all 15 integral FIT
base types are held as `int` and the two float ones as `double`. Signedness and
width live in the `BaseType`, which is what the reader and the writer work from.
Two consequences:

- A `uint64` above 2^63 is held as the negative `int` sharing its bit pattern,
  exactly as the Java SDK holds one in a `long`. The bit pattern is what is
  written back out, so the round trip is exact even though arithmetic on it is
  not. FIT uses `uint64` in a handful of places and none of them approach that
  range.
- `BaseType.of` — consulted only when setting a field number the profile does
  not declare — can only answer with the widest type of each kind. It costs a
  few bytes on the wire, never precision.

Compiled to JavaScript, `int` and `double` are one runtime type. Everything that
inspects a boxed numeric type here tests `double` before `int` so that an
integral value is held losslessly rather than truncated.

### Names

Two profile types would collide with something Dart already has, and are
prefixed rather than shadowing it:

| profile type | Dart |
|---|---|
| `file` | `FitFile` — `dart:io` owns `File` |
| `mesg_num` | `FitMesgNum` — the global message *numbers* are `MesgNum.record` and friends, and unlike enum members they are compile-time constants a `switch` can use |

Everything else follows the profile: message `record` → `RecordMesg`, type
`sport` → `Sport`, field `heart_rate` → `heartRate`, value `rear_gear_change` →
`Event.rearGearChange`. A name that is a Dart reserved word gains a trailing
underscore, one that starts with a digit a leading `$`.

## Correctness

`dart test` runs 205 tests. The two that matter most do not check this SDK
against itself:

- **`tool/cross_check.sh`** decodes all five fixtures with this SDK *and* with
  [`garmin/fit-python-sdk`](https://github.com/garmin/fit-python-sdk), and diffs
  every field of every message: **140,257 values, zero divergences**. Five
  differences remain and are all the Python decoder describing the same data
  differently — see [`tool/README.md`](tool/README.md).
- **`test/re_encode_test.dart`** decodes a real file and encodes it straight
  back. `WithGearChangeData.fit` reproduces **byte for byte**, all 74,645 of
  them: same field order, same local message numbers, same definition records,
  same header. That one round trip exercises both CRCs, definition emission and
  reuse, every base type the file declared, string padding and every invalid
  sentinel at once — it is what catches an absent float being written back as a
  canonical NaN rather than the all-ones pattern the file held.

One deliberate difference from `fit-python-sdk`: an all-ones *accumulated*
component carries no sample, so it neither reaches its destination field nor
feeds the running total. `fit-python-sdk` folds the sentinel in before testing
invalidity, which corrupts the next record's total.

## Regenerating

Everything under `lib/`, `test/` and `example/`, plus `pubspec.yaml`,
`analysis_options.yaml`, `CHANGELOG.md` and this README, is generated. Editing
any of it is lost on the next run.

```sh
cd ../fitgen
./fitgen -norewrite -o .. -dart fit-dart-sdk
cd ../fit-dart-sdk && dart format . && dart test
```

`dart format` is the second half of the recipe, not an optional tidy-up: the
templates cannot know where the formatter wants to break a line, and pub.dev
scores an unformatted package down.

Regeneration deletes `*.dart` under the directories it owns and `*.yaml` at the
root. **`tool/` and `.github/` are hand-written and survive**, as does anything
else you add outside those directories.

## Continuous integration

`check.yml` runs on every push and pull request: `dart analyze --fatal-infos`,
`dart format --set-exit-if-changed` (the whole tree is generated *and*
formatted, so this is what catches a regeneration that skipped the second
half), `dart test`, `dart pub publish --dry-run`, the cross-check against
`fit-python-sdk`, and an analysis of `lib/` alone on Dart 3.0 — the floor
`pubspec.yaml` declares, which the dev toolchain is too new to exercise on its
own. It also builds the demo, which is where a change neither dart2js nor
dart2wasm accepts would surface: the package itself has no web build of its own.

`gh-pages.yml` builds `demo/` and publishes it to GitHub Pages on every push to
`main` that touches the demo or the library.

`release.yml` publishes to pub.dev from a `vN.N.N` tag, with OIDC rather than a
stored credential. Because pub.dev never lets a version be republished, three
things stand between a tag and an upload: the tag is checked against
`pubspec.yaml`'s version, the whole check runs again, and the publish job waits
for a manual approval in the `pub-dev` GitHub environment — which is itself
restricted to `v*` tags. The approval is the last point at which a release can
still be called off.

## License

The FIT Protocol License, as the SDK Garmin generates from the same profile.
See `LICENSE.txt`. Not affiliated with or endorsed by Garmin.
