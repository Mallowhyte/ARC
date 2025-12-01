/// Documents Screen
/// Displays list of all uploaded and classified documents

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/document_model.dart';
import 'package:intl/intl.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();

  String get _userId => _authService.currentUserId ?? 'anonymous';

  List<DocumentModel> _documents = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _filterType = 'All';
  String _searchQuery = '';
  Set<String> _roles = {};

  @override
  void initState() {
    super.initState();
    _authService.fetchRoles().then((_) {
      if (!mounted) return;
      setState(() => _roles = _authService.roles.toSet());
    });
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final documents = await _apiService.getUserDocuments(_userId);
      if (!mounted) return;
      setState(() {
        _documents = documents;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  List<DocumentModel> get _filteredDocuments {
    Iterable<DocumentModel> docs = _documents;

    if (_filterType != 'All') {
      docs = docs.where((doc) => doc.documentType == _filterType);
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      docs = docs.where(
        (doc) =>
            doc.filename.toLowerCase().contains(query) ||
            doc.documentType.toLowerCase().contains(query),
      );
    }

    return docs.toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadDocuments,
        child: Column(
          children: [
            // Search & filter row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (value) =>
                          setState(() => _searchQuery = value),
                      decoration: const InputDecoration(
                        hintText: 'Search documents',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_roles.isNotEmpty) ...[
                    Chip(
                      label: Text(
                        _roles.first.toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  IconButton(
                    icon: const Icon(Icons.filter_list),
                    onPressed: _documents.isEmpty
                        ? null
                        : () => _showFilterSheet(),
                  ),
                ],
              ),
            ),

            // Filter Chips (quick view)
            if (_documents.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All',
                      isSelected: _filterType == 'All',
                      count: _documents.length,
                      onTap: () => setState(() => _filterType = 'All'),
                    ),
                    const SizedBox(width: 8),
                    ...DocumentType.all.map((type) {
                      final count = _documents
                          .where((doc) => doc.documentType == type)
                          .length;
                      if (count == 0) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: _FilterChip(
                          label: type,
                          isSelected: _filterType == type,
                          count: count,
                          onTap: () => setState(() => _filterType = type),
                        ),
                      );
                    }),
                  ],
                ),
              ),

            // Content
            Expanded(child: _buildContent()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadDocuments,
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Future<void> _showFilterSheet() async {
    if (_documents.isEmpty) return;

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Filter by type',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ListTile(
                  title: const Text('All'),
                  trailing: _filterType == 'All'
                      ? const Icon(Icons.check, color: Colors.blue)
                      : null,
                  onTap: () {
                    setState(() => _filterType = 'All');
                    Navigator.pop(context);
                  },
                ),
                const Divider(),
                ...DocumentType.all.map((type) {
                  final count = _documents
                      .where((doc) => doc.documentType == type)
                      .length;
                  if (count == 0) return const SizedBox.shrink();
                  return ListTile(
                    title: Text(type),
                    subtitle: Text('$count documents'),
                    trailing: _filterType == type
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                    onTap: () {
                      setState(() => _filterType = type);
                      Navigator.pop(context);
                    },
                  );
                }).toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error loading documents',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(_errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadDocuments,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_documents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No documents yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text('Upload your first document to get started'),
          ],
        ),
      );
    }

    final filteredDocs = _filteredDocuments;

    if (filteredDocs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No $_filterType documents',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: filteredDocs.length,
      itemBuilder: (context, index) {
        return _DocumentCard(document: filteredDocs[index]);
      },
    );
  }
}

/// Document Card Widget
class _DocumentCard extends StatelessWidget {
  final DocumentModel document;

  const _DocumentCard({required this.document});

  // Get status color based on document status
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      case 'draft':
        return Colors.blueGrey;
      default:
        return Colors.grey;
    }
  }

  // Format date for display
  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  // Format time for display
  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: () => _showDocumentDetails(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // First row: Icon, Title, and Status
              Row(
                children: [
                  _getDocumentIcon(document.documentType),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          document.filename,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(
                                  document.status,
                                ).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _getStatusColor(
                                    document.status,
                                  ).withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                document.status.toUpperCase(),
                                style: TextStyle(
                                  color: _getStatusColor(document.status),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (document.documentNumber != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.blue.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  'v${document.versionNumber ?? 1}',
                                  style: const TextStyle(
                                    color: Colors.blue,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  _ConfidenceBadge(confidence: document.confidence),
                ],
              ),
              const SizedBox(height: 12),
              // Document details
              if (document.documentNumber != null ||
                  document.department != null)
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    if (document.documentNumber != null)
                      _DetailRow(
                        icon: Icons.numbers,
                        label: 'Document #',
                        value: document.documentNumber!,
                      ),
                    if (document.department != null)
                      _DetailRow(
                        icon: Icons.business,
                        label: 'Department',
                        value: document.department!,
                      ),
                    if (document.effectiveDate != null)
                      _DetailRow(
                        icon: Icons.calendar_today,
                        label: 'Effective',
                        value: _formatDate(document.effectiveDate),
                      ),
                  ],
                ),
              const SizedBox(height: 8),
              // Document type badge and upload date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.indigo.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      document.documentType,
                      style: TextStyle(
                        color: Colors.indigo.shade700,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    'Uploaded ${document.formattedDate}',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDocumentDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Document Details',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const Divider(height: 32),
                _DetailRow(label: 'Filename', value: document.filename),
                _DetailRow(
                  label: 'Document Type',
                  value: document.documentType,
                ),
                _DetailRow(
                  label: 'Confidence',
                  value: document.confidencePercentage,
                ),
                _DetailRow(
                  label: 'Upload Date',
                  value: DateFormat(
                    'MMMM dd, yyyy HH:mm',
                  ).format(document.createdAt),
                ),
                _DetailRow(label: 'Status', value: document.status),
                if (document.keywords != null &&
                    document.keywords!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Keywords:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: document.keywords!
                        .map(
                          (keyword) => Chip(
                            label: Text(keyword),
                            backgroundColor: Colors.blue[50],
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _getDocumentIcon(String type) {
    IconData icon;
    Color color;

    switch (type) {
      case 'Exam Form':
        icon = Icons.description;
        color = Colors.blue;
        break;
      case 'Receipt':
        icon = Icons.receipt;
        color = Colors.green;
        break;
      case 'Clearance':
        icon = Icons.verified;
        color = Colors.purple;
        break;
      case 'Grade Sheet':
        icon = Icons.grade;
        color = Colors.orange;
        break;
      default:
        icon = Icons.insert_drive_file;
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
}

/// Confidence Badge Widget
class _ConfidenceBadge extends StatelessWidget {
  final double confidence;

  const _ConfidenceBadge({required this.confidence});

  @override
  Widget build(BuildContext context) {
    final percentage = (confidence * 100).round();
    final color = percentage >= 80
        ? Colors.green
        : percentage >= 60
        ? Colors.orange
        : Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$percentage%',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// Filter Chip Widget
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final int count;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text('$label ($count)'),
      selected: isSelected,
      onSelected: (_) => onTap(),
      backgroundColor: Colors.grey[200],
      selectedColor: Colors.blue[100],
    );
  }
}

/// Detail Row Widget
class _DetailRow extends StatelessWidget {
  final IconData? icon;
  final String label;
  final String value;

  const _DetailRow({this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 8),
          ],
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
