class ChannelSummary {
  const ChannelSummary({
    required this.name,
    required this.displayName,
    required this.unit,
    required this.category,
    required this.sampleRateHz,
  });

  final String name;
  final String displayName;
  final String unit;
  final String category;
  final int sampleRateHz;

  factory ChannelSummary.fromJson(Map<String, dynamic> json) {
    return ChannelSummary(
      name: json['name'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      unit: json['unit'] as String? ?? '',
      category: json['category'] as String? ?? '',
      sampleRateHz: (json['sampleRateHz'] as num? ?? 1).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'displayName': displayName,
      'unit': unit,
      'category': category,
      'sampleRateHz': sampleRateHz,
    };
  }
}

class ChannelCategory {
  const ChannelCategory({
    required this.id,
    required this.label,
    required this.count,
  });

  final String id;
  final String label;
  final int count;

  factory ChannelCategory.fromJson(Map<String, dynamic> json) {
    return ChannelCategory(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      count: (json['count'] as num? ?? 0).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'id': id, 'label': label, 'count': count};
  }
}

class ChannelSearchResult {
  const ChannelSearchResult({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  final List<ChannelSummary> items;
  final int total;
  final int limit;
  final int offset;

  factory ChannelSearchResult.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List<dynamic>? ?? const <dynamic>[])
        .map(
          (dynamic item) =>
              ChannelSummary.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(growable: false);

    return ChannelSearchResult(
      items: items,
      total: (json['total'] as num? ?? items.length).toInt(),
      limit: (json['limit'] as num? ?? items.length).toInt(),
      offset: (json['offset'] as num? ?? 0).toInt(),
    );
  }
}

class SavedChannelCategory {
  const SavedChannelCategory({
    required this.id,
    required this.label,
    required this.channelNames,
  });

  final String id;
  final String label;
  final List<String> channelNames;

  int get count => channelNames.length;

  SavedChannelCategory copyWith({
    String? id,
    String? label,
    List<String>? channelNames,
  }) {
    return SavedChannelCategory(
      id: id ?? this.id,
      label: label ?? this.label,
      channelNames: channelNames ?? this.channelNames,
    );
  }

  factory SavedChannelCategory.fromJson(Map<String, dynamic> json) {
    final channelNames = (json['channelNames'] as List<dynamic>? ??
            const <dynamic>[])
        .map((dynamic item) => (item as String? ?? '').trim())
        .where((String value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false)
      ..sort();

    return SavedChannelCategory(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      channelNames: channelNames,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'label': label,
      'channelNames': channelNames,
    };
  }
}
