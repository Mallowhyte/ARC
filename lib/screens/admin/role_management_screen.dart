import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';

class RoleManagementScreen extends StatefulWidget {
  const RoleManagementScreen({super.key});

  @override
  State<RoleManagementScreen> createState() => _RoleManagementScreenState();
}

class _RoleManagementScreenState extends State<RoleManagementScreen> {
  final _supabase = Supabase.instance.client;
  final _auth = AuthService();
  final _api = ApiService();

  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _roles = [];
  List<Map<String, dynamic>> _departments = [];
  Map<String, Map<String, dynamic>> _userProfiles = {};

  // Form state
  final _userIdCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  String _selectedRole = 'faculty';
  String? _selectedDepartmentId;

  String? _deptLabel(String? id) {
    if (id == null) return null;
    for (final d in _departments) {
      if (d['id'] == id) {
        final code = (d['code'] as String?) ?? '';
        final name = (d['name'] as String?) ?? '';
        return name.isNotEmpty ? '$code - $name' : code;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _auth.fetchRoles();
      if (!_auth.isAdmin) {
        setState(() {
          _loading = false;
        });
        return;
      }
      await Future.wait([_loadRoles(), _loadDepartments()]);
      await _loadUserProfilesForRoles();
      setState(() {
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadRoles() async {
    final data = await _supabase
        .from('user_roles')
        .select('id,user_id,role,department_id,created_at')
        .order('created_at');
    _roles = (data as List).cast<Map<String, dynamic>>();
    // Filter out rows with empty/missing user_id to avoid blank bullets
    _roles = _roles
        .where((r) => ((r['user_id'] ?? '').toString()).trim().isNotEmpty)
        .toList();
  }

  Future<void> _loadDepartments() async {
    final data = await _supabase
        .from('departments')
        .select('id, code, name')
        .order('code');
    _departments = (data as List).cast<Map<String, dynamic>>();
    // Limit to actual school departments
    const allowed = {'BTLED', 'BSIT', 'BFPT'};
    _departments = _departments
        .where(
          (d) => allowed.contains(((d['code'] ?? '') as String).toUpperCase()),
        )
        .toList();
  }

  Future<void> _loadUserProfilesForRoles() async {
    try {
      final ids = _roles
          .map((r) => (r['user_id'] ?? '').toString())
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();
      if (ids.isEmpty) return;
      final mapping = await _api.getUserDisplays(ids);
      mapping.forEach((key, value) {
        if (value is Map) {
          _userProfiles[key] = Map<String, dynamic>.from(value);
        }
      });
    } catch (_) {
      // Fallback to showing user_id only
    }
  }

  Future<void> _refresh() async {
    await _loadRoles();
    await _loadUserProfilesForRoles();
    if (mounted) setState(() {});
  }

  Future<void> _addRole() async {
    try {
      String? userId = _userIdCtrl.text.trim().isNotEmpty
          ? _userIdCtrl.text.trim()
          : null;
      final email = _emailCtrl.text.trim();

      if (userId == null && email.isEmpty) {
        _showSnack('Enter a user ID or email');
        return;
      }

      // Resolve email to user id via backend (service role)
      if (userId == null && email.isNotEmpty) {
        final resolved = await _api.resolveUserByEmail(email);
        if (resolved != null && (resolved['id'] as String?) != null) {
          userId = resolved['id'] as String;
        }
      }

      if (userId == null) {
        _showSnack('Could not resolve user by email. Provide user ID.');
        return;
      }

      final payload = {
        'user_id': userId,
        'role': _selectedRole,
        if (_selectedRole == 'faculty' && _selectedDepartmentId != null)
          'department_id': _selectedDepartmentId,
      };
      await _supabase.from('user_roles').insert(payload);

      _userIdCtrl.clear();
      _emailCtrl.clear();
      _selectedRole = 'faculty';
      _selectedDepartmentId = null;

      await _refresh();
      _showSnack('Role added');
    } catch (e) {
      _showSnack('Failed to add role: $e');
    }
  }

  Future<void> _deleteRole(String id) async {
    try {
      await _supabase.from('user_roles').delete().eq('id', id);
      await _refresh();
      _showSnack('Role removed');
    } catch (e) {
      _showSnack('Failed to remove role: $e');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_auth.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Role Management')),
        body: const Center(child: Text('Admins only')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Role Management')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            if (_error != null) ...[
              Card(
                color: Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Colors.red[900]),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Add Role',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                            minWidth: 220,
                            maxWidth: 420,
                          ),
                          child: TextField(
                            controller: _emailCtrl,
                            decoration: const InputDecoration(
                              labelText:
                                  'Email (optional, resolves to user ID)',
                            ),
                          ),
                        ),
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                            minWidth: 220,
                            maxWidth: 420,
                          ),
                          child: TextField(
                            controller: _userIdCtrl,
                            decoration: const InputDecoration(
                              labelText: 'User ID (if not using email)',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints.tightFor(
                            width: 160,
                          ),
                          child: DropdownButtonFormField<String>(
                            value: _selectedRole,
                            decoration: const InputDecoration(
                              labelText: 'Role',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'admin',
                                child: Text('Admin'),
                              ),
                              DropdownMenuItem(
                                value: 'auditor',
                                child: Text('Auditor'),
                              ),
                              DropdownMenuItem(
                                value: 'faculty',
                                child: Text('Faculty'),
                              ),
                            ],
                            onChanged: (val) {
                              setState(() {
                                _selectedRole = val ?? 'faculty';
                              });
                            },
                          ),
                        ),
                        if (_selectedRole == 'faculty')
                          ConstrainedBox(
                            constraints: const BoxConstraints(
                              minWidth: 220,
                              maxWidth: 520,
                            ),
                            child: DropdownButtonFormField<String>(
                              value: _selectedDepartmentId,
                              items: _departments
                                  .map(
                                    (d) => DropdownMenuItem(
                                      value: d['id'] as String,
                                      child: Text(
                                        '${d['code']} - ${d['name']}',
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _selectedDepartmentId = v),
                              decoration: const InputDecoration(
                                labelText: 'Department (optional)',
                              ),
                            ),
                          ),
                        ElevatedButton.icon(
                          onPressed: _addRole,
                          icon: const Icon(Icons.add),
                          label: const Text('Add'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current Roles',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ..._roles.map((r) {
                      final userId = r['user_id'] as String? ?? '';
                      final profile = _userProfiles[userId];
                      final label = profile != null
                          ? '${profile['full_name'] ?? profile['email'] ?? userId} • ${r['role']}'
                          : '$userId • ${r['role']}';
                      final dept = r['department_id'] as String?;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: dept != null
                            ? Text(
                                'Department: ${_deptLabel(dept) ?? dept}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            : null,
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          onPressed: () => _deleteRole(r['id'] as String),
                          tooltip: 'Remove role',
                        ),
                        isThreeLine: false,
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
