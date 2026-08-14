import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminUsersPage extends StatefulWidget {
  final String initialFilter;

  const AdminUsersPage({
    super.key,
    this.initialFilter = 'All',
  });

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final supabase = Supabase.instance.client;
  final TextEditingController searchController = TextEditingController();

  bool isLoading = true;
  String selectedFilter = 'All';

  List<Map<String, dynamic>> users = [];
  List<Map<String, dynamic>> filteredUsers = [];

  @override
  void initState() {
    super.initState();
    selectedFilter = widget.initialFilter;
    fetchUsers();
  }

  Future<void> fetchUsers() async {
    if (!mounted) return;

    setState(() => isLoading = true);

    try {
      final data = await supabase
          .from('profiles')
          .select('id, full_name, phone, email, role, avatar_url, created_at, blocked')
          .order('created_at', ascending: false);

      users = List<Map<String, dynamic>>.from(data);
      applyFilter();
    } catch (e) {
      _msg('Failed to load users: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void applyFilter() {
    final search = searchController.text.toLowerCase();

    filteredUsers = users.where((user) {
      final name = (user['full_name'] ?? '').toString().toLowerCase();
      final email = (user['email'] ?? '').toString().toLowerCase();
      final role = (user['role'] ?? 'user').toString().toLowerCase();

      final matchesSearch = name.contains(search) || email.contains(search);

      if (selectedFilter == 'Admin') {
        return matchesSearch && role == 'admin';
      }

      if (selectedFilter == 'User') {
        return matchesSearch && role == 'user';
      }

      return matchesSearch;
    }).toList();

    if (mounted) {
      setState(() {});
    }
  }

  int get totalUsers => users.length;

  int get adminUsers => users
      .where((u) => (u['role'] ?? 'user').toString().toLowerCase() == 'admin')
      .length;

  int get normalUsers => users
      .where((u) => (u['role'] ?? 'user').toString().toLowerCase() == 'user')
      .length;

  void _msg(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  String formatDate(dynamic date) {
    if (date == null) return 'N/A';

    try {
      final d = DateTime.parse(date.toString());
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return 'N/A';
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _toggleBlockUser(
    Map<String, dynamic> user) async {
  final blocked = user['blocked'] ?? false;

  final confirm = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(
          blocked ? 'Unblock User?' : 'Block User?'),
      content: Text(
          blocked
              ? 'Allow this user to use the app again?'
              : 'This user will no longer be able to use the app.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Confirm'),
        ),
      ],
    ),
  );

  if (confirm != true) return;

  await supabase
      .from('profiles')
      .update({
        'blocked': !blocked,
      })
      .eq('id', user['id']);

  fetchUsers();

  _msg(
      blocked ? 'User unblocked' : 'User blocked');
}

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFD62828);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF7F8),
      appBar: AppBar(
        title: const Text(
          'Admin Users',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: red,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: fetchUsers,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: red),
            )
          : RefreshIndicator(
              onRefresh: fetchUsers,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _summaryCard(
                          title: 'Total Users',
                          value: totalUsers.toString(),
                          icon: Icons.people,
                          color: red,
                        ),
                        const SizedBox(width: 12),
                        _summaryCard(
                          title: 'Admins',
                          value: adminUsers.toString(),
                          icon: Icons.admin_panel_settings,
                          color: Colors.purple,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _summaryCard(
                          title: 'Users',
                          value: normalUsers.toString(),
                          icon: Icons.person,
                          color: Colors.blue,
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    TextField(
                      controller: searchController,
                      onChanged: (_) => applyFilter(),
                      decoration: InputDecoration(
                        hintText: 'Search by name or email',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _filterChip('All'),
                        const SizedBox(width: 8),
                        _filterChip('User'),
                        const SizedBox(width: 8),
                        _filterChip('Admin'),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (filteredUsers.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 80),
                        child: Text(
                          'No users found',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 18,
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredUsers.length,
                        itemBuilder: (context, index) {
                          return _userCard(filteredUsers[index]);
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        height: 115,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFFD9DE)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 26),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String text) {
    final selected = selectedFilter == text;

    return ChoiceChip(
      label: Text(text),
      selected: selected,
      selectedColor: const Color(0xFFD62828),
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.black,
        fontWeight: FontWeight.w600,
      ),
      onSelected: (_) {
        selectedFilter = text;
        applyFilter();
      },
    );
  }

  Widget _userCard(Map<String, dynamic> user) {
    final name = user['full_name'] ?? 'No Name';
    final email = user['email'] ?? 'No Email';
    final phone = user['phone'] ?? 'No Phone';
    final role = (user['role'] ?? 'user').toString().toLowerCase();
    final joined = formatDate(user['created_at']);

    final avatarUrl = user['avatar_url']?.toString();
    final hasAvatar = avatarUrl != null && avatarUrl.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFD9DE)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: role == 'admin'
                ? Colors.purple.withValues(alpha: 0.15)
                : Colors.red.withValues(alpha: 0.15),
            backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
            child: !hasAvatar
                ? Icon(
                    role == 'admin' ? Icons.admin_panel_settings : Icons.person,
                    color: role == 'admin' ? Colors.purple : Colors.red,
                  )
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.toString(),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email.toString(),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Text(
                  'Phone: $phone',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _badge(
                      text: role.toUpperCase(),
                      color: role == 'admin' ? Colors.purple : Colors.blue,
                    ),
                    _badge(
                      text: 'Joined $joined',
                      color: Colors.grey,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

if (role != 'admin')
ElevatedButton.icon(
  style: ElevatedButton.styleFrom(
    backgroundColor:
        (user['blocked'] ?? false)
            ? Colors.green
            : Colors.red,
    foregroundColor: Colors.white,
  ),
  onPressed: () => _toggleBlockUser(user),
  icon: Icon(
    (user['blocked'] ?? false)
        ? Icons.lock_open
        : Icons.block,
  ),
  label: Text(
    (user['blocked'] ?? false)
        ? 'Unblock'
        : 'Block',
  ),
),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge({
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}