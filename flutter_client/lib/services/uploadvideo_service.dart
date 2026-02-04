import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class UploadvideoService {
  final FlutterSecureStorage storage = FlutterSecureStorage();
  final backendUrl = "http://192.168.18.94:8000/upload/video";

  Future<Map<String, String>> _getCookieHeader() async {
    final accessToken = await storage.read(key: "access_token");
    final headers = {'Content-Type': 'application/json'};
    if (accessToken != null) {
      headers['Cookie'] = 'access_token=$accessToken';
    }
    
    return headers;
  }

  Future<Map<String, dynamic>> getPresignedUrlForThumbnail(String thumbnailId) async {
    final res = await http.get(
      Uri.parse("$backendUrl/url/thumbnail?thumbnail_id=$thumbnailId"),
      headers: await _getCookieHeader(),
    );
    if (res.statusCode == 200) {
      debugPrint("Presigned URL for thumbnail: ${jsonDecode(res.body)}");
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw jsonDecode(res.body)['details'] ?? 'Unexpected error occured';
  }

  Future<Map<String, dynamic>> getPresignedUrlForVideo() async {
    final res = await http.get(
      Uri.parse("$backendUrl/url"),
      headers: await _getCookieHeader(),
    );
    if (res.statusCode == 200) {
      debugPrint("Presigned URL for video: ${jsonDecode(res.body)}");
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw jsonDecode(res.body)['details'] ?? 'Unexpected error occured';
  }

  Future<bool> uploadFileToS3({
  required String presignedUrl,
  required File file,
  required bool isVideo,
}) async {
  try {
    // First check if file exists and can be read
    if (!await file.exists()) {
      debugPrint("File does not exist: ${file.path}");
      return false;
    }
    
    final bytes = await file.readAsBytes();
    debugPrint("File size: ${bytes.length} bytes");
    
    final res = await http.put(
      Uri.parse(presignedUrl),
      headers: {
        'Content-Type': isVideo ? 'video/mp4' : 'image/jpeg',
        if(!isVideo) 'x-amz-acl': 'public-read',
      },
      body: bytes,
    );
    
    debugPrint("S3 upload status: ${res.statusCode}");
    
    if (res.statusCode != 200) {
      debugPrint("S3 error response: ${res.body}");
    }
    
    return res.statusCode == 200;
    
  } catch (e) {
    debugPrint("Error in uploadFileToS3: $e");
    return false;
  }
}

  Future<bool> uploadMetadata({
    required String title,
    required String description,
    required String visibility,
    required String s3_key,
  }) async {
    final res = await http.post(
      Uri.parse("$backendUrl/metadata"),
      headers: await _getCookieHeader(),
      body: jsonEncode({
        'title': title,
        'description': description,
        'visibility': visibility,
        'video_id': s3_key,
        'video_s3_key': s3_key,
      }),
    );

    return res.statusCode == 200;
  }




}
