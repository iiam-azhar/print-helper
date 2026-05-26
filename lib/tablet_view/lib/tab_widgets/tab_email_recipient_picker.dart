import 'package:flutter/material.dart';
import '../tab_constants/paths.dart';
import '../tab_widgets/tab_image_widget.dart';
import '../tab_widgets/tab_text_widget.dart';

class TabEmailRecipientPicker extends StatefulWidget {
  final List<Map<String, dynamic>> users;
  final Function(List<Map<String, dynamic>>) onSelectionChanged;

  final bool isMultiSelect;
  final List<Map<String, dynamic>>? initialSelection;
  final String hintText;

  const TabEmailRecipientPicker({
    super.key,
    required this.users,
    required this.onSelectionChanged,
    this.isMultiSelect = true,
    this.initialSelection,
    this.hintText = 'Select Email Recipients',
  });

  @override
  State<TabEmailRecipientPicker> createState() =>
      _TabEmailRecipientPickerState();
}

class _TabEmailRecipientPickerState extends State<TabEmailRecipientPicker> {
  bool _isExpanded = false;
  String _searchQuery = '';
  int? _selectedClientId;
  List<Map<String, dynamic>> _selectedUsers = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialSelection != null &&
        widget.initialSelection!.isNotEmpty) {
      _selectedUsers = List.from(widget.initialSelection!);
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    return widget.users.where((user) {
      // Filter by Client
      if (_selectedClientId != null) {
        if (user['client_id'] != _selectedClientId &&
            user['customer_client_id'] != _selectedClientId) {
          return false;
        }
      }
      // Filter by Search Query
      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final name = (user['name'] ?? '').toString().toLowerCase();
        final primaryEmail =
            (user['email'] ??
                    ((user['emails'] != null &&
                            (user['emails'] as List).isNotEmpty)
                        ? user['emails'][0]
                        : ''))
                .toString()
                .toLowerCase();
        if (!name.contains(query) && !primaryEmail.contains(query)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  List<Map<String, dynamic>> get _availableClients {
    final Map<int, String> clientMap = {};
    for (var user in widget.users) {
      if (user['client_id'] != null && user['client_name'] != null) {
        clientMap[user['client_id'] as int] = user['client_name'].toString();
      }
      if (user['customer_client_id'] != null &&
          user['customer_client_name'] != null) {
        clientMap[user['customer_client_id'] as int] =
            user['customer_client_name'].toString();
      }
    }
    final clients = clientMap.entries
        .map((e) => {'id': e.key, 'name': e.value})
        .toList();
    clients.sort(
      (a, b) => (a['name'] as String).compareTo(b['name'] as String),
    );
    return clients;
  }

  void _toggleSelection(Map<String, dynamic> user) {
    setState(() {
      final exists = _selectedUsers.any((u) => u['id'] == user['id']);
      if (widget.isMultiSelect) {
        if (exists) {
          _selectedUsers.removeWhere((u) => u['id'] == user['id']);
        } else {
          _selectedUsers.add(user);
        }
      } else {
        if (!exists) {
          _selectedUsers = [user];
        }
        _isExpanded = false; // Auto close on single select
      }
    });
    widget.onSelectionChanged(List.from(_selectedUsers));
  }

  void _removeUser(Map<String, dynamic> user) {
    setState(() {
      _selectedUsers.removeWhere((u) => u['id'] == user['id']);
    });
    widget.onSelectionChanged(List.from(_selectedUsers));
  }

  Widget _buildRoleBadge(int roleId) {
    String text = 'User';

    if (roleId == 1) {
      text = 'Admin';
    } else if (roleId == 4) {
      text = 'Contact';
    } else if (roleId == 5) {
      text = 'Customer';
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xfff5f6f1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: TextWidget(
        text: text,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: const Color(0xff4b5563),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Picker Header (acting as dropdown toggle)
        GestureDetector(
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color: _isExpanded ? Colors.green : Colors.black12,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _selectedUsers.isEmpty
                      ? TextWidget(
                          text: widget.hintText,
                          fontSize: 14,
                          color: Colors.black38,
                          fontWeight: FontWeight.w400,
                        )
                      : Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _selectedUsers.map((user) {
                            return Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xffdce89c),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(50),
                                    child: ImageWidget(
                                      image:
                                          (user['image'] != null &&
                                              user['image']
                                                  .toString()
                                                  .isNotEmpty)
                                          ? user['image'].toString()
                                          : Paths.user,
                                      height: 22,
                                      width: 22,
                                      fit: BoxFit.cover,
                                      errorWidget: ImageWidget(
                                        image: Paths.user,
                                        height: 22,
                                        width: 22,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 6),
                                  Flexible(
                                    child: TextWidget(
                                      text: user['name'] ?? '',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  SizedBox(width: 6),
                                  _buildRoleBadge(user['role'] ?? 0),
                                  SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () => _removeUser(user),
                                    child: ImageWidget(
                                      image: Paths.delete,
                                      height: 18,
                                      width: 18,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                ),
                Icon(
                  _isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: Colors.black54,
                ),
              ],
            ),
          ),
        ),

        // Expanded Panel
        if (_isExpanded)
          Container(
            margin: EdgeInsets.only(top: 8),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Client Filter
                TextWidget(
                  text: 'CLIENT',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
                SizedBox(height: 6),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      value: _selectedClientId,
                      isExpanded: true,
                      dropdownColor: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      icon: const Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.black54,
                      ),
                      items: [
                        DropdownMenuItem<int?>(
                          value: null,
                          child: TextWidget(
                            text: 'All clients',
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        ..._availableClients.map((client) {
                          return DropdownMenuItem<int?>(
                            value: client['id'] as int?,
                            child: TextWidget(
                              text: client['name'] as String,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _selectedClientId = val;
                        });
                      },
                    ),
                  ),
                ),
                SizedBox(height: 12),

                // Search Bar
                TextField(
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search users',
                    hintStyle: TextStyle(color: Colors.black38, fontSize: 13),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.black12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.black12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.black26),
                    ),
                  ),
                ),

                SizedBox(height: 12),

                // Users List
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.35,
                  ),
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: _filteredUsers.length,
                    separatorBuilder: (_, _) => SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final user = _filteredUsers[index];
                      final isSelected = _selectedUsers.any(
                        (u) => u['id'] == user['id'],
                      );
                      final clientName =
                          user['client_name'] ??
                          user['customer_client_name'] ??
                          '';

                      return GestureDetector(
                        onTap: () => _toggleSelection(user),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xffe9f3df)
                                : const Color(0xfff0f1f3),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.green
                                  : Colors.transparent,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(50),
                                child: ImageWidget(
                                  image:
                                      (user['image'] != null &&
                                          user['image'].toString().isNotEmpty)
                                      ? user['image'].toString()
                                      : Paths.user,
                                  height: 38,
                                  width: 38,
                                  fit: BoxFit.cover,
                                  errorWidget: ImageWidget(
                                    image: Paths.user,
                                    height: 38,
                                    width: 38,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextWidget(
                                      text: user['name'] ?? '',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    SizedBox(height: 4),
                                    Row(
                                      children: [
                                        _buildRoleBadge(user['role'] ?? 0),
                                        if (clientName
                                            .toString()
                                            .trim()
                                            .isNotEmpty) ...[
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: TextWidget(
                                              text: clientName,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.black45,
                                              maxLines: 1,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
