import 'package:dataviewer/features/channel_selection/presentation/channel_selection_screen.dart';
import 'package:dataviewer/features/plot_view/presentation/plot_screen.dart';
import 'package:dataviewer/shared/models/plot_view_request.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/',
    routes: <GoRoute>[
      GoRoute(
        path: '/',
        builder: (context, state) => const ChannelSelectionScreen(),
      ),
      GoRoute(
        path: '/plots',
        builder: (context, state) =>
            PlotScreen(request: state.extra as PlotViewRequest?),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
