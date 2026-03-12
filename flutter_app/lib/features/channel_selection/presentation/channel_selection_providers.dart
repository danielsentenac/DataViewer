import 'package:dataviewer/core/providers.dart';
import 'package:dataviewer/features/channel_selection/data/channel_catalog_repository.dart';
import 'package:dataviewer/features/channel_selection/data/http_channel_catalog_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final channelCatalogRepositoryProvider = Provider<ChannelCatalogRepository>((
  ref,
) {
  final client = ref.watch(apiClientProvider);
  return HttpChannelCatalogRepository(client);
});
