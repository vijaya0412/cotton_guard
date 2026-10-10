/// User profile and credentials model.
class UserProfile {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String location;
  final double? latitude;
  final double? longitude;
  final String role; // 'Farmer', 'Agronomist', 'Researcher', 'Student'
  final String? profileImagePath;
  final DateTime createdAt;

  UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone = '',
    this.location = 'Warangal, Telangana',
    this.latitude,
    this.longitude,
    this.role = 'Cotton Farmer',
    this.profileImagePath,
    required this.createdAt,
  });

  UserProfile copyWith({
    String? id,
    String? fullName,
    String? email,
    String? phone,
    String? location,
    double? latitude,
    double? longitude,
    String? role,
    String? profileImagePath,
    bool clearProfileImage = false,
    DateTime? createdAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      role: role ?? this.role,
      profileImagePath:
          clearProfileImage ? null : (profileImagePath ?? this.profileImagePath),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final rawDate = json['createdAt'] ?? json['created_at'];
    DateTime date;
    if (rawDate != null) {
      date = DateTime.tryParse(rawDate.toString()) ?? DateTime.now();
    } else {
      date = DateTime.now();
    }

    return UserProfile(
      id: (json['id'] as String?) ?? 'usr_${DateTime.now().millisecondsSinceEpoch}',
      fullName: (json['fullName'] ?? json['full_name'] as String?) ?? 'Farmer',
      email: (json['email'] as String?) ?? '',
      phone: (json['phone'] as String?) ?? '',
      location: (json['location'] as String?) ?? 'Warangal, Telangana',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      role: (json['role'] as String?) ?? 'Cotton Farmer',
      profileImagePath: (json['profileImagePath'] ?? json['profile_image_url']) as String?,
      createdAt: date,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'role': role,
      'profileImagePath': profileImagePath,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static UserProfile defaultFarmer() {
    return UserProfile(
      id: 'farmer_01',
      fullName: 'Ramesh Patel',
      email: 'ramesh.farmer@cottonguard.org',
      phone: '+91 98480 12345',
      location: 'Warangal, Telangana',
      latitude: 17.9784,
      longitude: 79.5941,
      role: 'Cotton Grower',
      profileImagePath: null,
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
    );
  }

  static UserProfile guestFarmer() {
    return UserProfile(
      id: 'guest_${DateTime.now().millisecondsSinceEpoch}',
      fullName: 'Farmer',
      email: '',
      phone: '',
      location: 'Warangal, Telangana',
      latitude: 17.9784,
      longitude: 79.5941,
      role: 'Guest Farmer',
      profileImagePath: null,
      createdAt: DateTime.now(),
    );
  }
}

