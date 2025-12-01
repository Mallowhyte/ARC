/// Upload Screen
/// Screen for uploading and classifying documents

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/document_model.dart';
import 'auth/email_verification_screen.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  final ImagePicker _imagePicker = ImagePicker();

  bool _isUploading = false;
  String _status = '';
  File? _selectedFile;
  DocumentModel? _classifiedDocument;

  String get _userId => _authService.currentUserId ?? 'anonymous';

  @override
  void initState() {
    super.initState();
    // Fetch roles for UI gating
    _authService.fetchRoles().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Document'),
        actions: [
          if (_authService.roles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: Chip(
                label: Text(
                  _authService.roles.first.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_authService.canUpload) ...[
              Card(
                color: Colors.amber[50],
                child: const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Text(
                    'Your role has read-only access. Uploading is disabled.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_isUploading) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  minHeight: 4,
                  backgroundColor: Colors.blue.shade50,
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Hero Upload Card
            Card(
              child: InkWell(
                onTap: _isUploading || !_authService.canUpload
                    ? null
                    : _pickFile,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cloud_upload_outlined,
                        size: 56,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Tap to upload a file',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Supported formats: PDF, JPG, PNG and more',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Additional sources
            Text(
              'Or capture from device',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),

            // Camera Button
            _UploadOptionButton(
              icon: Icons.camera_alt,
              label: 'Take Photo',
              onPressed: _isUploading || !_authService.canUpload
                  ? null
                  : _pickFromCamera,
            ),
            const SizedBox(height: 12),

            // Gallery Button
            _UploadOptionButton(
              icon: Icons.photo_library,
              label: 'Choose from Gallery',
              onPressed: _isUploading || !_authService.canUpload
                  ? null
                  : _pickFromGallery,
            ),
            const SizedBox(height: 12),

            // File Picker Button
            _UploadOptionButton(
              icon: Icons.folder_open,
              label: 'Browse Files',
              onPressed: _isUploading || !_authService.canUpload
                  ? null
                  : _pickFile,
            ),
            const SizedBox(height: 24),

            // Selected File Preview
            if (_selectedFile != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Selected File',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.description, color: Colors.blue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedFile!.path.split('/').last,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setState(() {
                                _selectedFile = null;
                                _status = '';
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Upload Button
              ElevatedButton.icon(
                onPressed: _isUploading || !_authService.canUpload
                    ? null
                    : _uploadAndClassify,
                icon: _isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload),
                label: Text(
                  _isUploading ? 'Processing...' : 'Upload & Classify',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],

            // Status Message
            if (_status.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                color: _classifiedDocument != null
                    ? Colors.green[50]
                    : Colors.orange[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    _status,
                    style: TextStyle(
                      color: _classifiedDocument != null
                          ? Colors.green[900]
                          : Colors.orange[900],
                    ),
                  ),
                ),
              ),
            ],

            // Classification Result
            if (_classifiedDocument != null) ...[
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Classification Result',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(),
                      const SizedBox(height: 8),
                      _ResultRow(
                        label: 'Document Type',
                        value: _classifiedDocument!.documentType,
                        icon: Icons.category,
                      ),
                      const SizedBox(height: 8),
                      _ResultRow(
                        label: 'Confidence',
                        value: _classifiedDocument!.confidencePercentage,
                        icon: Icons.analytics,
                      ),
                      if (_classifiedDocument!.keywords != null &&
                          _classifiedDocument!.keywords!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Keywords:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          children: _classifiedDocument!.keywords!
                              .map(
                                (keyword) => Chip(
                                  label: Text(keyword),
                                  backgroundColor: Colors.blue[50],
                                ),
                              )
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _selectedFile = null;
                            _classifiedDocument = null;
                            _status = '';
                          });
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Upload Another'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickFromCamera() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
      );
      if (photo != null) {
        if (!mounted) return;
        setState(() {
          _selectedFile = File(photo.path);
          _status = '';
          _classifiedDocument = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to capture photo: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );
      if (image != null) {
        if (!mounted) return;
        setState(() {
          _selectedFile = File(image.path);
          _status = '';
          _classifiedDocument = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to pick image: $e');
    }
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'tiff', 'bmp'],
      );

      if (result != null && result.files.single.path != null) {
        if (!mounted) return;
        setState(() {
          _selectedFile = File(result.files.single.path!);
          _status = '';
          _classifiedDocument = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to pick file: $e');
    }
  }

  Future<void> _uploadAndClassify() async {
    if (!_authService.isEmailVerified) {
      await _showVerificationRequiredDialog();
      return;
    }
    if (_selectedFile == null) return;

    setState(() {
      _isUploading = true;
      _status = 'Uploading and classifying document...';
    });

    try {
      final result = await _apiService.classifyDocument(
        _selectedFile!,
        _userId,
      );

      // Check if widget is still mounted before updating state
      if (!mounted) return;

      setState(() {
        _isUploading = false;
        _classifiedDocument = DocumentModel.fromJson(result);
        _status = 'Document successfully classified!';
      });
    } catch (e) {
      // Check if widget is still mounted before updating state
      if (!mounted) return;

      setState(() {
        _isUploading = false;
        _status = 'Error: $e';
      });
      _showError(e.toString());
    }
  }

  Future<void> _showVerificationRequiredDialog() async {
    final email = _authService.currentUserEmail;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Email verification required'),
          content: const Text(
            'Please verify your email address before uploading documents.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Maybe later'),
            ),
            if (email != null)
              TextButton(
                onPressed: () async {
                  try {
                    await _authService.resendVerificationEmail(email);
                    if (!mounted) return;
                    Navigator.pop(dialogContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            EmailVerificationScreen(email: email),
                      ),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    Navigator.pop(dialogContext);
                    _showError('Failed to send verification email: $e');
                  }
                },
                child: const Text('Verify now'),
              ),
          ],
        );
      },
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}

/// Upload Option Button Widget
class _UploadOptionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _UploadOptionButton({
    required this.icon,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        alignment: Alignment.centerLeft,
      ),
    );
  }
}

/// Result Row Widget
class _ResultRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _ResultRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(value),
      ],
    );
  }
}
