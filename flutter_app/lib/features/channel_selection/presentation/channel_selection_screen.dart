import 'dart:async';

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
  static const int _maxCategoryLoadAttempts = 4;
  static const double _headerCompressOffset = 24;
  static const Map<String, Duration> _presetDurations = <String, Duration>{
    '30 mn': Duration(minutes: 30),
    '1 h': Duration(hours: 1),
    '6 h': Duration(hours: 6),
    '1 day': Duration(days: 1),
  };

  final TextEditingController _searchController = TextEditingController(
    text: 'V1:*',
  );
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _selectedChannelsScrollController = ScrollController();
  final ScrollController _availableChannelsScrollController =
      ScrollController();
  final Set<String> _selectedChannels = <String>{};
  List<ChannelSummary> _results = const <ChannelSummary>[];
  List<ChannelCategory> _categories = const <ChannelCategory>[];
  List<SavedChannelCategory> _savedCategories = const <SavedChannelCategory>[];
  bool _isFiltersHeaderCompact = false;
  bool _isSelectionHeaderCompact = false;
  bool _isLoading = false;
  bool _isLoadingCategories = false;
  bool _isLoadingSavedCategories = false;
  String? _error;
  String? _selectedCategory;
  String? _selectedSavedCategoryId;
  String? _selectionSourceSavedCategoryId;
  String _selectedPreset = '1 h';
  int _categoryLoadAttempts = 0;
  Timer? _categoryRetryTimer;
  DateTime _customStartLocal =
      DateTime.now().subtract(const Duration(hours: 1));

  @override
  void initState() {
    super.initState();
    _selectedChannelsScrollController.addListener(
      _handleSelectedChannelsScroll,
    );
    _availableChannelsScrollController.addListener(
      _handleAvailableChannelsScroll,
    );
    _loadCategories();
    _loadSavedCategories();
    _runSearch();
  }

  @override
  void dispose() {
    _categoryRetryTimer?.cancel();
    _selectedChannelsScrollController
      ..removeListener(_handleSelectedChannelsScroll)
      ..dispose();
    _availableChannelsScrollController
      ..removeListener(_handleAvailableChannelsScroll)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleSelectedChannelsScroll() {
    final shouldCompress = _selectedChannelsScrollController.hasClients &&
        _selectedChannelsScrollController.offset > _headerCompressOffset;
    if (shouldCompress == _isSelectionHeaderCompact || !mounted) {
      return;
    }
    setState(() {
      _isSelectionHeaderCompact = shouldCompress;
    });
  }

  void _handleAvailableChannelsScroll() {
    final shouldCompress = _availableChannelsScrollController.hasClients &&
        _availableChannelsScrollController.offset > _headerCompressOffset;
    if (shouldCompress == _isFiltersHeaderCompact || !mounted) {
      return;
    }
    setState(() {
      _isFiltersHeaderCompact = shouldCompress;
    });
  }

  Future<void> _loadCategories() async {
    if (_isLoadingCategories) {
      return;
    }
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
        _categoryLoadAttempts = categories.isEmpty ? _categoryLoadAttempts : 0;
      });
      if (categories.isEmpty) {
        _scheduleCategoryRetry();
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      _scheduleCategoryRetry();
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCategories = false;
        });
      }
    }
  }

  Future<void> _loadSavedCategories({String? selectedCategoryId}) async {
    if (_isLoadingSavedCategories) {
      return;
    }
    setState(() {
      _isLoadingSavedCategories = true;
    });

    try {
      final repository = ref.read(savedChannelCategoryRepositoryProvider);
      final categories = await repository.fetchSavedCategories();
      if (!mounted) {
        return;
      }
      final nextSelectedId = selectedCategoryId ?? _selectedSavedCategoryId;
      final resolvedSelectedId = categories.any(
        (SavedChannelCategory category) => category.id == nextSelectedId,
      )
          ? nextSelectedId
          : null;
      final resolvedSourceId = categories.any(
        (SavedChannelCategory category) =>
            category.id == _selectionSourceSavedCategoryId,
      )
          ? _selectionSourceSavedCategoryId
          : null;
      setState(() {
        _savedCategories = categories;
        _selectedSavedCategoryId = resolvedSelectedId;
        _selectionSourceSavedCategoryId = resolvedSourceId;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSavedCategories = false;
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
        limit: 10000,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _results = result.items;
      });
      if (_categories.isEmpty && !_isLoadingCategories) {
        unawaited(_loadCategories());
      }
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

  Future<void> _resetPlots() async {
    if (_selectedChannels.isEmpty) {
      return;
    }

    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Reset selection?'),
          content: Text(
            'Clear the current ${_selectedChannels.length}-channel selection?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );
    if (!mounted || shouldReset != true) {
      return;
    }

    setState(() {
      _selectedChannels.clear();
      _isSelectionHeaderCompact = false;
      _selectionSourceSavedCategoryId = null;
    });
    _showMessage('Channel selection cleared.');
  }

  void _openFiltersPanel() {
    if (_categories.isEmpty && !_isLoadingCategories) {
      unawaited(_loadCategories());
    }
    _scaffoldKey.currentState?.openEndDrawer();
  }

  Future<void> _saveCurrentSelectionAsCategory() async {
    if (_selectedChannels.isEmpty) {
      return;
    }

    final controller = TextEditingController();
    try {
      final label = await showDialog<String>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Save selection as config'),
            content: TextField(
              controller: controller,
              autofocus: true,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Config name',
                hintText: 'Example: Lock acquisition',
              ),
              onSubmitted: (String value) {
                final normalizedValue = value.trim();
                if (normalizedValue.isEmpty) {
                  return;
                }
                Navigator.of(context).pop(normalizedValue);
              },
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final normalizedValue = controller.text.trim();
                  if (normalizedValue.isEmpty) {
                    return;
                  }
                  Navigator.of(context).pop(normalizedValue);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );

      if (!mounted || label == null) {
        return;
      }

      final repository = ref.read(savedChannelCategoryRepositoryProvider);
      final channelNames = _selectedChannels.toList()..sort();
      final category = await repository.saveCategory(
        label: label,
        channelNames: channelNames,
      );
      final backupSuffix = await _backupSyncMessageSuffix();
      if (!mounted) {
        return;
      }

      await _loadSavedCategories(selectedCategoryId: category.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _selectionSourceSavedCategoryId = category.id;
      });
      _showMessage(
        'Saved config "${category.label}" (${category.count} channels).$backupSuffix',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(_normalizeErrorMessage(error));
    } finally {
      controller.dispose();
    }
  }

  Future<void> _editSavedCategory() async {
    final category = _selectedSavedCategory;
    if (category == null) {
      return;
    }

    final currentSelection = _selectedChannels.toList()..sort();
    final canUseCurrentSelection = currentSelection.isNotEmpty;
    final defaultUseCurrentSelection = canUseCurrentSelection &&
        (_selectionSourceSavedCategoryId == category.id ||
            _hasSameChannelSelection(category.channelNames));
    final controller = TextEditingController(text: category.label);
    var useCurrentSelection = defaultUseCurrentSelection;

    try {
      final editRequest = await showDialog<_SavedCategoryEditRequest>(
        context: context,
        builder: (BuildContext context) {
          final dialogTheme = Theme.of(context);
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setDialogState) {
              return AlertDialog(
                title: const Text('Edit saved config'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      TextField(
                        controller: controller,
                        autofocus: true,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'Config name',
                        ),
                        onSubmitted: (String value) {
                          final normalizedValue = value.trim();
                          if (normalizedValue.isEmpty) {
                            return;
                          }
                          Navigator.of(context).pop(
                            _SavedCategoryEditRequest(
                              label: normalizedValue,
                              useCurrentSelection: useCurrentSelection,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Channels',
                        style: dialogTheme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<bool>(
                        segments: <ButtonSegment<bool>>[
                          ButtonSegment<bool>(
                            value: false,
                            label: Text('Keep saved (${category.count})'),
                          ),
                          ButtonSegment<bool>(
                            value: true,
                            label: Text(
                              canUseCurrentSelection
                                  ? 'Use current (${currentSelection.length})'
                                  : 'Use current',
                            ),
                            enabled: canUseCurrentSelection,
                          ),
                        ],
                        selected: <bool>{useCurrentSelection},
                        multiSelectionEnabled: false,
                        onSelectionChanged: (Set<bool> selection) {
                          if (selection.isEmpty) {
                            return;
                          }
                          setDialogState(() {
                            useCurrentSelection = selection.first;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Text(
                        canUseCurrentSelection
                            ? 'Use the channels currently selected on the main screen to replace the saved channel list.'
                            : 'Select at least one channel to replace the saved channel list. You can still rename this config now.',
                        style: dialogTheme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () {
                      final normalizedValue = controller.text.trim();
                      if (normalizedValue.isEmpty) {
                        return;
                      }
                      Navigator.of(context).pop(
                        _SavedCategoryEditRequest(
                          label: normalizedValue,
                          useCurrentSelection: useCurrentSelection,
                        ),
                      );
                    },
                    child: const Text('Update'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (!mounted || editRequest == null) {
        return;
      }

      final repository = ref.read(savedChannelCategoryRepositoryProvider);
      final updatedCategory = await repository.updateCategory(
        id: category.id,
        label: editRequest.label,
        channelNames: editRequest.useCurrentSelection
            ? currentSelection
            : category.channelNames,
      );
      final backupSuffix = await _backupSyncMessageSuffix();
      if (!mounted) {
        return;
      }

      await _loadSavedCategories(selectedCategoryId: updatedCategory.id);
      if (!mounted) {
        return;
      }
      setState(() {
        if (editRequest.useCurrentSelection) {
          _selectionSourceSavedCategoryId = updatedCategory.id;
        }
      });
      _showMessage(
        'Updated config "${updatedCategory.label}" (${updatedCategory.count} channels).$backupSuffix',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(_normalizeErrorMessage(error));
    } finally {
      controller.dispose();
    }
  }

  Future<void> _loadSavedCategorySelection() async {
    final category = _selectedSavedCategory;
    if (category == null) {
      return;
    }

    if (_selectedChannels.isNotEmpty &&
        !_hasSameChannelSelection(category.channelNames)) {
      final shouldReplace = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Replace current selection?'),
            content: Text(
              'Load "${category.label}" and replace the current '
              '${_selectedChannels.length}-channel selection?',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Replace'),
              ),
            ],
          );
        },
      );
      if (!mounted || shouldReplace != true) {
        return;
      }
    }

    setState(() {
      _selectedChannels
        ..clear()
        ..addAll(category.channelNames);
      _selectionSourceSavedCategoryId = category.id;
    });
    _showMessage(
        'Loaded config "${category.label}" (${category.count} channels).');
  }

  Future<void> _deleteSavedCategory() async {
    final category = _selectedSavedCategory;
    if (category == null) {
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete saved config?'),
          content: Text(
            'Delete "${category.label}" from the saved configs list?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (!mounted || shouldDelete != true) {
      return;
    }

    final repository = ref.read(savedChannelCategoryRepositoryProvider);
    await repository.deleteCategory(category.id);
    final backupSuffix = await _backupSyncMessageSuffix();
    if (!mounted) {
      return;
    }
    if (_selectionSourceSavedCategoryId == category.id) {
      setState(() {
        _selectionSourceSavedCategoryId = null;
      });
    }
    await _loadSavedCategories();
    if (!mounted) {
      return;
    }
    _showMessage('Deleted config "${category.label}".$backupSuffix');
  }

  Future<void> _exportSavedConfigsBackup() async {
    try {
      final backupService = ref.read(savedChannelCategoryBackupServiceProvider);
      final hadConfiguredAutoBackup =
          backupService.hasConfiguredAutoBackupTarget;
      final savedPath = await backupService.exportBackup();
      if (!mounted || savedPath == null) {
        return;
      }
      setState(() {});
      final hasConfiguredAutoBackup =
          backupService.hasConfiguredAutoBackupTarget;
      if (!hadConfiguredAutoBackup && hasConfiguredAutoBackup) {
        _showMessage(
          'Backup folder configured. Saved configs will now keep this phone-storage backup updated automatically.',
        );
        return;
      }
      _showMessage('Backup synced to phone storage.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {});
      _showMessage(_normalizeErrorMessage(error));
    }
  }

  Future<void> _importSavedConfigsBackup() async {
    if (_savedCategories.isNotEmpty) {
      final shouldReplace = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Replace saved configs?'),
            content: Text(
              'Importing a backup will replace the current ${_savedCategories.length} saved configs.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Replace'),
              ),
            ],
          );
        },
      );
      if (!mounted || shouldReplace != true) {
        return;
      }
    }

    try {
      final backupService = ref.read(savedChannelCategoryBackupServiceProvider);
      final importResult = await backupService.importBackup();
      if (!mounted || importResult == null) {
        return;
      }

      await _loadSavedCategories();
      if (!mounted) {
        return;
      }
      _showMessage(
        'Imported ${importResult.categoryCount} saved configs from backup.${_autoBackupConfiguredSuffix()}',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(_normalizeErrorMessage(error));
    }
  }

  Future<String> _backupSyncMessageSuffix() async {
    final backupService = ref.read(savedChannelCategoryBackupServiceProvider);
    if (!backupService.hasConfiguredAutoBackupTarget) {
      return '';
    }

    try {
      final savedPath = await backupService.syncConfiguredBackup();
      if (savedPath == null) {
        return '';
      }
      return ' Backup updated.';
    } catch (error) {
      if (mounted) {
        setState(() {});
      }
      return ' Local changes were kept, but backup update failed: ${_normalizeErrorMessage(error)}';
    }
  }

  String _autoBackupConfiguredSuffix() {
    final backupService = ref.read(savedChannelCategoryBackupServiceProvider);
    return backupService.hasConfiguredAutoBackupTarget
        ? ' Backup updated.'
        : '';
  }

  void _selectAllVisibleChannels() {
    if (_results.isEmpty) {
      return;
    }
    setState(() {
      for (final ChannelSummary channel in _results) {
        _selectedChannels.add(channel.name);
      }
    });
  }

  void _unselectAllVisibleChannels() {
    if (_results.isEmpty) {
      return;
    }
    setState(() {
      for (final ChannelSummary channel in _results) {
        _selectedChannels.remove(channel.name);
      }
    });
  }

  void _scheduleCategoryRetry() {
    if (!mounted || _categories.isNotEmpty) {
      return;
    }
    if (_categoryLoadAttempts >= _maxCategoryLoadAttempts) {
      return;
    }
    _categoryRetryTimer?.cancel();
    _categoryLoadAttempts += 1;
    final delaySeconds = _categoryLoadAttempts == 1 ? 2 : 4;
    _categoryRetryTimer = Timer(Duration(seconds: delaySeconds), () {
      if (!mounted || _isLoadingCategories || _categories.isNotEmpty) {
        return;
      }
      unawaited(_loadCategories());
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final startLocal = _resolveStartLocal();
    final isWideLayout = MediaQuery.sizeOf(context).width >= 960;
    final selectedChannels = _selectedChannels.toList()..sort();

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('DataViewer'),
        actions: <Widget>[
          if (!isWideLayout)
            IconButton(
              onPressed: _openFiltersPanel,
              icon: const Icon(Icons.tune),
              tooltip: 'Filters',
            ),
        ],
      ),
      endDrawer: isWideLayout
          ? null
          : Drawer(
              width: 380,
              child: SafeArea(
                child: _buildFiltersPanel(
                  theme,
                  startLocal,
                  showDrawerHeading: true,
                ),
              ),
            ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: isWideLayout
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: _buildMainPanel(
                        theme,
                        startLocal,
                        selectedChannels,
                        isWideLayout: true,
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 380,
                      child: _buildFiltersPanel(theme, startLocal),
                    ),
                  ],
                )
              : _buildMainPanel(
                  theme,
                  startLocal,
                  selectedChannels,
                  isWideLayout: false,
                ),
        ),
      ),
    );
  }

  Widget _buildMainPanel(
    ThemeData theme,
    DateTime startLocal,
    List<String> selectedChannels, {
    required bool isWideLayout,
  }) {
    final isCompact = _isSelectionHeaderCompact && selectedChannels.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(isCompact ? 12 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (isCompact)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Selected channels',
                          style: theme.textTheme.titleLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        _buildSelectionActions(),
                      ],
                    )
                  else ...<Widget>[
                    Text(
                      'Selected channels',
                      style: theme.textTheme.titleLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Build the active query here. Use the Filters panel to search the available channels and add them to this list.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    _buildSelectionActions(),
                  ],
                  SizedBox(height: isCompact ? 8 : 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      _summaryChip(
                          theme, '${selectedChannels.length} selected'),
                      _summaryChip(
                        theme,
                        _selectedPreset == 'Custom'
                            ? 'Start ${_compactStartLabel(startLocal)}'
                            : 'Start $_selectedPreset ago',
                      ),
                      _summaryChip(
                        theme,
                        _selectedCategory == null
                            ? 'All categories'
                            : _selectedCategory!,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Text(
              _error!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        const SizedBox(height: 12),
        Expanded(
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: selectedChannels.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        isWideLayout
                            ? 'No channels selected yet. Use the panel on the right to choose channels.'
                            : 'No channels selected yet. Use the Filters icon to choose channels.',
                        style: theme.textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.separated(
                    controller: _selectedChannelsScrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: selectedChannels.length,
                    separatorBuilder: (BuildContext context, int index) {
                      return const Divider(height: 1);
                    },
                    itemBuilder: (BuildContext context, int index) {
                      final channelName = selectedChannels[index];
                      final channel = _findChannelSummary(channelName);
                      return ListTile(
                        dense: true,
                        title: Text(
                          channelName,
                          style: theme.textTheme.bodyMedium,
                        ),
                        subtitle: Text(
                          _selectedChannelSubtitle(channel),
                          style: theme.textTheme.bodySmall,
                        ),
                        trailing: IconButton(
                          onPressed: () {
                            setState(() {
                              _selectedChannels.remove(channelName);
                            });
                          },
                          icon: const Icon(Icons.close),
                          tooltip: 'Remove channel',
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionActions() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        FilledButton.tonal(
          onPressed: _selectedChannels.isEmpty ? null : _openPlots,
          child: const Text('Open plots'),
        ),
        OutlinedButton.icon(
          onPressed: _selectedChannels.isEmpty ? null : _resetPlots,
          icon: const Icon(Icons.restart_alt),
          label: const Text('Reset plots'),
        ),
      ],
    );
  }

  Widget _buildFiltersPanel(
    ThemeData theme,
    DateTime startLocal, {
    bool showDrawerHeading = false,
  }) {
    final isCompact = _isFiltersHeaderCompact && _results.isNotEmpty;
    final filtersHeader = AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Filters',
            style: theme.textTheme.titleLarge,
          ),
          if (!isCompact) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              'Search channels, choose the subsystem and start time, then tick the channels to add them to the main selection.',
              style: theme.textTheme.bodyMedium,
            ),
          ],
          SizedBox(height: isCompact ? 12 : 16),
          _buildFilterSearchRow(),
          const SizedBox(height: 12),
          _buildCategoryDropdown(),
          if (isCompact) ...<Widget>[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _summaryChip(
                  theme,
                  _selectedPreset == 'Custom'
                      ? 'Start ${_compactStartLabel(startLocal)}'
                      : 'Start $_selectedPreset ago',
                ),
                _summaryChip(
                  theme,
                  _selectedCategory == null
                      ? 'All categories'
                      : _selectedCategory!,
                ),
                _summaryChip(
                  theme,
                  '${_selectedChannels.length} selected',
                ),
              ],
            ),
          ] else ...<Widget>[
            const SizedBox(height: 16),
            _buildSavedCategoriesSection(theme),
            const SizedBox(height: 16),
            _buildStartTimeSection(theme, startLocal),
          ],
        ],
      ),
    );
    final availableChannelsSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Available channels',
                style: theme.textTheme.titleMedium,
              ),
            ),
            TextButton(
              onPressed: _results.isEmpty ? null : _selectAllVisibleChannels,
              child: const Text('Select all'),
            ),
            TextButton(
              onPressed: _visibleSelectedChannelCount == 0
                  ? null
                  : _unselectAllVisibleChannels,
              child: const Text('Unselect all'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Card(
            clipBehavior: Clip.antiAlias,
            margin: EdgeInsets.zero,
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
                        controller: _availableChannelsScrollController,
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
                            subtitle: Text(_channelSubtitle(channel)),
                            dense: true,
                            controlAffinity: ListTileControlAffinity.leading,
                          );
                        },
                      ),
          ),
        ),
      ],
    );
    final content = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Flexible(
            fit: FlexFit.loose,
            child: SingleChildScrollView(
              primary: false,
              child: filtersHeader,
            ),
          ),
          SizedBox(height: isCompact ? 12 : 16),
          Expanded(
            child: availableChannelsSection,
          ),
        ],
      ),
    );

    if (showDrawerHeading) {
      return content;
    }

    return Card(child: content);
  }

  Widget _buildFilterSearchRow() {
    return Row(
      children: <Widget>[
        Expanded(
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _runSearch(),
            decoration: const InputDecoration(
              hintText: 'Example: V1:* or V1:TCS*',
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
    );
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<String>(
      key: ValueKey<String?>(_selectedCategory),
      initialValue: _selectedCategory,
      isExpanded: true,
      decoration: InputDecoration(
        labelText:
            _isLoadingCategories ? 'Loading categories' : 'Subsystem category',
      ),
      items: <DropdownMenuItem<String>>[
        const DropdownMenuItem<String>(
          value: null,
          child: Text('All categories'),
        ),
        ..._categories.map((ChannelCategory category) {
          return DropdownMenuItem<String>(
            value: category.id,
            child: Text('${category.label} (${category.count})'),
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
    );
  }

  Widget _buildSavedCategoriesSection(ThemeData theme) {
    final backupService = ref.read(savedChannelCategoryBackupServiceProvider);
    final hasConfiguredAutoBackup = backupService.hasConfiguredAutoBackupTarget;
    const compactActionStyle = ButtonStyle(
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey<String?>(_selectedSavedCategoryId),
                initialValue: _selectedSavedCategoryId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: _isLoadingSavedCategories
                      ? 'Loading saved configs'
                      : 'Saved configs',
                ),
                items: <DropdownMenuItem<String>>[
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Select a saved config'),
                  ),
                  ..._savedCategories.map((SavedChannelCategory category) {
                    return DropdownMenuItem<String>(
                      value: category.id,
                      child: Text('${category.label} (${category.count})'),
                    );
                  }),
                ],
                onChanged: _isLoadingSavedCategories
                    ? null
                    : (String? value) {
                        setState(() {
                          _selectedSavedCategoryId = value;
                        });
                      },
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed:
                  _selectedSavedCategory == null ? null : _editSavedCategory,
              tooltip: 'Edit saved config',
              icon: const Icon(Icons.edit_outlined),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed:
                  _selectedSavedCategory == null ? null : _deleteSavedCategory,
              tooltip: 'Delete saved config',
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: FilledButton.tonal(
                onPressed: _selectedChannels.isEmpty
                    ? null
                    : _saveCurrentSelectionAsCategory,
                style: compactActionStyle,
                child: const Text('Save'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: _selectedSavedCategory == null
                    ? null
                    : _loadSavedCategorySelection,
                style: compactActionStyle,
                child: const Text('Load'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed:
                    _selectedSavedCategory == null ? null : _editSavedCategory,
                style: compactActionStyle,
                child: const Text('Update'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: _exportSavedConfigsBackup,
              icon: const Icon(Icons.upload_file_outlined),
              label:
                  Text(hasConfiguredAutoBackup ? 'Sync backup' : 'Set backup'),
            ),
            OutlinedButton.icon(
              onPressed: _importSavedConfigsBackup,
              icon: const Icon(Icons.download_for_offline_outlined),
              label: const Text('Import backup'),
            ),
          ],
        ),
        if (_selectedSavedCategory != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _savedConfigHint(_selectedSavedCategory!),
              style: theme.textTheme.bodySmall,
            ),
          ),
        if (_savedCategories.isEmpty && !_isLoadingSavedCategories)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Save the current channel selection as a named config to reuse it later. Load it, add or remove channels in the main selection, then use Update config to save the changes.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            hasConfiguredAutoBackup
                ? 'The backup file in phone storage is updated automatically whenever you save, update, delete, or import configs.'
                : 'Choose Set backup once to save configs into phone storage. After that, config changes keep dataviewer-saved-configs.json updated automatically and you can Import backup after reinstall.',
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  Widget _buildStartTimeSection(ThemeData theme, DateTime startLocal) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: <Widget>[
              ..._presetDurations.keys.map((String preset) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(preset),
                    selected: preset == _selectedPreset,
                    onSelected: (_) {
                      setState(() {
                        _selectedPreset = preset;
                      });
                    },
                  ),
                );
              }),
              ChoiceChip(
                label: const Text('Custom'),
                selected: _selectedPreset == 'Custom',
                onSelected: (_) => _pickCustomStart(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Start: ${_resolveStartLabel(startLocal)}',
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }

  ChannelSummary? _findChannelSummary(String channelName) {
    for (final ChannelSummary channel in _results) {
      if (channel.name == channelName) {
        return channel;
      }
    }
    return null;
  }

  static String _selectedChannelSubtitle(ChannelSummary? channel) {
    if (channel == null) {
      return 'Selected for plot query';
    }
    final parts = <String>[
      channel.category,
      if (channel.unit.isNotEmpty) channel.unit,
    ].where((String value) => value.trim().isNotEmpty).toList(growable: false);
    if (parts.isEmpty) {
      return 'Selected for plot query';
    }
    return parts.join('   ');
  }

  SavedChannelCategory? get _selectedSavedCategory {
    final selectedSavedCategoryId = _selectedSavedCategoryId;
    if (selectedSavedCategoryId == null) {
      return null;
    }
    for (final SavedChannelCategory category in _savedCategories) {
      if (category.id == selectedSavedCategoryId) {
        return category;
      }
    }
    return null;
  }

  bool _hasSameChannelSelection(List<String> channelNames) {
    return _selectedChannels.length == channelNames.length &&
        _selectedChannels.containsAll(channelNames);
  }

  String _savedConfigHint(SavedChannelCategory category) {
    if (_selectionSourceSavedCategoryId == category.id) {
      return 'The current selection is based on this config. Add or remove channels, then use Update config to save the edited channel list or rename it.';
    }
    return 'Load this config to edit its channels with the current selection, or open Update config to rename it without changing the saved channel list.';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  static String _normalizeErrorMessage(Object error) {
    final message = error.toString();
    const prefix = 'Bad state: ';
    if (message.startsWith(prefix)) {
      return message.substring(prefix.length);
    }
    return message;
  }

  int get _visibleSelectedChannelCount {
    var count = 0;
    for (final ChannelSummary channel in _results) {
      if (_selectedChannels.contains(channel.name)) {
        count += 1;
      }
    }
    return count;
  }

  Widget _summaryChip(ThemeData theme, String text) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: Text(
            text,
            style: theme.textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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

  static String _compactStartLabel(DateTime value) {
    final local = value.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}

class _SavedCategoryEditRequest {
  const _SavedCategoryEditRequest({
    required this.label,
    required this.useCurrentSelection,
  });

  final String label;
  final bool useCurrentSelection;
}
