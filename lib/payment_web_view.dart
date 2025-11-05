import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PaymentWebView extends StatefulWidget {
  final String url;
  final String? page;
  const PaymentWebView({super.key, required this.url, this.page});

  @override
  State<PaymentWebView> createState() => _PaymentWebViewState();
}

class _PaymentWebViewState extends State<PaymentWebView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              onNavigationRequest: (request) {
                print("Navigating to: ${request.url}");
                final uri = Uri.parse(request.url);

                if (uri.host == "hoppr-face-two-dbe557472d7f.herokuapp.com" &&
                    uri.path == "/api/users/wallet-callback") {
                  final status = uri.queryParameters["status"];
                  final txRef = uri.queryParameters["tx_ref"];
                  final transactionId = uri.queryParameters["transaction_id"];

                  if (status == "successful") {
                    Navigator.pop(context, {
                      "status": "success",
                      "txRef": txRef,
                      "transactionId": transactionId,
                    });
                  } else {
                    Navigator.pop(context, {"status": "failure"});
                  }

                  return NavigationDecision.prevent;
                }

                if (request.url.contains("flutterwave/fail")) {
                  Navigator.pop(context, {"status": "failure"});
                  return NavigationDecision.prevent;
                }

                return NavigationDecision.navigate;
              },
            ),
          )
          ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Payment")),
      body: WebViewWidget(controller: _controller),
    );
  }
}
