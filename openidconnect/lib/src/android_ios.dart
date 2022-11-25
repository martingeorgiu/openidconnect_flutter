part of openidconnect;

class OpenIdConnectAndroidiOS {
  static Future<String> authorizeInteractive({
    required BuildContext context,
    String? title,
    required String authorizationUrl,
    required String redirectUrl,
    required int popupWidth,
    required int popupHeight,
    bool useBottomDialog = false,
  }) async {
    if (useBottomDialog) {
      final result = await showModalBottomSheet<String?>(
        context: context,
        isDismissible: false,
        enableDrag: false,
        isScrollControlled: true,
        builder: (_) {
          return _OpenIdConnectBottomSheet(authorizationUrl, redirectUrl);
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
              child: flutterWebView.WebView(
                javascriptMode: flutterWebView.JavascriptMode.unrestricted,
                initialUrl: authorizationUrl,
                onPageFinished: (url) {
                  if (url.startsWith(redirectUrl)) {
                    Navigator.pop(dialogContext, url);
                  }
                },
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
  const _OpenIdConnectBottomSheet(this.authorizationUrl, this.redirectUrl);

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
                  ? flutterWebView.WebView(
                      javascriptMode:
                          flutterWebView.JavascriptMode.unrestricted,
                      initialUrl: widget.authorizationUrl,
                      onPageStarted: (url) {
                        if (url.startsWith(widget.redirectUrl)) {
                          setState(() {
                            showWebView = false;
                          });
                          Navigator.pop(context, url);
                        }
                      },
                    )
                  : SizedBox.shrink()),
        ],
      ),
    );
  }
}
