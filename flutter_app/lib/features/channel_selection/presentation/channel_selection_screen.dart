import 'package:dataviewer/features/channel_selection/presentation/channel_selection_providers.dart';
import 'package:dataviewer/shared/models/channel_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ChannelSelectionScreen extends ConsumerStatefulWidget {
  const ChannelSelectionScreen({super.key});

  @override
  ConsumerState<ChannelSelectionScreen> createState() =>
      _ChannelSelectionScreenState();
}

class _ChannelSelectionScreenState
    extends ConsumerState<ChannelSelectionScreen> {
  static const List<String> _presets = <String>[
    '30 min',
    '1 h',
    '6 h',
    '12 h',
    '1 day',
    '7 days',
  ];

  final TextEditingController _searchController = TextEditingController(
    text: 'VAC*',
  );
  final Set<String> _selectedChannels = <String>{};
  List<ChannelSummary> _results = const <ChannelSummary>[];
  bool _isLoading = false;
  String? _error;
  String _selectedPreset = _presets[1];

  @override
  void initState() {
    super.initState();
    _runSearch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repository = ref.read(channelCatalogRepositoryProvider);
      final result = await repository.searchChannels(
        query: _searchController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _results = result.items;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('DataViewer')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Channel selection',
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Search by channel name or wildcard, pick a preset start range, then move to the plot workspace.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              textInputAction: TextInputAction.search,
                              onSubmitted: (_) => _runSearch(),
                              decoration: const InputDecoration(
                                hintText: 'Example: VAC* or V1:VAC-CRYO_*',
                                prefixIcon: Icon(Icons.search),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            onPressed: _isLoading ? null : _runSearch,
                            child: const Text('Search'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _presets
                            .map((String preset) {
                              return ChoiceChip(
                                label: Text(preset),
                                selected: preset == _selectedPreset,
                                onSelected: (_) {
                                  setState(() {
                                    _selectedPreset = preset;
                                  });
                                },
                              );
                            })
                            .toList(growable: false),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _error!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              Row(
                children: <Widget>[
                  Text(
                    'Selected: ${_selectedChannels.length}',
                    style: theme.textTheme.titleMedium,
                  ),
                  const Spacer(),
                  FilledButton.tonal(
                    onPressed: _selectedChannels.isEmpty
                        ? null
                        : () => context.go('/plots'),
                    child: const Text('Open plots'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Card(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _results.length,
                          separatorBuilder: (BuildContext context, int index) {
                            return const Divider(height: 1);
                          },
                          itemBuilder: (BuildContext context, int index) {
                            final channel = _results[index];
                            final isSelected = _selectedChannels.contains(
                              channel.name,
                            );
                            return CheckboxListTile(
                              value: isSelected,
                              onChanged: (bool? value) {
                                setState(() {
                                  if (value ?? false) {
                                    _selectedChannels.add(channel.name);
                                  } else {
                                    _selectedChannels.remove(channel.name);
                                  }
                                });
                              },
                              title: Text(channel.name),
                              subtitle: Text(
                                '${channel.displayName}   ${channel.category}   ${channel.unit}',
                              ),
                              dense: true,
                              controlAffinity: ListTileControlAffinity.leading,
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
