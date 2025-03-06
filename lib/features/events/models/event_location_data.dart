class EventLocationData {
  final String? venue;
  final String? city;
  final String? country;

  const EventLocationData({
    this.venue,
    this.city,
    this.country,
  });

  bool get isComplete => 
    venue != null && venue!.isNotEmpty &&
    city != null && city!.isNotEmpty &&
    country != null && country!.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'venue': venue,
    'city': city,
    'country': country,
  };

  factory EventLocationData.fromJson(Map<String, dynamic> json) {
    return EventLocationData(
      venue: json['venue'] as String?,
      city: json['city'] as String?,
      country: json['country'] as String?,
    );
  }

  EventLocationData copyWith({
    String? venue,
    String? city,
    String? country,
  }) {
    return EventLocationData(
      venue: venue ?? this.venue,
      city: city ?? this.city,
      country: country ?? this.country,
    );
  }
}
