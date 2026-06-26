import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: WebViewApp(),
    );
  }
}

class WebViewApp extends StatefulWidget {
  const WebViewApp({super.key});

  @override
  State<WebViewApp> createState() => _WebViewAppState();
}

class _WebViewAppState extends State<WebViewApp> {
  InAppWebViewController? controller;
  PullToRefreshController? pullToRefreshController;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    requestPermissions();

    pullToRefreshController = PullToRefreshController(
      onRefresh: () async {
        await controller?.reload();
      },
    );
  }

  Future<void> requestPermissions() async {
    await [
      Permission.camera,
      Permission.microphone,
      Permission.storage,
      Permission.photos,
    ].request();
  }

  Future<void> _handleBackButton() async {
    if (controller != null && await controller!.canGoBack()) {
      controller!.goBack();
    } else {
      if (mounted) Navigator.of(context).pop();
    }
  }

  // 📸 FUNÇÃO QUE ABRE A CÂMERA E DEVOLVE BASE64
  Future<String?> tirarFotoBase64() async {
    final ImagePicker picker = ImagePicker();

    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );

    if (image == null) return null;

    final bytes = await File(image.path).readAsBytes();
    final base64Image = base64Encode(bytes);

    return base64Image;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBackButton();
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              InAppWebView(
                initialUrlRequest:
                URLRequest(url: WebUri("https://app.sofjuridico.com.br")),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  mediaPlaybackRequiresUserGesture: false,
                  allowsInlineMediaPlayback: true,
                  supportZoom: false,
                  allowFileAccess: true,
                  allowContentAccess: true,
                  userAgent: "SOFJuridicoApp/1.0 (${Platform.isIOS ? 'iOS' : 'Android'})",
                ),
                pullToRefreshController: pullToRefreshController,

                onWebViewCreated: (webViewController) {
                  controller = webViewController;

                  // 🔗 PONTE FLUTTER ↔ WEB
                  controller!.addJavaScriptHandler(
                    handlerName: 'abrirCamera',
                    callback: (args) async {
                      final base64 = await tirarFotoBase64();
                      return base64; // ← retorna para o site
                    },
                  );
                },

                onLoadStart: (controller, url) {
                  setState(() => isLoading = true);
                },

                onLoadStop: (controller, url) async {
                  pullToRefreshController?.endRefreshing();
                  setState(() => isLoading = false);
                },

                onPermissionRequest: (controller, request) async {
                  return PermissionResponse(
                    resources: request.resources,
                    action: PermissionResponseAction.GRANT,
                  );
                },
              ),

              if (isLoading)
                const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      ),
    );
  }
}