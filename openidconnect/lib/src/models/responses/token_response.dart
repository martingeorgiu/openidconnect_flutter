part of openidconnect;

class TokenResponse {
  final String tokenType;
  final Map<String, dynamic>? additionalProperties;
  final DateTime? expiresAt;

  const TokenResponse({
    required this.tokenType,
    this.expiresAt,
    this.additionalProperties,
  });
}
