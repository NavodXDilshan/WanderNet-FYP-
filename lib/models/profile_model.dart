class ProfileModel {
  String? username;
  String? firstName;
  String? lastName;
  String? phone;
  String? bio;
  String? country;
  String? city;
  String? userAvatar;

  ProfileModel({
    this.username,
    this.firstName,
    this.lastName,
    this.phone,
    this.bio,
    this.country,
    this.city,
    this.userAvatar,
  });

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'firstName': firstName,
      'lastName': lastName,
      'phone': phone,
      'bio': bio,
      'country': country,
      'city': city,
      'userAvatar': userAvatar,
    };
  }

  factory ProfileModel.fromMap(Map<String, dynamic> map) {
    return ProfileModel(
      username: map['username'] as String?,
      firstName: map['firstName'] as String?,
      lastName: map['lastName'] as String?,
      phone: map['phone'] as String?,
      bio: map['bio'] as String?,
      country: map['country'] as String?,
      city: map['city'] as String?,
      userAvatar: map['userAvatar'] as String?,
    );
  }
}