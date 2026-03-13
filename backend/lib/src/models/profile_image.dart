class ProfileImage {
  final String id;
  final String userId;
  final String filePath;
  final int fileSizeBytes;
  final String originalFormat;
  final String storedFormat;
  final int widthPx;
  final int heightPx;
  final bool isActive;
  final DateTime uploadedAt;
  final DateTime? deletedAt;

  ProfileImage({
    required this.id,
    required this.userId,
    required this.filePath,
    required this.fileSizeBytes,
    required this.originalFormat,
    this.storedFormat = 'jpeg',
    this.widthPx = 500,
    this.heightPx = 500,
    this.isActive = false,
    required this.uploadedAt,
    this.deletedAt,
  });

  /// Check if this image is soft-deleted
  bool get isDeleted => deletedAt != null;

  /// Convert to JSON for API responses
  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'filePath': filePath,
    'fileSizeBytes': fileSizeBytes,
    'originalFormat': originalFormat,
    'storedFormat': storedFormat,
    'widthPx': widthPx,
    'heightPx': heightPx,
    'isActive': isActive,
    'uploadedAt': uploadedAt.toIso8601String(),
    'deletedAt': deletedAt?.toIso8601String(),
  };

  /// Create from JSON
  factory ProfileImage.fromJson(Map<String, dynamic> json) => ProfileImage(
    id: json['id'] as String,
    userId: json['userId'] as String? ?? json['user_id'] as String,
    filePath: json['filePath'] as String? ?? json['file_path'] as String,
    fileSizeBytes: json['fileSizeBytes'] as int? ?? json['file_size_bytes'] as int,
    originalFormat: json['originalFormat'] as String? ?? json['original_format'] as String,
    storedFormat: json['storedFormat'] as String? ?? json['stored_format'] as String? ?? 'jpeg',
    widthPx: json['widthPx'] as int? ?? json['width_px'] as int? ?? 500,
    heightPx: json['heightPx'] as int? ?? json['height_px'] as int? ?? 500,
    isActive: json['isActive'] as bool? ?? json['is_active'] as bool? ?? false,
    uploadedAt: DateTime.parse(json['uploadedAt'] as String? ?? json['uploaded_at'] as String),
    deletedAt: json['deletedAt'] != null 
      ? DateTime.parse(json['deletedAt'] as String)
      : (json['deleted_at'] != null
        ? DateTime.parse(json['deleted_at'] as String)
        : null),
  );

  /// Create a copy with modified fields
  ProfileImage copyWith({
    String? id,
    String? userId,
    String? filePath,
    int? fileSizeBytes,
    String? originalFormat,
    String? storedFormat,
    int? widthPx,
    int? heightPx,
    bool? isActive,
    DateTime? uploadedAt,
    DateTime? deletedAt,
  }) => ProfileImage(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    filePath: filePath ?? this.filePath,
    fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
    originalFormat: originalFormat ?? this.originalFormat,
    storedFormat: storedFormat ?? this.storedFormat,
    widthPx: widthPx ?? this.widthPx,
    heightPx: heightPx ?? this.heightPx,
    isActive: isActive ?? this.isActive,
    uploadedAt: uploadedAt ?? this.uploadedAt,
    deletedAt: deletedAt ?? this.deletedAt,
  );

  @override
  String toString() => 'ProfileImage(id: $id, userId: $userId, active: $isActive, deleted: $isDeleted)';
}
