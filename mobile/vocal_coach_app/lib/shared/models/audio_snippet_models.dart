class AudioSnippet {
  AudioSnippet({
    required this.snippetId,
    required this.sessionId,
    required this.contentType,
    required this.durationSec,
    required this.storageBackend,
    required this.storagePath,
    required this.sizeBytes,
    required this.createdAt,
    required this.expiresAt,
  });

  final String snippetId;
  final String sessionId;
  final String contentType;
  final double durationSec;
  final String storageBackend;
  final String storagePath;
  final int sizeBytes;
  final int createdAt;
  final int expiresAt;

  factory AudioSnippet.fromJson(Map<String, dynamic> json) {
    return AudioSnippet(
      snippetId: json['snippet_id'] as String,
      sessionId: json['session_id'] as String,
      contentType: json['content_type'] as String,
      durationSec: (json['duration_sec'] as num).toDouble(),
      storageBackend: json['storage_backend'] as String,
      storagePath: json['storage_path'] as String,
      sizeBytes: (json['size_bytes'] as num).toInt(),
      createdAt: (json['created_at'] as num).toInt(),
      expiresAt: (json['expires_at'] as num).toInt(),
    );
  }
}

class AudioSnippetList {
  AudioSnippetList({required this.sessionId, required this.snippets});

  final String sessionId;
  final List<AudioSnippet> snippets;

  factory AudioSnippetList.fromJson(Map<String, dynamic> json) {
    final snippets = (json['snippets'] as List<dynamic>)
        .map((item) => AudioSnippet.fromJson(item as Map<String, dynamic>))
        .toList();
    return AudioSnippetList(
      sessionId: json['session_id'] as String,
      snippets: snippets,
    );
  }
}
