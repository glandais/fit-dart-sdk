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
  test('a value comes back out as it went in', () {
    final field = Field('heart_rate', 3, BaseType.uint8)..setValue(140);
    expect(field.getValue(), 140);
    expect(field.getRawValue(), 140);
    expect(field.numValues, 1);
    expect(field.hasValues, isTrue);
  });

  test('scale and offset are applied on write and undone on read', () {
    final field = Field('speed', 6, BaseType.uint16, 1000.0, 0.0, 'm/s')
      ..setValue(5.5);
    expect(field.getRawValue(), 5500);
    expect(field.getValue(), 5.5);

    final altitude = Field('altitude', 2, BaseType.uint16, 5.0, 500.0, 'm')
      ..setValue(100.0);
    expect(altitude.getRawValue(), 3000);
    expect(altitude.getValue(), 100.0);
  });

  test('the invalid sentinel reads back as null', () {
    final field = Field('heart_rate', 3, BaseType.uint8)
      ..setValue(BaseType.uint8.invalidValue());
    expect(field.getValue(), isNull);
    expect(field.getRawValue(), 255);
  });

  test('reading beyond the stored values gives null', () {
    final field = Field('x', 0, BaseType.uint8)..setValue(1);
    expect(field.getValue(5), isNull);
    expect(field.getRawValue(5), isNull);
    expect(field.getValue(-1), isNull);
  });

  test('a field holds an array of values', () {
    final field = Field('x', 0, BaseType.uint8)
      ..setValue(1, 0)
      ..setValue(2, 1)
      ..setValue(3, 2);
    expect(field.numValues, 3);
    expect(field.toList(), <Object?>[1, 2, 3]);
  });

  test('setting a value past the end pads with nulls', () {
    final field = Field('x', 0, BaseType.uint8)..setValue(9, 3);
    expect(field.numValues, 4);
    expect(field.toList(), <Object?>[null, null, null, 9]);
  });

  test('encoded size follows the base type and value count', () {
    final field = Field('x', 0, BaseType.uint16)
      ..setValue(1, 0)
      ..setValue(2, 1);
    expect(field.size, 4);
    expect(Field('y', 0, BaseType.uint8).size, 0);
  });

  test('a string field is sized by its UTF-8 bytes plus terminator', () {
    final field = Field('name', 0, BaseType.string)..setValue('abc');
    expect(field.size, 4);
    field.setValue('éé', 1);
    expect(field.size, 4 + 5);
  });

  test('a field cannot grow past the protocol limit', () {
    final field = Field('x', 0, BaseType.uint8);
    expect(() => field.setValue(1, Fit.maxFieldSize),
        throwsA(isA<FitFieldException>()));
    expect(() => Field('s', 0, BaseType.string).setValue('a' * 300),
        throwsA(isA<FitFieldException>()));
  });

  test('values round-trip through the wire', () {
    final field = Field('x', 0, BaseType.sint16)
      ..setValue(-1, 0)
      ..setValue(1000, 1);

    final writer = ByteWriter();
    field.write(writer);
    expect(writer.size, field.size);

    final read = Field('x', 0, BaseType.sint16)
      ..read(ByteReader(writer.toBytes()), writer.size);
    expect(read.toList(), <Object?>[-1, 1000]);
  });

  test('a field whose values are all invalid is dropped on read', () {
    final writer = ByteWriter()
      ..writeByte(0xFF)
      ..writeByte(0xFF);
    final field = Field('x', 0, BaseType.uint8)
      ..read(ByteReader(writer.toBytes()), 2);
    expect(field.hasValues, isFalse);
  });

  test('a partly valid field is kept whole', () {
    final writer = ByteWriter()
      ..writeByte(0xFF)
      ..writeByte(0x01);
    final field = Field('x', 0, BaseType.uint8)
      ..read(ByteReader(writer.toBytes()), 2);
    expect(field.numValues, 2);
    expect(field.toList(), <Object?>[null, 1]);
  });

  test('a size that is not a whole number of values is skipped', () {
    final reader = ByteReader(TestData.bytes(const [1, 2, 3, 0xAB]));
    final field = Field('x', 0, BaseType.uint16)..read(reader, 3);
    expect(field.hasValues, isFalse);
    // The rest of the record stayed aligned.
    expect(reader.position, 3);
    expect(reader.readByte(), 0xAB);
  });

  test('a string field can carry several NUL-separated strings', () {
    final writer = ByteWriter()
      ..writeString('one')
      ..writeString('two');
    final field = Field('s', 0, BaseType.string)
      ..read(ByteReader(writer.toBytes()), writer.size);
    expect(field.toList(), <Object?>['one', 'two']);
  });

  test('a string field of nothing but NULs is dropped on read', () {
    final field = Field('s', 0, BaseType.string)
      ..read(ByteReader(Uint8List(4)), 4);
    expect(field.hasValues, isFalse);
  });

  test('an invalid value is written as its sentinel bytes', () {
    final field = Field('x', 0, BaseType.sint16)..setValue(null);
    final writer = ByteWriter();
    field.write(writer);
    expect(writer.toBytes(), TestData.bytes(const [0xFF, 0x7F]));
  });

  test('an absent float keeps its all-ones bit pattern', () {
    final field = Field('x', 0, BaseType.float32)..setValue(null);
    final writer = ByteWriter();
    field.write(writer);
    expect(writer.toBytes(), TestData.bytes(const [0xFF, 0xFF, 0xFF, 0xFF]));
  });

  test('integral conversion rounds rather than truncates', () {
    // Component expansion divides by a scale, so a value that should land
    // exactly on 4087 arrives as 4086.99999...
    final field = Field('x', 0, BaseType.uint16, 100.0)..setValue(40.8699999);
    expect(field.getRawValue(), 4087);
  });

  test('a byte array treats 0xFF as data unless every byte is 0xFF', () {
    // FIT's `byte` type is the raw-bytes type: 0xFF is a legitimate element, and
    // the field only means "absent" when every byte is 0xFF. Nulling elements
    // individually would punch holes in a UUID.
    final uuid = Field('application_id', 0, BaseType.byte);
    for (var i = 0; i < 4; i++) {
      uuid.setValue(i == 1 ? 0xFF : i, i);
    }
    expect(uuid.toList(), <Object?>[0, 0xFF, 2, 3]);

    final allFf = Field('application_id', 0, BaseType.byte);
    for (var i = 0; i < 4; i++) {
      allFf.setValue(0xFF, i);
    }
    expect(allFf.toList(), <Object?>[null, null, null, null]);
  });

  test('a value too large for the active subfield is stored as invalid', () {
    // event.data is a uint32 whose course_point_index subfield is a uint16. The
    // storage stays the field's own width, but a value that overflows the
    // subfield must not read back as something else.
    final field = Field('data', 3, BaseType.uint32)
      ..addSubField(
          SubField('course_point_index', BaseType.uint16, 1.0, 0.0, ''));
    final subField = field.getSubFieldNamed('course_point_index');

    field.setValueWith(70000, 0, subField);
    expect(field.getRawValue(), BaseType.uint32.invalidValue());
    expect(field.getValueWith(0, subField), isNull);
  });

  test('a value within the active subfield range round-trips', () {
    final field = Field('data', 3, BaseType.uint32)
      ..addSubField(
          SubField('course_point_index', BaseType.uint16, 1.0, 0.0, ''));
    final subField = field.getSubFieldNamed('course_point_index');

    field.setValueWith(1234, 0, subField);
    expect(field.getValueWith(0, subField), 1234);
  });

  test('a profile field never equals a developer field of the same number', () {
    // Field 0 of a record is position_lat; developer field 0 of the same record
    // is whatever that file's field_description named.
    final profile = Field('x', 0, BaseType.uint8)..setValue(1);
    final developer = DeveloperField(
      fieldName: 'x',
      fieldNum: 0,
      baseType: BaseType.uint8,
      developerDataIndex: 0,
    )..setValue(1);
    expect(profile == developer, isFalse);
    expect(developer == profile, isFalse);
  });

  test('two developer fields from different applications are not equal', () {
    DeveloperField field(int uuidByte) => DeveloperField(
          fieldName: 'x',
          fieldNum: 0,
          baseType: BaseType.uint8,
          developerDataIndex: 0,
          applicationId: List<int>.filled(16, uuidByte),
        )..setValue(1);

    expect(field(1) == field(1), isTrue);
    expect(field(1) == field(2), isFalse);
  });

  test('the application id is copied on the way in and on the way out', () {
    final id = List<int>.filled(16, 7);
    final field = DeveloperField(
      fieldName: 'x',
      fieldNum: 0,
      baseType: BaseType.uint8,
      developerDataIndex: 0,
      applicationId: id,
    );

    id[0] = 99;
    expect(field.applicationId![0], 7);

    field.applicationId![0] = 42;
    expect(field.applicationId![0], 7);
  });

  test('copying a field carries its metadata and values', () {
    final original = Field('speed', 6, BaseType.uint16, 1000.0, 0.0, 'm/s')
      ..addComponent(const FieldComponent(7, false, 12, 100.0, 0.0))
      ..addSubField(SubField('sub', BaseType.uint8, 1.0, 0.0, ''))
      ..setValue(5.5);
    original.isExpandedField = true;

    final copy = Field.from(original);
    expect(copy.fieldName, 'speed');
    expect(copy.scale, 1000.0);
    expect(copy.units, 'm/s');
    expect(copy.isExpandedField, isTrue);
    expect(copy.components.length, 1);
    expect(copy.subFields.length, 1);
    expect(copy.getValue(), 5.5);

    copy.setValue(6.0);
    expect(original.getValue(), 5.5);
  });
}
