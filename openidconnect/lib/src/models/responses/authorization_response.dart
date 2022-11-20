part of openidconnect;

class AuthorizationResponse extends TokenResponse {
  final String accessToken;
  final String? refreshToken;
  final String idToken;
  final String? state;

  AuthorizationResponse({
    required this.accessToken,
    required this.idToken,
    this.refreshToken,
    this.state,
    required String tokenType,
    DateTime? expiresAt,
    Map<String, dynamic>? additionalProperties,
  }) : super(
          tokenType: tokenType,
          expiresAt: expiresAt,
          additionalProperties: additionalProperties,
        );

  factory AuthorizationResponse.fromJson(
    Map<String, dynamic> json, {
    String? state,
  }) {
    DateTime? getExpiredAt() {
      final dynamic expiresIn = json['expires_in'];
      if (expiresIn == null || expiresIn is! int) {
        return null;
      }
      return DateTime.now().add(
        Duration(seconds: expiresIn),
      );
    }

    return AuthorizationResponse(
      accessToken: json["access_token"].toString(),
      tokenType: json["token_type"].toString(),
      idToken: json["id_token"].toString(),
      refreshToken: json["refresh_token"]?.toString(),
      expiresAt: getExpiredAt(),
      additionalProperties: json,
      state: state,
    );
  }
}
