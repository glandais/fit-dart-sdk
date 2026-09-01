/////////////////////////////////////////////////////////////////////////////////////////////
// Copyright 2026 Garmin International, Inc.
// Licensed under the Flexible and Interoperable Data Transfer (FIT) Protocol License; you
// may not use this file except in compliance with the Flexible and Interoperable Data
// Transfer (FIT) Protocol License.
/////////////////////////////////////////////////////////////////////////////////////////////

import 'dart:typed_data';

import 'package:fit_dart_sdk/fit_dart_sdk.dart';
import 'package:test/test.dart';

import 'test_data.dart';

void main() {
  group('recognition and integrity', () {
    test('a well-formed file is recognised as FIT', () {
      expect(FitDecoder(TestData.fitFileShort).isFit(), isTrue);
      expect(FitDecoder.looksLikeFit(TestData.fitFileShort), isTrue);
    });

    test('anything else is not', () {
      expect(FitDecoder(Uint8List(0)).isFit(), isFalse);
      expect(FitDecoder(TestData.bytes(const [1, 2, 3])).isFit(), isFalse);
      expect(FitDecoder(TestData.fitFileShortInvalidHeader).isFit(), isFalse);
    });

    test('integrity follows the recorded CRC', () {
      expect(FitDecoder(TestData.fitFileShort).checkIntegrity(), isTrue);
      expect(FitDecoder(TestData.fitFileShortInvalidCrc).checkIntegrity(),
          isFalse);
    });

    test('a wrong header CRC fails the integrity check', () {
      expect(FitDecoder(TestData.fitFileShortInvalidHeaderCrc).checkIntegrity(),
          isFalse);
    });

    test('an unset header CRC is accepted', () {
      // 0x0000 is how a producer says "header CRC not filled in", which the
      // protocol allows.
      expect(FitDecoder(TestData.fitFileShortUnsetHeaderCrc).checkIntegrity(),
          isTrue);
    });

    test('a twelve-byte header has no header CRC to check', () {
      final bytes = TestData.fitFileShortShortHeader;
      expect(FitDecoder(bytes).isFit(), isTrue);
      expect(FitDecoder(bytes).checkIntegrity(), isTrue);
    });

    test('a bad header CRC anywhere in a chain is caught', () {
      final chained = Uint8List.fromList(<int>[
        ...TestData.fitFileShort,
        ...TestData.fitFileShortInvalidHeaderCrc,
      ]);
      expect(FitDecoder(chained).checkIntegrity(), isFalse);
    });
  });

  group('decoding the fixture', () {
    test('yields its single file_id message', () {
      final result = FitDecoder(TestData.fitFileShort).decode();

      expect(result.errors, isEmpty);
      expect(result.isSuccess, isTrue);
      expect(result.mesgs.length, 1);

      final fileId = result.messages.fileIdMesgs.single;
      expect(fileId.type, FitFile.activity);
      expect(fileId.manufacturer, Manufacturer.garmin);
      // Field 4, uint32 0x3B9ACA00, is time_created — seconds since the FIT
      // epoch, not since 1970.
      expect(
          fileId.timeCreated,
          DateTime.utc(1970).add(
              const Duration(seconds: 1000000000 + Fit.epochOffsetSeconds)));
      expect(fileId.productName, 'abcdefghi');
    });

    test('the profile version comes from the file header', () {
      final result = FitDecoder(TestData.fitFileShort).decode();
      expect(result.profileVersion, 0x088B);
    });

    test('messages carry their position in the file', () {
      final chained = Uint8List.fromList(<int>[
        ...TestData.fitFileShort,
        ...TestData.fitFileShort,
      ]);
      final result = FitDecoder(chained).decode();
      expect(result.mesgs.map((m) => m.decoderMesgIndex).toList(), <int>[0, 1]);
    });

    test('two concatenated files both decode', () {
      final chained = Uint8List.fromList(<int>[
        ...TestData.fitFileShort,
        ...TestData.fitFileShort,
      ]);
      final result = FitDecoder(chained).decode();
      expect(result.errors, isEmpty);
      expect(result.messages.fileIdMesgs.length, 2);
    });
  });

  group('error reporting', () {
    test('a bad CRC is reported without losing the decoded messages', () {
      final result = FitDecoder(TestData.fitFileShortInvalidCrc).decode();
      expect(result.errors, hasLength(1));
      expect(result.errors.single.message, contains('CRC mismatch'));
      expect(result.messages.fileIdMesgs.length, 1);
    });

    test('a file truncated before its CRC is reported', () {
      final truncated = Uint8List.sublistView(
          TestData.fitFileShort, 0, TestData.fitFileShort.length - 1);
      final result = FitDecoder(Uint8List.fromList(truncated)).decode();
      expect(result.errors, hasLength(1));
      expect(result.errors.single.message, contains('before its CRC'));
      // Everything decoded up to the problem is still there.
      expect(result.messages.fileIdMesgs.length, 1);
    });

    test('a missing CRC is not an error outside normal mode', () {
      final truncated = Uint8List.fromList(Uint8List.sublistView(
          TestData.fitFileShort, 0, TestData.fitFileShort.length - 2));
      expect(
        FitDecoder(truncated)
            .decode(const DecodeOptions(mode: DecodeMode.skipHeader))
            .errors,
        isEmpty,
      );
    });

    test('decoding never throws, whatever the input', () {
      for (final bytes in <Uint8List>[
        Uint8List(0),
        TestData.bytes(const [0xFF]),
        TestData.bytes(List<int>.filled(64, 0xFF)),
        TestData.fitFileShortInvalidHeader,
        TestData.fitFileShortInvalidCrc,
      ]) {
        final result = FitDecoder(bytes).decode();
        expect(result, isA<DecodeResult>());
      }
    });

    test('no exception escapes on arbitrary malformed input', () {
      // Every truncation and every single-byte corruption of the fixture.
      final source = TestData.fitFileShort;
      for (var length = 0; length <= source.length; length++) {
        FitDecoder(Uint8List.fromList(source.sublist(0, length))).decode();
      }
      for (var i = 0; i < source.length; i++) {
        final corrupt = Uint8List.fromList(source);
        corrupt[i] = (corrupt[i] + 137) & 0xFF;
        FitDecoder(corrupt).decode();
        FitDecoder(corrupt)
            .decode(const DecodeOptions(mode: DecodeMode.skipHeader));
        FitDecoder(corrupt)
            .decode(const DecodeOptions(mode: DecodeMode.dataOnly));
      }
    });

    test('a data record for an undefined local message is reported, not thrown',
        () {
      // A lone data record header with no preceding definition.
      final result =
          FitDecoder(TestData.fileOf(TestData.bytes(const [0x00, 0x01])))
              .decode();
      expect(result.errors, hasLength(1));
      expect(result.errors.single.message, contains('nothing defined'));
    });

    test('a compressed timestamp header is rejected', () {
      final result =
          FitDecoder(TestData.fileOf(TestData.bytes(const [0x80, 0x00])))
              .decode();
      expect(result.errors, hasLength(1));
      expect(result.errors.single.message, contains('compressed timestamp'));
    });

    test('the callback API reports failures instead of throwing', () {
      final seen = <Mesg>[];
      final errors = FitDecoder(TestData.fitFileShortInvalidCrc).read(seen.add);
      expect(errors, hasLength(1));
      expect(seen, hasLength(1));
    });

    test('the safety net does not swallow the caller\'s own failures', () {
      expect(
        () => FitDecoder(TestData.fitFileShort)
            .read((_) => throw StateError('mine')),
        throwsStateError,
      );
    });
  });

  group('decode modes', () {
    test('a bad header is rejected in normal mode and tolerated in skipHeader',
        () {
      final bytes = TestData.fitFileShortInvalidHeader;
      expect(FitDecoder(bytes).decode().errors, isNotEmpty);
      expect(
        FitDecoder(bytes)
            .decode(const DecodeOptions(mode: DecodeMode.skipHeader))
            .messages
            .fileIdMesgs,
        hasLength(1),
      );
    });

    test('headerless records decode in dataOnly mode', () {
      final result = FitDecoder(TestData.fitFileShortDataOnly)
          .decode(const DecodeOptions(mode: DecodeMode.dataOnly));
      expect(result.errors, isEmpty);
      expect(result.messages.fileIdMesgs, hasLength(1));
    });

    test('headerless records are not a FIT file in normal mode', () {
      expect(FitDecoder(TestData.fitFileShortDataOnly).isFit(), isFalse);
      expect(FitDecoder(TestData.fitFileShortDataOnly).decode().errors,
          isNotEmpty);
    });

    test('every truncation of a file decodes in skipHeader mode', () {
      for (var length = 0; length <= TestData.fitFileShort.length; length++) {
        FitDecoder(Uint8List.fromList(TestData.fitFileShort.sublist(0, length)))
            .decode(const DecodeOptions(mode: DecodeMode.skipHeader));
      }
    });
  });

  group('lazy and asynchronous entry points', () {
    test('the iterable API decodes lazily and sees the same messages', () {
      final lazy = FitDecoder(TestData.fitFileShort).asIterable().toList();
      final eager = FitDecoder(TestData.fitFileShort).decode().mesgs;
      expect(lazy.length, eager.length);
      expect(lazy.single, isA<FileIdMesg>());
    });

    test('the iterable API throws where the result API collects', () {
      expect(
        () => FitDecoder(TestData.fitFileShortInvalidCrc).asIterable().toList(),
        throwsA(isA<FitFormatException>()),
      );
    });

    test('whereType picks one message type out of the stream', () {
      final records = FitDecoder(TestData.fitFileShort)
          .asIterable()
          .whereType<FileIdMesg>();
      expect(records, hasLength(1));
    });

    test('the stream API yields the same messages', () async {
      final streamed =
          await FitDecoder(TestData.fitFileShort).stream(chunkSize: 1).toList();
      expect(streamed, hasLength(1));
      expect(streamed.single, isA<FileIdMesg>());
    });

    test('decodeAsync matches decode', () async {
      final sync = FitDecoder(TestData.fitFileShort).decode();
      final async =
          await FitDecoder(TestData.fitFileShort).decodeAsync(chunkSize: 1);
      expect(async.mesgs.length, sync.mesgs.length);
      expect(async.errors.length, sync.errors.length);
      expect(async.profileVersion, sync.profileVersion);
    });

    test('decodeFitStream collects the input before decoding', () async {
      final chunks = <List<int>>[
        TestData.fitFileShort.sublist(0, 10),
        TestData.fitFileShort.sublist(10),
      ];
      final result =
          await decodeFitStream(Stream<List<int>>.fromIterable(chunks));
      expect(result.errors, isEmpty);
      expect(result.messages.fileIdMesgs, hasLength(1));
    });
  });

  test('a decoded message holds only the populated fields', () {
    final fileId =
        FitDecoder(TestData.fitFileShort).decode().messages.fileIdMesgs.single;
    expect(fileId.fieldList.map((f) => f.fieldName).toList(),
        <String>['type', 'manufacturer', 'time_created', 'product_name']);
    expect(fileId.fieldList.every((f) => f.hasValues), isTrue);
  });

  test('unknown messages are dropped unless asked for', () {
    // A definition and data record for global message 0xFFFE.
    final body = ByteWriter()
      ..writeByte(0x40)
      ..writeByte(0)
      ..writeByte(Endianness.little.value)
      ..writeUint16(0xFFFE)
      ..writeByte(1)
      ..writeByte(0)
      ..writeByte(1)
      ..writeByte(BaseType.uint8.id)
      ..writeByte(0x00)
      ..writeByte(0x2A);
    final file = TestData.fileOf(body.toBytes());

    expect(FitDecoder(file).decode().mesgs, isEmpty);

    final kept =
        FitDecoder(file).decode(const DecodeOptions(includeUnknownData: true));
    expect(kept.messages.unknownMesgs, hasLength(1));
    expect(kept.messages.unknownMesgs.single.getFieldValue(0), 42);
  });
}
