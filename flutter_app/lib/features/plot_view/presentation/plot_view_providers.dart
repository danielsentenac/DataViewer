import 'package:dataviewer/core/providers.dart';
import 'package:dataviewer/features/plot_view/data/http_plot_repository.dart';
import 'package:dataviewer/features/plot_view/data/plot_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final plotRepositoryProvider = Provider<PlotRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return HttpPlotRepository(client);
});
