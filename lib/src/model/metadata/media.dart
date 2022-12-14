import 'dart:convert';
import 'dart:typed_data';

import 'package:lib5/src/constants.dart';
import 'package:lib5/src/model/cid.dart';

import 'base.dart';
import 'extra.dart';
import 'user.dart';

class MediaMetadata extends Metadata {
  final String name;

  final Map<String, List<MediaFormat>> mediaTypes;

  final List<MetadataUser> users;

  final MediaMetadataDetails details;

  final ExtraMetadata extraMetadata;

  MediaMetadata({
    required this.name,
    required this.details,
    required this.users,
    required this.mediaTypes,
    required this.extraMetadata,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'media',
        'name': name,
        'details': details,
        'users': users,
        'mediaTypes': mediaTypes,
        'extraMetadata': extraMetadata,
      };
}

class MediaMetadataDetails {
  final Map<int, dynamic> data;

  MediaMetadataDetails(this.data);

  toJson() {
    final map = <String, dynamic>{};
    final names = {
      metadataMediaDetailsDuration: 'duration',
    };
    for (final e in data.entries) {
      map[names[e.key]!] = e.value;
    }

    return map;
  }

  /// duration of media file in seconds
  double? get duration => data[metadataMediaDetailsDuration];
}

class MediaFormat {
  late final String subtype;
  late final String?
      role; // thumbnail, storyboard, lyrics, subtitle, description, ...
  late final String ext;
  late final CID? cid;

  int? height;
  int? width;
  // int? quality;
  List<String>? languages;

  // TODO Maybe change types
  int? asr;
  double? fps;
  double? tbr;
  double? abr;
  double? vbr;
  int? audioChannels;
  String? vcodec;
  String? acodec;
  String? container;
  String? dynamicRange;

  String? charset;
  Uint8List? value;
  // TODO String generator/processedBy/encoder/...

  String? get valueAsString => value == null ? null : utf8.decode(value!);

  double? duration;
  int? rows;
  int? columns;
  int? index;

  MediaFormat({
    required this.subtype,
    required this.role,
    required this.ext,
    required this.cid,
    this.height,
    this.width,
    this.languages,
    this.asr,
    this.fps,
    this.tbr,
    this.abr,
    this.vbr,
    this.audioChannels,
    this.vcodec,
    this.acodec,
    this.container,
    this.dynamicRange,
    this.charset,
    this.value,
    this.duration,
    this.rows,
    this.columns,
    this.index,
  });

  MediaFormat.decode(Map<int, dynamic> data) {
    cid = data[1] == null ? null : CID.fromBytes(Uint8List.fromList(data[1]));
    subtype = data[2];
    role = data[3];
    ext = data[4];
    height = data[10];
    width = data[11];
    languages = data[12]?.cast<String>();
    asr = data[13];
    fps = data[14];
    tbr = data[15];
    abr = data[16];
    vbr = data[17];
    audioChannels = data[18];
    vcodec = data[19];
    acodec = data[20];
    container = data[21];
    dynamicRange = data[22];
    charset = data[23];
    value = data[24] == null ? null : Uint8List.fromList(data[24]);

    duration = data[25];
    rows = data[26];
    columns = data[27];
    index = data[28];
  }

  Map<int, dynamic> encode() {
    final map = <int, dynamic>{};
    void addNotNull(int key, dynamic value) {
      if (value != null) {
        map[key] = value;
      }
    }

    addNotNull(1, cid?.toBytes());
    addNotNull(2, subtype);
    addNotNull(3, role);
    addNotNull(4, ext);
    addNotNull(10, height);
    addNotNull(11, width);
    addNotNull(12, languages);
    addNotNull(13, asr);
    addNotNull(14, fps);
    addNotNull(15, tbr);
    addNotNull(16, abr);
    addNotNull(17, vbr);
    addNotNull(18, audioChannels);
    addNotNull(19, vcodec);
    addNotNull(20, acodec);
    addNotNull(21, container);
    addNotNull(22, dynamicRange);
    addNotNull(23, charset);
    addNotNull(24, value);
    addNotNull(25, duration);
    addNotNull(26, rows);
    addNotNull(27, columns);
    addNotNull(28, index);

    return map;
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    void addNotNull(String key, dynamic value) {
      if (value != null) {
        map[key] = value;
      }
    }

    addNotNull('cid', cid?.toBase64Url());
    addNotNull('subtype', subtype);
    addNotNull('role', role);
    addNotNull('ext', ext);
    addNotNull('height', height);
    addNotNull('width', width);
    addNotNull('languages', languages);
    addNotNull('asr', asr);
    addNotNull('fps', fps);
    addNotNull('tbr', tbr);
    addNotNull('abr', abr);
    addNotNull('vbr', vbr);
    addNotNull('audioChannels', audioChannels);
    addNotNull('vcodec', vcodec);
    addNotNull('acodec', acodec);
    addNotNull('container', container);
    addNotNull('dynamicRange', dynamicRange);
    addNotNull('charset', charset);
    addNotNull('value', valueAsString);
    addNotNull('duration', duration);
    addNotNull('rows', rows);
    addNotNull('columns', columns);
    addNotNull('index', index);

    return map;
  }
}
