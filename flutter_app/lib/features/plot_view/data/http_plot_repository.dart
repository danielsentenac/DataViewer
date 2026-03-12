import 'package:dataviewer/core/networking/api_client.dart';
import 'package:dataviewer/features/plot_view/data/plot_repository.dart';
import 'package:dataviewer/shared/models/plot_models.dart';

class HttpPlotRepository implements PlotRepository {
  HttpPlotRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<LivePlotResponse> pollLive(LivePlotRequest request) async {
    final json = await _apiClient.postJson(
      '/api/v1/plots/live',
      data: request.toJson(),
    );
    return LivePlotResponse.fromJson(json);
  }

  @override
  Future<PlotQueryResponse> queryPlot(PlotQueryRequest request) async {
    final json = await _apiClient.postJson(
      '/api/v1/plots/query',
      data: request.toJson(),
    );
    return PlotQueryResponse.fromJson(json);
  }
}
