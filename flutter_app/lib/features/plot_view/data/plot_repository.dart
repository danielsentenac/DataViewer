import 'package:dataviewer/shared/models/plot_models.dart';

abstract class PlotRepository {
  Future<PlotQueryResponse> queryPlot(PlotQueryRequest request);

  Future<LivePlotResponse> pollLive(LivePlotRequest request);
}
