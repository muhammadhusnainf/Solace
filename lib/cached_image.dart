import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

final CacheManager _imageCache = CacheManager(
  Config(
    'solaceImages',
    stalePeriod: const Duration(days: 30),
    maxNrOfCacheObjects: 500,
  ),
);

ImageProvider cachedImage(String url) =>
    CachedNetworkImageProvider(url, cacheManager: _imageCache);
