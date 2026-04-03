class VehicleMedia {
  final String id;
  final String url;
  final bool isVideo;
  final String type;

  VehicleMedia({
    required this.id,
    required this.url,
    required this.isVideo,
    required this.type,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'url': url,
      'isVideo': isVideo,
      'type': type,
    };
  }

  factory VehicleMedia.fromMap(Map<String, dynamic> map) {
    return VehicleMedia(
      id: map['id'] ?? '',
      url: map['url'] ?? '',
      isVideo: map['isVideo'] ?? false,
      type: map['type'] ?? '',
    );
  }
}
