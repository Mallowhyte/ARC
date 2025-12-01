/// API Service
/// Handles communication with the backend and Supabase

import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/document_model.dart';
import 'supabase_service.dart';

class ApiService {
  final String baseUrl = SupabaseConfig.backendUrl;
  final SupabaseClient _supabase = SupabaseService().client;

  /// Upload and classify a document
  Future<Map<String, dynamic>> classifyDocument(
    File file,
    String userId,
  ) async {
    try {
      final url = '$baseUrl${SupabaseConfig.classifyEndpoint}';
      print('📤 Uploading to: $url');
      print('📁 File: ${file.path}');
      print('👤 User ID: $userId');

      var request = http.MultipartRequest('POST', Uri.parse(url));

      // Add file
      final multipartFile = await http.MultipartFile.fromPath(
        'file',
        file.path,
      );
      print('📊 File size: ${multipartFile.length} bytes');
      request.files.add(multipartFile);

      // Add user_id
      request.fields['user_id'] = userId;

      print('🚀 Sending request...');

      // Send request with timeout (180 seconds for OCR processing)
      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 180),
        onTimeout: () {
          print('⏱️ Request timed out after 180 seconds');
          throw Exception('Upload timed out. Please wait longer or try again.');
        },
      );

      print('📥 Response received: ${streamedResponse.statusCode}');
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        print('✅ Upload successful');
        return json.decode(response.body);
      } else {
        print('❌ Upload failed: ${response.statusCode}');
        print('Response: ${response.body}');
        throw Exception('Failed to classify document: ${response.body}');
      }
    } catch (e) {
      print('❌ Error during upload: $e');
      throw Exception('Error uploading document: $e');
    }
  }

  /// Get all documents for a user via backend (RBAC-aware)
  Future<List<DocumentModel>> getUserDocuments(String userId) async {
    try {
      final url = '$baseUrl${SupabaseConfig.documentsEndpoint}?user_id=$userId';
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode != 200) {
        throw Exception('Failed to fetch documents: ${resp.body}');
      }
      final data = json.decode(resp.body) as Map<String, dynamic>;
      final docs = (data['documents'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      return docs.map((row) => DocumentModel.fromJson(row)).toList();
    } catch (e) {
      print('Error fetching documents from backend: $e');
      throw Exception('Error fetching documents: $e');
    }
  }

  /// Get a specific document by ID
  Future<DocumentModel> getDocumentById(String documentId) async {
    try {
      final callerId = _supabase.auth.currentUser?.id;
      final q = callerId != null ? '?user_id=$callerId' : '';
      final response = await http.get(
        Uri.parse('$baseUrl${SupabaseConfig.documentsEndpoint}/$documentId$q'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return DocumentModel.fromJson(data['document']);
      } else if (response.statusCode == 404) {
        throw Exception('Document not found');
      } else {
        throw Exception('Failed to load document');
      }
    } catch (e) {
      throw Exception('Error fetching document: $e');
    }
  }

  /// Get classification statistics
  Future<Map<String, dynamic>> getStatistics(String? userId) async {
    try {
      String url = '$baseUrl${SupabaseConfig.statsEndpoint}';
      if (userId != null) {
        url += '?user_id=$userId';
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['statistics'];
      } else {
        throw Exception('Failed to load statistics');
      }
    } catch (e) {
      throw Exception('Error fetching statistics: $e');
    }
  }

  /// Check backend health
  Future<bool> checkHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
