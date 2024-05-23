part of openidconnect;

class SelfSignedInAppBrowser extends InAppBrowser {
  final _authCompleter = Completer<String>();
  Future<String> get authResult => _authCompleter.future;

  final String redirectUrl;
  final List<String> certificates;
  final bool includeRoots;

  SelfSignedInAppBrowser({
    required this.redirectUrl,
    required this.certificates,
    required this.includeRoots,
  });

  ServerTrustAuthResponse get proceedResponse =>
      ServerTrustAuthResponse(action: ServerTrustAuthResponseAction.PROCEED);

  ServerTrustAuthResponse? get cancelResponse => includeRoots
      ? null
      : ServerTrustAuthResponse(action: ServerTrustAuthResponseAction.CANCEL);

  String prefixCertificate(String certificate) =>
      '-----BEGIN CERTIFICATE-----\n$certificate\n-----END CERTIFICATE-----';

  @override
  Future<ServerTrustAuthResponse?>? onReceivedServerTrustAuthRequest(
      URLAuthenticationChallenge challenge) async {
    final incomingCertificate =
        challenge.protectionSpace.sslCertificate?.x509Certificate?.encoded;
    if (incomingCertificate == null) return cancelResponse;

    final incomingBase64Certificate = base64Encode(incomingCertificate);

    for (final certificate in certificates) {
      /// If the certificate is in the list of trusted certificates, we proceed with the request
      if (incomingBase64Certificate == certificate) return proceedResponse;

      final incomingCert = X509Utils.x509CertificateFromPem(
          prefixCertificate(incomingBase64Certificate));
      final trustedCertificate = X509Utils.x509CertificateFromPem(certificate);

      final chainValidator =
          X509Utils.checkChain([incomingCert, trustedCertificate]);
      // If the certificate is signed by the trusted certificate, we proceed with the request
      if (chainValidator.pairs?[0].signatureMatch == true) {
        return proceedResponse;
      }
    }

    // If the certificate is not in the list of trusted certificates or it is not signed by one of the trusted certificates, we cancel the request
    return cancelResponse;
  }

  @override
  void onExit() {
    if (!_authCompleter.isCompleted) {
      _authCompleter.completeError(
          'The window was closed before the authentication was completed.');
    }
  }

  @override
  void onReceivedError(WebResourceRequest request, WebResourceError error) {
    final url = request.url.toString();

    /// The server returned the redirect URL with the auth code
    /// This library automatically sends custom schema as an error,
    /// therefore we need to use this callback
    if (url.startsWith(redirectUrl)) {
      _authCompleter.complete(url);
      unawaited(close());
    }
  }
}

class OpenIdConnectAndroidiOS {
  static Future<String> authorizeInteractiveWithCertificate({
    required String authorizationUrl,
    required String redirectUrl,
    required List<String> certificates,
    required bool includeRoots,
  }) async {
    final browser = SelfSignedInAppBrowser(
      redirectUrl: redirectUrl,
      certificates: certificates,
      includeRoots: includeRoots,
    );

    final settings = InAppBrowserClassSettings(
        browserSettings:
            InAppBrowserSettings(hideUrlBar: true, hideToolbarBottom: true),
        webViewSettings: InAppWebViewSettings(
            javaScriptEnabled: true, isInspectable: kDebugMode));

    await browser.openUrlRequest(
        urlRequest: URLRequest(url: WebUri(authorizationUrl)),
        settings: settings);

    final result = await browser.authResult;
    return result;
  }

  static Future<String> authorizeInteractive({
    required BuildContext context,
    String? title,
    required String authorizationUrl,
    required String redirectUrl,
    required int popupWidth,
    required int popupHeight,
    bool useBottomDialog = false,
  }) async {
    final controller = flutterWebView.WebViewController()
      ..setJavaScriptMode(flutterWebView.JavaScriptMode.unrestricted);

    if (useBottomDialog) {
      final result = await showModalBottomSheet<String?>(
        context: context,
        isDismissible: false,
        enableDrag: false,
        isScrollControlled: true,
        builder: (_) {
          return _OpenIdConnectBottomSheet(
              authorizationUrl, redirectUrl, controller);
        },
      );

      if (result == null) throw AuthenticationException(ERROR_USER_CLOSED);
      return result;
    } else {
      final result = await showDialog<String?>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            actions: [
              IconButton(
                onPressed: () => Navigator.pop(dialogContext, null),
                icon: Icon(Icons.close),
              ),
            ],
            content: Container(
              width:
                  min(popupWidth.toDouble(), MediaQuery.of(context).size.width),
              height: min(
                  popupHeight.toDouble(), MediaQuery.of(context).size.height),
              child: flutterWebView.WebViewWidget(
                controller: controller
                  ..setNavigationDelegate(
                    flutterWebView.NavigationDelegate(
                      onPageFinished: (String url) {
                        if (url.startsWith(redirectUrl)) {
                          Navigator.pop(dialogContext, url);
                        }
                      },
                    ),
                  )
                  ..loadRequest(Uri.parse(authorizationUrl)),
              ),
            ),
            title: title != null ? Text(title) : SizedBox.shrink(),
          );
        },
      );

      if (result == null) throw AuthenticationException(ERROR_USER_CLOSED);
      return result;
    }
  }
}

class _OpenIdConnectBottomSheet extends StatefulWidget {
  final String authorizationUrl;
  final String redirectUrl;
  final flutterWebView.WebViewController controller;
  const _OpenIdConnectBottomSheet(
      this.authorizationUrl, this.redirectUrl, this.controller);

  @override
  State<_OpenIdConnectBottomSheet> createState() =>
      __OpenIdConnectBottomSheetState();
}

class __OpenIdConnectBottomSheetState extends State<_OpenIdConnectBottomSheet> {
  bool showWebView = true;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      height: MediaQuery.of(context).size.height * .9,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          InkWell(
            onTap: () => Navigator.pop(context, null),
            child: Padding(
              padding: EdgeInsets.all(4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('cancel'),
                  Icon(Icons.close),
                ],
              ),
            ),
          ),
          Expanded(
              child: showWebView
                  ? flutterWebView.WebViewWidget(
                      controller: widget.controller
                        ..setNavigationDelegate(
                          flutterWebView.NavigationDelegate(
                            onPageFinished: (String url) {
                              if (url.startsWith(widget.redirectUrl)) {
                                setState(() {
                                  showWebView = false;
                                });
                                Navigator.pop(context, url);
                              }
                            },
                          ),
                        )
                        ..loadRequest(Uri.parse(widget.authorizationUrl)),
                    )
                  : SizedBox.shrink()),
        ],
      ),
    );
  }
}
