import 'package:dataviewer/features/channel_selection/presentation/channel_selection_providers.dart';
import 'package:dataviewer/shared/models/channel_models.dart';
import 'package:dataviewer/shared/models/plot_view_request.dart';
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
  static const Map<String, Duration> _presetDurations = <String, Duration>{
    '30 min': Duration(minutes: 30),
    '1 h': Duration(hours: 1),
    '6 h': Duration(hours: 6),
    '12 h': Duration(hours: 12),
    '1 day': Duration(days: 1),
    '7 days': Duration(days: 7),
  };

  final TextEditingController _searchController = TextEditingController(
    text: 'TCS*',
  );
  final Set<String> _selectedChannels = <String>{};
  List<ChannelSummary> _results = const <ChannelSummary>[];
  List<ChannelCategory> _categories = const <ChannelCategory>[];
  bool _isLoading = false;
  bool _isLoadingCategories = false;
  String? _error;
  String? _selectedCategory;
  String _selectedPreset = '1 h';
  DateTime _customStartLocal =
      DateTime.now().subtract(const Duration(hours: 1));

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _runSearch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoadingCategories = true;
    });

    try {
      final repository = ref.read(channelCatalogRepositoryProvider);
      final categories = await repository.fetchCategories();
      if (!mounted) {
        return;
      }
      setState(() {
        _categories = categories;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _categories = const <ChannelCategory>[];
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCategories = false;
        });
      }
    }
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
        category: _selectedCategory,
        limit: 150,
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

  Future<void> _pickCustomStart() async {
    final localNow = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _customStartLocal,
      firstDate: DateTime(2002),
      lastDate: localNow,
    );
    if (!mounted || pickedDate == null) {
      return;
    }

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_customStartLocal),
    );
    if (!mounted || pickedTime == null) {
      return;
    }

    final candidate = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    setState(() {
      _customStartLocal = candidate;
      _selectedPreset = 'Custom';
    });
  }

  DateTime _resolveStartLocal() {
    final presetDuration = _presetDurations[_selectedPreset];
    if (presetDuration != null) {
      return DateTime.now().subtract(presetDuration);
    }
    return _customStartLocal;
  }

  String _resolveStartLabel(DateTime value) {
    final local = value.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')} '
        '(UTC${_formatOffset(local.timeZoneOffset)})';
  }

  void _openPlots() {
    final sortedChannels = _selectedChannels.toList()..sort();
    final request = PlotViewRequest(
      channels: sortedChannels,
      startLocal: _resolveStartLocal(),
      sourceLabel: _selectedPreset,
    );
    context.push('/plots', extra: request);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final startLocal = _resolveStartLocal();
    final selectedChannelChips =
        (_selectedChannels.toList()..sort()).map((String channel) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: InputChip(
          label: Text(channel),
          onDeleted: () {
            setState(() {
              _selectedChannels.remove(channel);
            });
          },
        ),
      );
    }).toList(growable: false);

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
                        'Search by name or wildcard, narrow by subsystem, then choose the local start time that will be translated to GPS on the backend.',
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
                                hintText: 'Example: V1:TCS* or VAC*',
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
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: ValueKey<String?>(_selectedCategory),
                        initialValue: _selectedCategory,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: _isLoadingCategories
                              ? 'Loading categories'
                              : 'Subsystem category',
                        ),
                        items: <DropdownMenuItem<String>>[
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('All categories'),
                          ),
                          ..._categories.map((ChannelCategory category) {
                            return DropdownMenuItem<String>(
                              value: category.id,
                              child: Text(
                                '${category.label} (${category.count})',
                              ),
                            );
                          }),
                        ],
                        onChanged: _isLoadingCategories
                            ? null
                            : (String? value) {
                                setState(() {
                                  _selectedCategory = value;
                                });
                                _runSearch();
                              },
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          ..._presetDurations.keys.map((String preset) {
                            return ChoiceChip(
                              label: Text(preset),
                              selected: preset == _selectedPreset,
                              onSelected: (_) {
                                setState(() {
                                  _selectedPreset = preset;
                                });
                              },
                            );
                          }),
                          ChoiceChip(
                            label: const Text('Custom'),
                            selected: _selectedPreset == 'Custom',
                            onSelected: (_) => _pickCustomStart(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              'Start: ${_resolveStartLabel(startLocal)}',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _pickCustomStart,
                            icon: const Icon(Icons.schedule),
                            label: const Text('Pick'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_selectedChannels.isNotEmpty) ...<Widget>[
                Text(
                  'Selected channels',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 42,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: selectedChannelChips,
                  ),
                ),
                const SizedBox(height: 8),
              ],
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
                    onPressed: _selectedChannels.isEmpty ? null : _openPlots,
                    child: const Text('Open plots'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Card(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _results.isEmpty
                          ? Center(
                              child: Text(
                                'No channels matched this search.',
                                style: theme.textTheme.titleMedium,
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: _results.length,
                              separatorBuilder:
                                  (BuildContext context, int index) {
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
                                  subtitle: Text(_channelSubtitle(channel)),
                                  dense: true,
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
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

  static String _channelSubtitle(ChannelSummary channel) {
    final parts = <String>[
      channel.displayName,
      channel.category,
      if (channel.unit.isNotEmpty) channel.unit,
    ].where((String value) => value.trim().isNotEmpty).toList(growable: false);
    return parts.join('   ');
  }

  static String _formatOffset(Duration offset) {
    final totalMinutes = offset.inMinutes.abs();
    final sign = offset.isNegative ? '-' : '+';
    final hours = (totalMinutes ~/ 60).toString().padLeft(2, '0');
    final minutes = (totalMinutes % 60).toString().padLeft(2, '0');
    return '$sign$hours:$minutes';
  }
}
