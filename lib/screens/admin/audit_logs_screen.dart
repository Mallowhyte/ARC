import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/api_service.dart';

class AuditLogsScreen extends StatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen> {
  final _supabase = Supabase.instance.client;
  final _api = ApiService();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = [];
  final Map<String, Map<String, dynamic>> _profiles = {};

  String? _actionFilter; // upload, view, update, delete, list, stats_view
  String? _actorSearch; // actor_user_id partial

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var q = _supabase
          .from('audit_logs')
          .select(
            'id, actor_user_id, action, resource_type, resource_id, metadata, created_at',
          );

      if (_actionFilter != null && _actionFilter!.isNotEmpty) {
        q = q.eq('action', _actionFilter!);
      }
      if (_actorSearch != null && _actorSearch!.isNotEmpty) {
        q = q.ilike('actor_user_id', '%${_actorSearch!.trim()}%');
      }

      final data = await q.order('created_at', ascending: false).limit(200);
      _rows = (data as List).cast<Map<String, dynamic>>();

      // Load actor profiles for display names/emails
      await _loadActorProfiles();
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadActorProfiles() async {
    try {
      final ids = _rows
          .map((r) => (r['actor_user_id'] ?? '') as String)
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();
      if (ids.isEmpty) return;
      final mapping = await _api.getUserDisplays(ids);
      mapping.forEach((key, value) {
        if (value is Map) {
          _profiles[key] = Map<String, dynamic>.from(value as Map);
        }
      });
    } catch (_) {
      // ignore, fall back to UID display
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          const Divider(height: 1),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 160,
            child: DropdownButtonFormField<String>(
              value: _actionFilter,
              decoration: const InputDecoration(labelText: 'Action'),
              items: const [
                DropdownMenuItem(value: '', child: Text('All')),
                DropdownMenuItem(value: 'upload', child: Text('Upload')),
                DropdownMenuItem(value: 'view', child: Text('View')),
                DropdownMenuItem(value: 'update', child: Text('Update')),
                DropdownMenuItem(value: 'delete', child: Text('Delete')),
                DropdownMenuItem(value: 'list', child: Text('List')),
                DropdownMenuItem(
                  value: 'stats_view',
                  child: Text('Stats View'),
                ),
              ],
              onChanged: (v) {
                setState(() {
                  _actionFilter = (v != null && v.isNotEmpty) ? v : null;
                });
                _load();
              },
            ),
          ),
          SizedBox(
            width: 220,
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Actor contains',
                hintText: 'user id / email fragment',
              ),
              onChanged: (v) {
                _actorSearch = v;
              },
              onSubmitted: (_) => _load(),
            ),
          ),
          ElevatedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.search),
            label: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(_error!),
        ),
      );
    }
    if (_rows.isEmpty) {
      return const Center(child: Text('No logs'));
    }

    return ListView.separated(
      itemCount: _rows.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final r = _rows[index];
        final action = (r['action'] ?? '') as String;
        final resourceType = (r['resource_type'] ?? '') as String;
        final actor = (r['actor_user_id'] ?? '') as String;
        final prof = _profiles[actor];
        final fullName = (prof?['full_name'] as String?)?.trim();
        final email = (prof?['email'] as String?)?.trim();
        final actorDisplay = (fullName != null && fullName.isNotEmpty)
            ? (email != null && email.isNotEmpty
                  ? '$fullName • $email'
                  : fullName)
            : (email != null && email.isNotEmpty ? email : actor);
        final createdAt = r['created_at']?.toString() ?? '';
        final resourceId = (r['resource_id'] ?? '') as String;

        return ListTile(
          dense: true,
          leading: _actionIcon(action),
          title: Text('$action • $resourceType'),
          subtitle: Text('Actor: $actorDisplay\nTime: $createdAt'),
          trailing: resourceId.isNotEmpty
              ? Text(resourceId, style: const TextStyle(fontSize: 12))
              : null,
        );
      },
    );
  }

  Icon _actionIcon(String a) {
    switch (a) {
      case 'upload':
        return const Icon(Icons.upload_file);
      case 'view':
        return const Icon(Icons.visibility_outlined);
      case 'update':
        return const Icon(Icons.edit_outlined);
      case 'delete':
        return const Icon(Icons.delete_outline);
      case 'list':
        return const Icon(Icons.list_alt);
      case 'stats_view':
        return const Icon(Icons.insights_outlined);
      default:
        return const Icon(Icons.event_note_outlined);
    }
  }
}
