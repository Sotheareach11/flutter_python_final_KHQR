import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class KhqrImageScreen extends StatefulWidget {
  const KhqrImageScreen({super.key});

  @override
  State<KhqrImageScreen> createState() => _KhqrImageScreenState();
}

class _KhqrImageScreenState extends State<KhqrImageScreen> {
  late Future<Uint8List> _imageFuture;

  @override
  void initState() {
    super.initState();
    _imageFuture = _fetchBase64Image();
  }

  Future<Uint8List> _fetchBase64Image() async {
    const url = 'http://10.0.2.2:8000/api/khqr-image/';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['image_base64'] != null) {
        return base64Decode(data['image_base64']);
      } else {
        throw Exception('No image data in response');
      }
    } else {
      throw Exception('Failed to load image: ${response.statusCode}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('KHQR Image')),
      body: Center(
        child: FutureBuilder<Uint8List>(
          future: _imageFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            } else if (snapshot.hasError) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.broken_image, size: 100, color: Colors.red),
                  const SizedBox(height: 10),
                  Text('Error: ${snapshot.error}'),
                ],
              );
            } else if (snapshot.hasData) {
              return Image.memory(
                snapshot.data!,
                width: 250,
                height: 250,
                fit: BoxFit.contain,
              );
            } else {
              return const Icon(Icons.image_not_supported, size: 100);
            }
          },
        ),
      ),
    );
  }
}
