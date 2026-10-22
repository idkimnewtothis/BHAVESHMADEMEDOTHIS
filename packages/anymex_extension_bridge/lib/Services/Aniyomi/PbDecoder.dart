import 'dart:convert';

/// Aniyomi v17 index.proto. Truncated input is an error, never an empty store.
class PbDecoder {
  static Map<String, dynamic> decodeStore(List<int> bytes) {
    final root = _message(bytes);
    if (root.containsKey(101) || root.containsKey(102)) {
      return {
        'name': _string(root, 1),
        'signingKey': _string(root, 3),
        if (root.containsKey(102)) 'extensionListUrl': _string(root, 102),
        if (root.containsKey(101))
          'extensionList': {
            'extensions': _extensions(_message(root[101]!.single as List<int>))
          },
      };
    }
    return {'extensions': _extensions(root)};
  }

  static List<Map<String, dynamic>> decodeIndex(List<int> bytes) {
    final store = decodeStore(bytes);
    return List<Map<String, dynamic>>.from(
        store['extensionList']?['extensions'] ?? store['extensions'] ?? []);
  }

  static List<Map<String, dynamic>> _extensions(Map<int, List<Object>> list) =>
      (list[1] ?? []).map((raw) {
        final e = _message(raw as List<int>);
        final resources = _message(e[3]?.single as List<int>? ?? []);
        return <String, dynamic>{
          'name': _string(e, 1),
          'packageName': _string(e, 2),
          'resources': {
            'apkUrl': _string(resources, 1),
            'iconUrl': _string(resources, 2)
          },
          'extensionLib': _string(e, 4),
          'versionCode': _integer(e, 5),
          'versionName': _string(e, 6),
          'contentWarning': _integer(e, 7),
          'isTorrent': _integer(e, 8) != 0,
          'sources': (e[9] ?? []).map((raw) {
            final s = _message(raw as List<int>);
            return {
              'id': _integer(s, 1).toString(),
              'name': _string(s, 2),
              'language': _string(s, 3),
              'homeUrl': _string(s, 4),
              'message': _string(s, 6)
            };
          }).toList(),
        };
      }).toList();

  static Map<int, List<Object>> _message(List<int> bytes) {
    final result = <int, List<Object>>{};
    var offset = 0;
    int varint() {
      var value = 0;
      for (var shift = 0; shift < 70; shift += 7) {
        if (offset >= bytes.length)
          throw const FormatException('Truncated protobuf varint');
        final byte = bytes[offset++];
        if (shift == 63 && byte > 1)
          throw const FormatException('Protobuf varint overflow');
        value |= (byte & 127) << shift;
        if (byte < 128) return value;
      }
      throw const FormatException('Invalid protobuf varint');
    }

    while (offset < bytes.length) {
      final tag = varint(), field = tag >> 3, wire = tag & 7;
      if (field < 1) throw const FormatException('Invalid protobuf field');
      Object value;
      if (wire == 0) {
        value = varint();
      } else if (wire == 1 || wire == 2 || wire == 5) {
        final size = wire == 2 ? varint() : (wire == 1 ? 8 : 4);
        if (size < 0 || size > bytes.length - offset)
          throw const FormatException('Truncated protobuf field');
        value = bytes.sublist(offset, offset + size);
        offset += size;
      } else {
        throw FormatException('Unsupported protobuf wire type: $wire');
      }
      result.putIfAbsent(field, () => []).add(value);
    }
    return result;
  }

  static String _string(Map<int, List<Object>> m, int key) {
    final v = m[key]?.single;
    if (v == null) return '';
    if (v is! List<int>) throw FormatException('Invalid string field $key');
    return utf8.decode(v);
  }

  static int _integer(Map<int, List<Object>> m, int key) {
    final v = m[key]?.single;
    if (v == null) return 0;
    if (v is! int) throw FormatException('Invalid integer field $key');
    return v;
  }
}
