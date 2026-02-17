class Hospital {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double rating;
  final bool isOpen;

  Hospital({
    required this.id,
    required this.name,
    this.address = '',
    required this.latitude,
    required this.longitude,
    this.rating = 0.0,
    this.isOpen = false,
  });

  factory Hospital.fromJson(Map<String, dynamic> json) {
    return Hospital(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      address: json['address'] ?? json['vicinity'] ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      isOpen: json['isOpen'] ?? false,
    );
  }
}

