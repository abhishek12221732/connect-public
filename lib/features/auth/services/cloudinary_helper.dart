import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class CloudinaryHelper {
  final String _cloudName = 'dqshu6jwp';
  final String _uploadPreset = 'unsigned_uploads'; // The name is the same, but its mode is now 'Signed'

  /// Uploads image bytes using a secure signature from a Cloud Function.
  Future<String?> uploadImageBytes(Uint8List imageBytes, {required String publicId, required String folder}) async {
  try {
    // 1. Get the signature from your Firebase Cloud Function
    print("Requesting signature from Firebase...");
    final callable = FirebaseFunctions.instance.httpsCallable('generateCloudinarySignature');
    
    // ✨ PASS THE FOLDER IN THE CALL
    final response = await callable.call({
      'publicId': publicId,
      'folder': folder, 
    });

    final signature = response.data['signature'];
    final timestamp = response.data['timestamp'];
    final apiKey = response.data['api_key'];
    print("Signature received successfully.");

    // (The rest of the function stays exactly the same)
    // 2. Prepare the multipart request for Cloudinary's API
    final url = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload');
    final request = http.MultipartRequest('POST', url);
    
    request.fields['api_key'] = apiKey;
    request.fields['timestamp'] = timestamp.toString();
    request.fields['signature'] = signature;
    request.fields['public_id'] = publicId;
    request.fields['folder'] = folder;
    request.fields['upload_preset'] = _uploadPreset; 

    request.files.add(http.MultipartFile.fromBytes(
      'file',
      imageBytes,
      filename: '$publicId.jpg',
    ));

    // 3. Send the request and parse the response
    print("Uploading to Cloudinary with signature...");
    final streamResponse = await request.send();
    final http.Response res = await http.Response.fromStream(streamResponse);
    print("Cloudinary response status: ${res.statusCode}");
    
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      final secureUrl = data['secure_url'];
      if (secureUrl != null) {
        print("Cloudinary upload successful. URL: $secureUrl");
        return secureUrl;
      }
    }
    
    print("Cloudinary response body: ${res.body}");
    throw Exception('Cloudinary upload failed with status: ${res.statusCode}');

  } catch (e) {
    debugPrint("Cloudinary signed upload error: $e");
    rethrow; 
  }
}
}