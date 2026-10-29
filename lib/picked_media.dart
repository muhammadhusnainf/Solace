import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

class PickedMedia {
  final Uint8List bytes;
  final String name;
  final String mime;
  final bool isVideo;

  const PickedMedia({
    required this.bytes,
    required this.name,
    required this.mime,
    required this.isVideo,
  });

  static Future<PickedMedia> fromFile(XFile file) async {
    final mime = file.mimeType ?? mimeFromName(file.name);
    return PickedMedia(
      bytes: await file.readAsBytes(),
      name: file.name,
      mime: mime,
      isVideo: mime.startsWith('video/'),
    );
  }
}

String mimeFromName(String name) {
  final n = name.toLowerCase();
  if (n.endsWith('.png')) return 'image/png';
  if (n.endsWith('.gif')) return 'image/gif';
  if (n.endsWith('.webp')) return 'image/webp';
  if (n.endsWith('.mp4')) return 'video/mp4';
  if (n.endsWith('.mov')) return 'video/quicktime';
  if (n.endsWith('.webm')) return 'video/webm';
  if (n.endsWith('.mkv')) return 'video/x-matroska';
  if (n.endsWith('.3gp')) return 'video/3gpp';
  if (n.endsWith('.avi')) return 'video/x-msvideo';
  return 'image/jpeg';
}
