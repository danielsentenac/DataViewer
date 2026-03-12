import 'package:dataviewer/shared/models/channel_models.dart';

abstract class ChannelCatalogRepository {
  Future<ChannelSearchResult> searchChannels({
    required String query,
    String? category,
    int limit = 100,
    int offset = 0,
  });

  Future<List<ChannelCategory>> fetchCategories();
}
