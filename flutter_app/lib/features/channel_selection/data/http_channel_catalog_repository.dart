import 'package:dataviewer/core/networking/api_client.dart';
import 'package:dataviewer/features/channel_selection/data/channel_catalog_repository.dart';
import 'package:dataviewer/shared/models/channel_models.dart';

class HttpChannelCatalogRepository implements ChannelCatalogRepository {
  HttpChannelCatalogRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<List<ChannelCategory>> fetchCategories() async {
    final json = await _apiClient.getJson('/api/v1/channels/categories');
    return (json['items'] as List<dynamic>? ?? const <dynamic>[])
        .map(
          (dynamic item) =>
              ChannelCategory.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(growable: false);
  }

  @override
  Future<ChannelSearchResult> searchChannels({
    required String query,
    String? category,
    int limit = 100,
    int offset = 0,
  }) async {
    final json = await _apiClient.getJson(
      '/api/v1/channels/search',
      queryParameters: <String, dynamic>{
        'q': query,
        'category': category,
        'limit': limit,
        'offset': offset,
      },
    );

    return ChannelSearchResult.fromJson(json);
  }
}
