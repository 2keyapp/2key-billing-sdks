/// Capability credential JSON returned by billing Machine AuthN.
class CapabilityCredential {
  const CapabilityCredential({required this.raw});

  factory CapabilityCredential.fromJson(Map<String, dynamic> json) {
    return CapabilityCredential(raw: Map<String, dynamic>.from(json));
  }

  final Map<String, dynamic> raw;

  String? get ski => raw['ski'] as String?;
  String? get kind => raw['kind'] as String?;
  String? get entityId => raw['entityId'] as String?;

  Map<String, dynamic> toJson() => Map<String, dynamic>.from(raw);
}

/// Capability set entry for assert-subset.
class CapabilityEntry {
  const CapabilityEntry({
    required this.action,
    this.scope = const {},
    this.delegable,
  });

  factory CapabilityEntry.fromJson(Map<String, dynamic> json) {
    return CapabilityEntry(
      action: json['action'] as String? ?? '',
      scope: json['scope'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['scope'] as Map)
          : const {},
      delegable: json['delegable'] as bool?,
    );
  }

  final String action;
  final Map<String, dynamic> scope;
  final bool? delegable;

  Map<String, dynamic> toJson() => {
        'action': action,
        'scope': scope,
        if (delegable != null) 'delegable': delegable,
      };
}
