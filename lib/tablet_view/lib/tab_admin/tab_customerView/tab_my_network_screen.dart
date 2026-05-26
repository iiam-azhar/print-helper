import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:provider/provider.dart';

import 'package:print_helper/providers/client_pro.dart';
import 'package:print_helper/providers/cust_pro.dart';
import 'package:print_helper/providers/setting_pro.dart';
import 'package:print_helper/models/client_models.dart' hide ContactModel;
import 'package:print_helper/models/contact_form_models.dart';
import 'package:print_helper/models/settings_models.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:print_helper/providers/admin_pro.dart';
import 'package:print_helper/models/accounts_models.dart';
import '../../tab_services/helpers.dart';

import '../../tab_constants/colors.dart';
import '../../tab_widgets/tab_image_widget.dart';
import '../../tab_widgets/loaders.dart';
import '../../tab_widgets/tab_text_widget.dart';
import '../../tab_widgets/tab_field_widget.dart';
import '../../tab_constants/paths.dart';
import '../../tab_utils/regx.dart';
import '../../tab_utils/formatter.dart';
import 'dialog_add_customer.dart';
import 'dialog_edit_customer.dart';

class TabMyNetworkScreen extends StatefulWidget {
  final bool isFromAdmin;
  final bool isFromStaff;
  final bool isFromClient;
  final int id;
  final Function(String)? onMenuTap;

  const TabMyNetworkScreen({
    super.key,
    required this.isFromAdmin,
    required this.isFromStaff,
    required this.isFromClient,
    required this.id,
    this.onMenuTap,
  });

  @override
  State<TabMyNetworkScreen> createState() => _TabMyNetworkScreenState();
}

class _MyNetworkSection {
  final String title;
  final String key;
  final List<dynamic> items;

  _MyNetworkSection({
    required this.title,
    required this.key,
    required this.items,
  });
}

class _TabMyNetworkScreenState extends State<TabMyNetworkScreen> {
  int _activeTab = 0;
  final TextEditingController _searchCtrl = TextEditingController();
  final Set<String> _expandedCustomers = <String>{};
  int? _selectedCompanyType;
  int? _selectedStatus;
  Timer? _debounce;
  bool _hasSearched = false;
  static const double _internalOpsContactCardHeight = 260;
  bool _isChangingSupervisor = false;
  bool _isLoadingSupervisorStaff = false;
  int? _selectedSupervisorId;

  List<String> get _tabs {
    return const ['Customers', 'Assigned Team', 'Internal Ops'];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CustomerPro>().getMyNetworkTabs(
        ctx: context,
        clientId: widget.id,
      );
      context.read<ClientPro>().getClientInfoTabs(
        widget.id,
        showLoading: false,
      );
      context.read<SettingsPro>().loadSettings(ctx: context).then((_) {
        if (mounted) {
          context.read<SettingsPro>().getCustomerCompanyTypes();
        }
      });
    });
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch();
    });
  }

  Future<void> _performSearch() async {
    if (!mounted) return;
    setState(() => _hasSearched = true);

    final pro = context.read<CustomerPro>();
    pro.customerFilters = {
      if (_searchCtrl.text.trim().isNotEmpty)
        'company_name': _searchCtrl.text.trim(),
      if (_selectedCompanyType != null) 'company_type': _selectedCompanyType,
      if (_selectedStatus != null) 'contact_status': _selectedStatus,
    };

    await pro.getCustomers(ctx: context, clientId: widget.id, page: 1);
  }

  Future<void> _fetchSupervisorStaff() async {
    final clientPro = context.read<ClientPro>();
    if (clientPro.staffList.isEmpty) {
      setState(() => _isLoadingSupervisorStaff = true);
      await clientPro.fetchStaff(showLoader: false);
      if (mounted) setState(() => _isLoadingSupervisorStaff = false);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // --- Helper Methods ---
  Map<String, dynamic> _unwrapData(Map<String, dynamic> source) {
    var current = source;
    for (int i = 0; i < 3; i++) {
      final next = _asMap(
        current['data'] ?? current['web_payload'] ?? current['payload'],
      );
      if (next.isEmpty) break;
      final hasNetworkKeys =
          next.containsKey('customers') ||
          next.containsKey('tabs') ||
          next.containsKey('client') ||
          next.containsKey('assigned_team') ||
          next.containsKey('internal_ops');
      final shouldForceUnwrap =
          current.keys.length <= 3 &&
          current.containsKey('data') &&
          (current.containsKey('success') || current.containsKey('message'));
      if (hasNetworkKeys || shouldForceUnwrap) {
        current = next;
        continue;
      }
      break;
    }
    return current;
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
    return {};
  }

  List<dynamic> _asList(dynamic value) {
    if (value is List) return value;
    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) return decoded;
        if (decoded is Map<String, dynamic>) return _asList(decoded);
        if (decoded is Map) return _asList(_asMap(decoded));
      } catch (_) {}
    }
    if (value is Map<String, dynamic>) {
      for (final key in [
        'items',
        'data',
        'list',
        'records',
        'value',
        'contacts',
        'assigned_specialists',
        'staff_members',
      ]) {
        final nested = value[key];
        if (nested is List) return nested;
      }
    }
    return const [];
  }

  _MyNetworkSection _findSection(
    Map<String, dynamic> data, {
    required List<String> keys,
  }) {
    final sections = _sections(data);
    _MyNetworkSection? matchedEmptySection;

    for (final section in sections) {
      final key = section.key.toLowerCase();
      for (final k in keys) {
        if (key == k || key.contains(k)) {
          if (section.items.isNotEmpty) return section;
          matchedEmptySection ??= section;
        }
      }
    }

    for (final k in keys) {
      final rootValue = data[k];
      final rootItems = _asList(rootValue);
      if (rootItems.isNotEmpty) {
        return _MyNetworkSection(
          title: matchedEmptySection?.title ?? k,
          key: k,
          items: rootItems,
        );
      }

      final rootMap = _asMap(rootValue);
      final nestedItems = _asList(
        rootMap['items'] ??
            rootMap['data'] ??
            rootMap['list'] ??
            rootMap['records'] ??
            rootMap['value'],
      );
      if (nestedItems.isNotEmpty) {
        return _MyNetworkSection(
          title: matchedEmptySection?.title ?? k,
          key: k,
          items: nestedItems,
        );
      }
    }

    if (matchedEmptySection != null) return matchedEmptySection;

    return _MyNetworkSection(
      title: keys.first,
      key: keys.first,
      items: const [],
    );
  }

  List<_MyNetworkSection> _sections(Map<String, dynamic> data) {
    final tabs = <_MyNetworkSection>[];

    final rawTabs = data['tabs'];
    if (rawTabs is List) {
      for (final raw in rawTabs) {
        final map = _asMap(raw);
        final title = _pickString(map, [
          'title',
          'label',
          'name',
        ], fallback: 'Tab');
        final key = _pickString(map, [
          'key',
          'slug',
          'type',
        ], fallback: title).toLowerCase().replaceAll(RegExp(r'\s+'), '_');
        final items = _asList(
          map['items'] ??
              map['data'] ??
              map['list'] ??
              map['records'] ??
              map['value'],
        );
        tabs.add(_MyNetworkSection(title: title, key: key, items: items));
      }
    }

    if (rawTabs is Map) {
      for (final entry in rawTabs.entries) {
        final map = _asMap(entry.value);
        final title = _pickString(map, [
          'title',
          'label',
          'name',
        ], fallback: entry.key);
        final key = entry.key.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
        final items = _asList(
          map['items'] ??
              map['data'] ??
              map['list'] ??
              map['records'] ??
              map['value'] ??
              map,
        );
        tabs.add(_MyNetworkSection(title: title, key: key, items: items));
      }
    }

    if (tabs.isNotEmpty) return tabs;

    const fallback = <String, String>{
      'customers': 'Customers',
      'assigned_team': 'Assigned Team',
      'assigned_specialists': 'Assigned Team',
      'internal_ops': 'Internal Ops',
      'internal_operations': 'Internal Ops',
      'supervisors': 'Assigned Team',
      'contacts': 'Internal Ops',
    };

    for (final entry in fallback.entries) {
      final list = _asList(data[entry.key]);
      if (list.isNotEmpty) {
        tabs.add(
          _MyNetworkSection(title: entry.value, key: entry.key, items: list),
        );
      }
    }

    return tabs;
  }

  String _pickString(
    Map<String, dynamic> map,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = map[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    return fallback;
  }

  int _pickInt(
    Map<String, dynamic> map,
    List<String> keys, {
    int fallback = 0,
  }) {
    for (final key in keys) {
      final value = map[key];
      if (value == null) continue;
      if (value is int) return value;
      if (value is bool) return value ? 1 : 0;
      final text = value.toString().trim().toLowerCase();
      if (text == 'true' || text == 'active') return 1;
      if (text == 'false' || text == 'inactive') return 0;
      final parsed = int.tryParse(text);
      if (parsed != null) return parsed;
    }
    return fallback;
  }

  String _clientName(CustomerPro provider, Map<String, dynamic> data) {
    final fromData = _pickString(_asMap(data['client']), [
      'company_name',
      'companyName',
      'name',
    ]);
    if (fromData.isNotEmpty) return fromData;
    final providerName = provider.client?.companyName ?? '';
    if (providerName.trim().isNotEmpty) return providerName;
    return 'Client';
  }

  String _fullName(Map<String, dynamic> map) {
    final first = _pickString(map, ['name', 'first_name', 'firstName']);
    final last = _pickString(map, ['last_name', 'lastName', 'surname']);
    final combined = '$first $last'.trim();
    if (combined.isNotEmpty) return combined;
    return _pickString(map, [
      'title',
      'company_name',
      'companyName',
    ], fallback: 'Member');
  }

  String _initial(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'C';
    return trimmed.characters.first.toUpperCase();
  }

  String _safeImage(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.toLowerCase() == 'null') return Paths.user;
    return trimmed;
  }

  List<dynamic> _extractCustomers(Map<String, dynamic> data) {
    final normalized = _unwrapData(data);
    final sources = <Map<String, dynamic>>[
      normalized,
      _asMap(data['data']),
      _asMap(data['web_payload']),
      _asMap(data['payload']),
      _asMap(normalized['data']),
      _asMap(data['web_payload']),
      _asMap(normalized['web_payload']),
      _asMap(data['payload']),
      _asMap(normalized['payload']),
      _asMap(_asMap(data['tabs'])['customers']),
      _asMap(_asMap(normalized['tabs'])['customers']),
    ];

    const keys = <String>[
      'customers',
      'customer',
      'end_customers',
      'client_customers',
      'data',
      'items',
      'results',
      'rows',
    ];

    for (final source in sources) {
      if (source.isEmpty) continue;

      for (final key in keys) {
        final list = _asList(source[key]);
        if (list.isNotEmpty) return list;

        final block = _asMap(source[key]);
        final nestedList = _asList(
          block['items'] ??
              block['data'] ??
              block['list'] ??
              block['records'] ??
              block['rows'] ??
              block['results'] ??
              block['value'],
        );
        if (nestedList.isNotEmpty) return nestedList;
      }

      final rawTabs = source['tabs'];
      if (rawTabs is List) {
        for (final tab in rawTabs) {
          final tabMap = _asMap(tab);
          final tabKey = _pickString(tabMap, const [
            'key',
            'slug',
            'type',
          ]).toLowerCase();
          final tabTitle = _pickString(tabMap, const [
            'title',
            'label',
            'name',
          ]).toLowerCase();
          final isCustomersTab =
              tabKey.contains('customer') || tabTitle.contains('customer');
          if (!isCustomersTab) continue;

          final tabItems = _asList(
            tabMap['items'] ??
                tabMap['data'] ??
                tabMap['list'] ??
                tabMap['records'] ??
                tabMap['rows'] ??
                tabMap['results'] ??
                tabMap['customers'],
          );
          if (tabItems.isNotEmpty) return tabItems;

          final tabDataMap = _asMap(tabMap['data']);
          final nestedTabItems = _asList(
            tabDataMap['items'] ??
                tabDataMap['customers'] ??
                tabDataMap['list'] ??
                tabDataMap['records'] ??
                tabDataMap['rows'] ??
                tabDataMap['results'],
          );
          if (nestedTabItems.isNotEmpty) return nestedTabItems;
        }
      }

      if (rawTabs is Map) {
        for (final entry in rawTabs.entries) {
          final tabMap = _asMap(entry.value);
          final mapKey = entry.key.toLowerCase();
          final tabTitle = _pickString(tabMap, const [
            'title',
            'label',
            'name',
          ]).toLowerCase();
          final isCustomersTab =
              mapKey.contains('customer') || tabTitle.contains('customer');
          if (!isCustomersTab) continue;

          final tabItems = _asList(
            tabMap['items'] ??
                tabMap['data'] ??
                tabMap['list'] ??
                tabMap['records'] ??
                tabMap['rows'] ??
                tabMap['results'] ??
                tabMap['customers'] ??
                tabMap,
          );
          if (tabItems.isNotEmpty) return tabItems;
        }
      }
    }

    return _findSection(
      normalized,
      keys: const ['customers', 'customer', 'end_customers'],
    ).items;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: Consumer<CustomerPro>(
          builder: (context, provider, _) {
            final data = _unwrapData(provider.myNetworkTabs);
            final clientName = _clientName(provider, data);
            final clientMap = _asMap(data['client']);
            final companyLogo = _pickString(clientMap, [
              'logo',
              'company_logo',
              'image',
              'avatar',
              'photo',
              'profile_image',
            ]);
            final isActive = _pickInt(clientMap, ['status']) == 1;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _topBar(clientName, isActive, companyLogo),
                Expanded(
                  child: provider.myNetworkLoad
                      ? Center(child: showLoader())
                      : RefreshIndicator(
                          onRefresh: () => provider.getMyNetworkTabs(
                            ctx: context,
                            clientId: widget.id,
                          ),
                          child: ListView(
                            padding: const EdgeInsets.all(24),
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.02,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _tabsHeader(),
                                    Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: _tabBody(data, clientName),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _topBar(String clientName, bool isActive, String companyLogo) {
    final bool isAdminOrStaff = widget.isFromAdmin || widget.isFromStaff;
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (widget.onMenuTap != null)
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 20,
                color: Colors.black87,
              ),
              onPressed: () {
                if (widget.onMenuTap != null) {
                  widget.onMenuTap!("clients");
                }
              },
            )
          else
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 20,
                color: Colors.black87,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          const SizedBox(width: 16),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child:
                  companyLogo.isNotEmpty && companyLogo.toLowerCase() != 'null'
                  ? ImageWidget(
                      image: companyLogo,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    )
                  : ImageWidget(
                      image: Paths.user,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextWidget(
              text: 'Clients/ $clientName',
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: const Color(0xFF1E293B),
            ),
          ),
          if (isAdminOrStaff)
            GestureDetector(
              onTap: () => _showToggleClientStatusDialog(context, clientName, isActive),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isActive
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF10B981),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isActive ? Icons.block : Icons.check_circle_outline,
                      size: 16,
                      color: isActive
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF10B981),
                    ),
                    const SizedBox(width: 8),
                    TextWidget(
                      text: isActive ? 'Deactivate' : 'Activate',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isActive
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF10B981),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tabsHeader() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: List.generate(_tabs.length, (index) {
          final active = _activeTab == index;
          return GestureDetector(
            onTap: () => setState(() => _activeTab = index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: active
                        ? const Color(0xFFFACC15)
                        : Colors.transparent, // Yellow brand color
                    width: 3,
                  ),
                ),
              ),
              child: TextWidget(
                text: _tabs[index],
                fontSize: 15,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active
                    ? const Color(0xFF1E293B)
                    : const Color(0xFF64748B),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _tabBody(Map<String, dynamic> data, String clientName) {
    final currentTabName = (_activeTab >= 0 && _activeTab < _tabs.length)
        ? _tabs[_activeTab]
        : 'Customers';
    switch (currentTabName) {
      case 'Customers':
        return _customersTab(data, clientName);
      case 'Assigned Team':
        return _assignedTeamTab(data);
      case 'Internal Ops':
        return _internalOpsTab(data);
      default:
        return const SizedBox();
    }
  }

  Widget _assignedTeamTab(Map<String, dynamic> rootData) {
    final tabs = _asMap(rootData['tabs']);
    final data = tabs.containsKey('assigned_team')
        ? _asMap(tabs['assigned_team'])
        : rootData;

    final contactData = _asMap(data['contactData'] ?? data['contact_data']);
    final specialistsRaw = _asList(data['assigned_specialists']);
    final supervisorsRaw = _asList(data['supervisor']);
    final allStaff = (specialistsRaw.isNotEmpty || supervisorsRaw.isNotEmpty)
        ? [...specialistsRaw, ...supervisorsRaw]
        : _asList(contactData['assigned_staff']);

    var supervisorRaw = supervisorsRaw.isNotEmpty
        ? supervisorsRaw.first
        : (data['supervisor'] ?? contactData['supervisor']);
    if (supervisorRaw is List && supervisorRaw.isNotEmpty) {
      supervisorRaw = supervisorRaw.first;
    }
    if (supervisorRaw == null || _asMap(supervisorRaw).isEmpty) {
      supervisorRaw = allStaff.firstWhere((item) {
        final map = _asMap(item);
        final designation = _pickString(map, ['designation']).toLowerCase();
        return designation.contains('supervisor') ||
            _pickInt(map, ['role']) == 1;
      }, orElse: () => null);
    }

    final supervisor = _asMap(supervisorRaw);
    final supervisorId = _pickInt(supervisor, ['id', 'user_id']);
    final specialists = allStaff.where((item) {
      return _pickInt(_asMap(item), ['id', 'user_id']) != supervisorId;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _assignedTeamCard(
                title: 'ASSIGNED SPECIALISTS',
                minHeight: 190,
                child: Column(
                  children: [
                    if (specialists.isEmpty)
                      _emptyAssignedTeamText('No specialists assigned.')
                    else
                      ...List.generate(specialists.length, (index) {
                        return Column(
                          children: [
                            _specialistRow(specialists[index]),
                            if (index < specialists.length - 1)
                              const Divider(
                                height: 28,
                                color: Color(0xFFE5E7EB),
                              ),
                          ],
                        );
                      }),
                    if (widget.isFromAdmin) ...[
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _teamOutlineButton(
                          icon: Icons.add,
                          text: 'Assign Specialist',
                          onTap: () => _showAssignSpecialistsDialog(
                            context,
                            specialists,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _assignedTeamCard(
                title: 'SUPERVISOR',
                minHeight: 190,
                child: supervisor.isEmpty
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _emptyAssignedTeamText('No supervisor assigned.'),
                          if (widget.isFromAdmin) ...[
                            const SizedBox(height: 16),
                            _teamOutlineButton(
                              icon: Icons.add,
                              text: 'Assign Supervisor',
                              onTap: () => _showStaffSelection(
                                context,
                                isSupervisor: true,
                              ),
                            ),
                          ],
                        ],
                      )
                    : _supervisorRow(supervisor),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        _supportLinesSection(
          contactNumbers: _asList(contactData['contact_numbers']),
          assignedStaff: _asList(contactData['assigned_staff']),
          supportLines: _asList(contactData['support_lines']),
        ),
      ],
    );
  }

  Widget _assignedTeamCard({
    required String title,
    required Widget child,
    double minHeight = 0,
  }) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: minHeight),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextWidget(
            text: title,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF64748B),
            letterSpacing: 1.6,
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _specialistRow(dynamic item) {
    final map = _asMap(item);
    final title = _fullName(map);
    final subtitle = _pickString(map, [
      'designation',
      'role_name',
    ], fallback: 'Specialist');
    return Row(
      children: [
        _teamAvatar(
          title,
          _pickString(map, ['image_url', 'image', 'avatar', 'photo']),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextWidget(
                text: title,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF020617),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              TextWidget(
                text: subtitle,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
              ),
            ],
          ),
        ),
        if (widget.isFromAdmin)
          GestureDetector(
            onTap: () => _unassignStaff(map),
            child: const ImageWidget(image: Paths.delete, width: 16),
          ),
      ],
    );
  }

  Widget _supervisorRow(Map<String, dynamic> map) {
    final title = _fullName(map);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _teamAvatar(
              title,
              _pickString(map, ['image_url', 'image', 'avatar', 'photo']),
              bg: const Color(0xFFF5F3FF),
              fg: const Color(0xFF9333EA),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextWidget(
                    text: title,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF020617),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  const TextWidget(
                    text: 'Supervisor',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF3E8FF),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const TextWidget(
                text: 'Supervisor',
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF9333EA),
              ),
            ),
            if (widget.isFromAdmin && !_isChangingSupervisor) ...[
              const SizedBox(width: 10),
              _teamOutlineButton(
                text: 'Change',
                onTap: () {
                  setState(() {
                    _isChangingSupervisor = true;
                    _selectedSupervisorId = _pickInt(map, ['id', 'user_id']);
                  });
                  _fetchSupervisorStaff();
                },
              ),
            ],
          ],
        ),
        if (_isChangingSupervisor) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TextWidget(
                  text: 'Select Supervisor',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                ),
                const SizedBox(height: 8),
                _isLoadingSupervisorStaff
                    ? const Center(child: CircularProgressIndicator())
                    : Consumer<ClientPro>(
                        builder: (context, provider, _) {
                          final staffList = provider.staffList
                              .where((s) => s.role == 1)
                              .toList();
                          return Container(
                            height: 44,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              border: Border.all(
                                color: const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                borderRadius: BorderRadius.circular(12),
                                isExpanded: true,
                                value:
                                    staffList.any(
                                      (s) => s.id == _selectedSupervisorId,
                                    )
                                    ? _selectedSupervisorId
                                    : null,
                                hint: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 14),
                                  child: TextWidget(
                                    text: 'Choose a supervisor',
                                    fontSize: 14,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                icon: const Padding(
                                  padding: EdgeInsets.only(right: 14),
                                  child: Icon(
                                    Icons.keyboard_arrow_down,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                                dropdownColor: Colors.white,
                                items: staffList.map((staff) {
                                  final isSelected =
                                      staff.id == _selectedSupervisorId;
                                  return DropdownMenuItem<int>(
                                    value: staff.id,
                                    child: Container(
                                      width: double.infinity,
                                      color: isSelected
                                          ? const Color(0xFFFAF5FF)
                                          : Colors.transparent,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                      ),
                                      alignment: Alignment.centerLeft,
                                      child: TextWidget(
                                        text: staff.name,
                                        fontSize: 12,
                                        color: isSelected
                                            ? const Color(0xFF9333EA)
                                            : const Color(0xFF1E293B),
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setState(() => _selectedSupervisorId = val);
                                },
                              ),
                            ),
                          );
                        },
                      ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _teamOutlineButton(
                      text: 'Cancel',
                      onTap: () {
                        setState(() {
                          _isChangingSupervisor = false;
                        });
                      },
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () async {
                        if (_selectedSupervisorId == null) return;
                        final success = await context
                            .read<ClientPro>()
                            .assignSupervisor(
                              clientId: widget.id,
                              supervisorId: _selectedSupervisorId!,
                              showLoader: true,
                            );
                        if (!mounted) return;
                        if (success) {
                          setState(() => _isChangingSupervisor = false);
                          context.read<CustomerPro>().getMyNetworkTabs(
                            ctx: context,
                            clientId: widget.id,
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const TextWidget(
                          text: 'Save Change',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _teamAvatar(
    String title,
    String image, {
    Color bg = const Color(0xFFEFF6FF),
    Color fg = const Color(0xFF2563EB),
  }) {
    final hasImage = image.isNotEmpty && image.toLowerCase() != 'null';
    return CircleAvatar(
      radius: 22,
      backgroundColor: bg,
      child: ClipOval(
        child: hasImage
            ? ImageWidget(
                image: image,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
              )
            : TextWidget(
                text: _initial(title),
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: fg,
              ),
      ),
    );
  }

  Widget _teamOutlineButton({
    String? text,
    IconData? icon,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFD1D5DB)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: const Color(0xFF0F172A)),
              const SizedBox(width: 7),
            ],
            TextWidget(
              text: text ?? '',
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF334155),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyAssignedTeamText(String text) {
    return TextWidget(
      text: text,
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: const Color(0xFF64748B),
    );
  }

  Widget _supportLinesSection({
    required List<dynamic> contactNumbers,
    required List<dynamic> assignedStaff,
    required List<dynamic> supportLines,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TextWidget(
          text: 'PH PORTAL SUPPORT LINES',
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: Color(0xFF020617),
        ),
        const SizedBox(height: 12),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),
        const SizedBox(height: 14),
        const TextWidget(
          text: 'Lines assigned to this client. Managed in Settings.',
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Color(0xFF64748B),
        ),
        const SizedBox(height: 16),
        if (supportLines.isEmpty &&
            contactNumbers.isEmpty &&
            assignedStaff.isEmpty)
          _emptyContactCard()
        else if (supportLines.isNotEmpty)
          ...supportLines.map((item) => _supportLineGroup(item))
        else
          _supportLineFlatGroup([...contactNumbers, ...assignedStaff]),
      ],
    );
  }

  Widget _supportLineGroup(dynamic item) {
    final map = _asMap(item);
    final phone = _pickString(map, ['phone_number', 'phone']);
    final rows = <Map<String, dynamic>>[];
    final client = _asMap(map['client']);
    if (client.isNotEmpty) {
      rows.add({
        'name': _pickString(client, ['company_name', 'name']),
        'designation': 'Client',
        'image': _pickString(client, ['image', 'logo']),
        'phone': phone,
        'show_phone': true,
      });
    }
    for (final staff in _asList(map['assigned_staff'])) {
      final staffMap = _asMap(staff);
      rows.add({
        'name': _fullName(staffMap),
        'designation': _pickString(staffMap, [
          'designation',
          'role_name',
        ], fallback: 'Supervisor'),
        'image': _pickString(staffMap, ['image', 'avatar', 'photo']),
        'show_phone': false,
      });
    }
    for (final contact in _asList(map['contact_numbers'])) {
      final contactMap = _asMap(contact);
      rows.add({
        'name': _fullName(contactMap),
        'designation': 'Client Contact',
        'image': _pickString(contactMap, ['image', 'avatar', 'photo']),
        'show_phone': false,
      });
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: _supportLineFlatGroup(rows),
    );
  }

  Widget _supportLineFlatGroup(List<dynamic> rows) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: List.generate(rows.length, (index) {
          return Column(
            children: [
              _supportLineRow(rows[index]),
              if (index < rows.length - 1)
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
            ],
          );
        }),
      ),
    );
  }

  Widget _supportLineRow(dynamic item) {
    final map = _asMap(item);
    final title = _pickString(map, ['name'], fallback: _fullName(map));
    final subtitle = _pickString(map, [
      'designation',
      'role_name',
    ], fallback: 'Specialist');
    final phone = _pickString(map, [
      'phone',
      'contact_number',
      'phone_number',
    ], fallback: '---');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _teamAvatar(
            title,
            _pickString(map, ['image', 'avatar', 'photo']),
            bg: const Color(0xFFF1F5F9),
            fg: const Color(0xFF64748B),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextWidget(
                  text: title,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF020617),
                ),
                TextWidget(
                  text: subtitle,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                ),
              ],
            ),
          ),
          if (map['show_phone'] != false)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextWidget(
                text: phone,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1E293B),
              ),
            ),
        ],
      ),
    );
  }

  Widget _internalOpsTab(Map<String, dynamic> rootData) {
    final tabs = _asMap(rootData['tabs']);
    final internalOps = tabs.containsKey('internal_ops')
        ? _asMap(tabs['internal_ops'])
        : _asMap(rootData['internal_ops']);
    final contacts = _asList(
      internalOps['contacts'] ??
          internalOps['items'] ??
          internalOps['data'] ??
          rootData['contacts'],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: TextWidget(
                text:
                    'Main contact can manage all contacts. Additional contacts are view-only except their own settings.',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 16),
            _internalOpsAddButton(),
          ],
        ),
        const SizedBox(height: 26),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth >= 820 ? 3 : 2;
            final cardWidth =
                (constraints.maxWidth - (16 * (crossAxisCount - 1))) /
                crossAxisCount;
            final cards = <Widget>[
              ...contacts.map((item) {
                final contact = _asMap(item);
                return SizedBox(
                  width: cardWidth,
                  child: _contactCard(contact, customerMap: const {}),
                );
              }),
              SizedBox(
                width: cardWidth,
                child: GestureDetector(
                  onTap: () async {
                    final saved = await _showEditContactDialog(context, {});
                    if (saved == true && mounted) {
                      this.context.read<CustomerPro>().getMyNetworkTabs(
                        ctx: this.context,
                        clientId: widget.id,
                      );
                    }
                  },
                  child: _addContactCard(),
                ),
              ),
            ];
            return Wrap(spacing: 16, runSpacing: 16, children: cards);
          },
        ),
      ],
    );
  }

  Widget _internalOpsAddButton() {
    return GestureDetector(
      onTap: () async {
        final saved = await _showEditContactDialog(context, {});
        if (saved == true && mounted) {
          context.read<CustomerPro>().getMyNetworkTabs(
            ctx: context,
            clientId: widget.id,
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF22C55E),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, color: Colors.white, size: 16),
            SizedBox(width: 6),
            TextWidget(
              text: 'Add Contact',
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  Widget _customersTab(Map<String, dynamic> data, String clientName) {
    final settingsPro = context.watch<SettingsPro>();
    final typeSection = settingsPro.sections.firstWhere(
      (s) => s.title.toLowerCase().contains("customer company"),
      orElse: () => SettingsSection(id: 0, title: '', items: []),
    );
    final companyTypes = typeSection.items;

    List<dynamic> allCustomers;
    if (_hasSearched) {
      allCustomers = context.read<CustomerPro>().customers;
    } else {
      allCustomers = _extractCustomers(data);
    }

    final customers = _hasSearched
        ? allCustomers
        : allCustomers.where((item) {
            final map = _asMap(item);
            final typeId = _pickInt(map, [
              'company_type_id',
              'company_category',
            ]);
            final status = _pickInt(map, ['status']);
            final name = _fullName(map).toLowerCase();
            final query = _searchCtrl.text.trim().toLowerCase();

            bool matchesType =
                _selectedCompanyType == null || typeId == _selectedCompanyType;
            bool matchesStatus =
                _selectedStatus == null || status == _selectedStatus;
            bool matchesSearch = query.isEmpty || name.contains(query);

            return matchesType && matchesStatus && matchesSearch;
          }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextWidget(
                text:
                    'End customers of $clientName. Admin can add, edit, and delete on behalf of the client.',
                fontSize: 14,
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w400,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => DialogAddCustomer(clientId: widget.id),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.add, color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    TextWidget(
                      text: 'Customer',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search,
                      color: Color(0xFF94A3B8),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: _onSearchChanged,
                        decoration: const InputDecoration(
                          hintText: 'Search customers...',
                          hintStyle: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 1,
              child: _filterDropdown<int>(
                label: 'All Types',
                value: _selectedCompanyType,
                items: [
                  const DropdownMenuItem<int>(
                    value: null,
                    child: Text('All Types'),
                  ),
                  ...companyTypes.map(
                    (type) => DropdownMenuItem<int>(
                      value: type.id,
                      child: Text(type.name, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: (val) {
                  setState(() => _selectedCompanyType = val);
                  _performSearch();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 1,
              child: _filterDropdown<int>(
                label: 'All Status',
                value: _selectedStatus,
                items: const [
                  DropdownMenuItem<int>(value: null, child: Text('All Status')),
                  DropdownMenuItem<int>(value: 1, child: Text('Active')),
                  DropdownMenuItem<int>(value: 0, child: Text('Inactive')),
                ],
                onChanged: (val) {
                  setState(() => _selectedStatus = val);
                  _performSearch();
                },
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () {
                setState(() {
                  _searchCtrl.clear();
                  _selectedCompanyType = null;
                  _selectedStatus = null;
                  _hasSearched = false;
                });
                context.read<CustomerPro>().getCustomers(
                  ctx: context,
                  clientId: widget.id,
                  page: 1,
                );
              },
              child: Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.refresh,
                  color: Color(0xFF64748B),
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              height: 44,
              width: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const TextWidget(
                text: '1',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (customers.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 40),
            alignment: Alignment.center,
            child: const TextWidget(
              text: 'No customers found.',
              fontSize: 16,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: customers.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = customers[index];
              return _customerRowCard(
                item: item,
                isExpanded: _expandedCustomers.contains(
                  _pickString(_asMap(item), ['id']).toString(),
                ),
                onToggle: () {
                  final idStr = _pickString(_asMap(item), ['id']).toString();
                  setState(() {
                    if (_expandedCustomers.contains(idStr)) {
                      _expandedCustomers.remove(idStr);
                    } else {
                      _expandedCustomers.add(idStr);
                    }
                  });
                },
              );
            },
          ),
      ],
    );
  }

  Widget _filterDropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 20,
            color: Color(0xFF64748B),
          ),
          hint: TextWidget(
            text: label,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF64748B),
          ),
          items: items,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _showDeleteCustomerDialog(
    BuildContext context,
    Map<String, dynamic> customerMap,
  ) {
    final title = _pickString(customerMap, [
      'company_name',
      'companyName',
      'name',
      'title',
    ], fallback: 'Customer');
    final customerId = _pickInt(customerMap, ['id', 'customer_id']);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TextWidget(
                  text: 'Delete Customer',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
                const SizedBox(height: 12),
                TextWidget(
                  text:
                      'Are you sure you want to delete "$title"? This action cannot be undone.',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF475569),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(dialogContext),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const TextWidget(
                          text: 'Cancel',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () async {
                        final customerPro = context.read<CustomerPro>();
                        Navigator.pop(dialogContext);
                        final success = await customerPro.deleteCust(
                          customerId,
                          context,
                        );
                        if (success && mounted) {
                          customerPro.getMyNetworkTabs(
                            ctx: context,
                            clientId: widget.id,
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const TextWidget(
                          text: 'Delete',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _customerRowCard({
    required dynamic item,
    required bool isExpanded,
    required VoidCallback onToggle,
  }) {
    final map = _asMap(item);
    final title = _pickString(map, [
      'company_name',
      'companyName',
      'name',
      'title',
    ], fallback: 'Customer');
    final subtype = _pickString(map, [
      'company_type',
      'company_type_name',
      'companyTypeName',
    ], fallback: 'Company');
    final image = _pickString(map, ['image', 'avatar', 'logo', 'photo']);
    final projects = _pickString(map, ['projects_count'], fallback: '0');
    final files = _pickString(map, ['files_count'], fallback: '0');
    final dateRaw = _pickString(map, ['created_at', 'date']);
    final contacts = _asList(
      map['contacts'] ?? map['customer_contacts'] ?? map['contact_data'],
    );

    // Formatting date
    String dateStr = '';
    if (dateRaw.isNotEmpty) {
      final dt = DateTime.tryParse(dateRaw);
      if (dt != null) {
        final months = [
          "Jan",
          "Feb",
          "Mar",
          "Apr",
          "May",
          "Jun",
          "Jul",
          "Aug",
          "Sep",
          "Oct",
          "Nov",
          "Dec",
        ];
        dateStr = '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
      } else {
        dateStr = dateRaw;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFE0E7FF),
                child: ClipOval(
                  child: image.isNotEmpty && image.toLowerCase() != 'null'
                      ? ImageWidget(
                          image: _safeImage(image),
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                        )
                      : TextWidget(
                          text: _initial(title),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF4338CA),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextWidget(
                      text: title,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                    ),
                    const SizedBox(height: 4),
                    TextWidget(
                      text:
                          '$subtype - $projects Projects - $files Files${dateStr.isNotEmpty ? ' - $dateStr' : ''}',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF94A3B8),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => DialogEditCustomer(
                          customerId: _pickInt(map, ['id']),
                          clientId: widget.id,
                        ),
                      ).then((_) {
                        if (mounted) {
                          context.read<CustomerPro>().getMyNetworkTabs(
                            ctx: context,
                            clientId: widget.id,
                          );
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ImageWidget(image: Paths.edit, width: 14),
                          SizedBox(width: 6),
                          TextWidget(
                            text: 'Edit',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF475569),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 35,
                    width: 48,
                    child: FittedBox(
                      fit: BoxFit.fill,
                      child: Switch(
                        value: _pickInt(map, ['status']) == 1,
                        onChanged: (val) async {
                          final customerId = _pickInt(map, ['id', 'customer_id']);
                          if (customerId != 0) {
                            await context.read<CustomerPro>().toggleStatus(
                              clientId: widget.id,
                              custId: customerId,
                              newStatus: val,
                            );
                            if (mounted) {
                              context.read<CustomerPro>().getMyNetworkTabs(
                                ctx: context,
                                clientId: widget.id,
                              );
                            }
                          }
                        },
                        activeThumbColor: Colors.white,
                        activeTrackColor: const Color(0xFF22C55E),
                        inactiveTrackColor: const Color(0xFFE2E8F0),
                        inactiveThumbColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => _showDeleteCustomerDialog(context, map),
                    child: const ImageWidget(image: Paths.delete, width: 18),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: onToggle,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: const Color(0xFF475569),
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (isExpanded) ...[
            const SizedBox(height: 16),
            const Divider(color: Color(0xFFE2E8F0), height: 1),
            const SizedBox(height: 16),
            _expandedContactsArea(contacts, customerMap: map),
          ],
        ],
      ),
    );
  }

  Widget _expandedContactsArea(
    List<dynamic> contacts, {
    required Map<String, dynamic> customerMap,
  }) {
    final mainContact = contacts.isNotEmpty
        ? _asMap(contacts.first)
        : <String, dynamic>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TextWidget(
          text: 'CONTACTS',
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF475569),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 4,
                child: mainContact.isEmpty
                    ? _emptyContactCard()
                    : _contactCard(mainContact, customerMap: customerMap),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 4,
                child: GestureDetector(
                  onTap: () {
                    // Add Contact placeholder
                  },
                  child: _addContactCard(),
                ),
              ),
              const Spacer(
                flex: 3,
              ), // Add space to the right so cards aren't too wide on large screens
            ],
          ),
        ),
      ],
    );
  }

  Widget _contactCard(
    Map<String, dynamic> contact, {
    Map<String, dynamic>? customerMap,
  }) {
    final name = _fullName(contact);
    final username = _pickString(contact, const [
      'username',
    ], fallback: '@user');
    String email = _primaryEmail(contact);
    if (email.isEmpty) email = 'No email';
    String phone = _primaryPhone(contact);
    if (phone.isEmpty) phone = 'No phone';
    final language = _primaryLanguage(contact);

    final isPrimary =
        contact['is_primary'] == true ||
        contact['is_primary'] == 1 ||
        contact['is_primary'] == '1' ||
        contact['is_primary'] == 'true';

    final showYellowBorder = isPrimary;

    String displayUsername = username;
    if (displayUsername.isNotEmpty && !displayUsername.startsWith('@')) {
      displayUsername = '@$displayUsername';
    }

    final rawImage = _pickString(contact, const [
      'image_url',
      'image',
      'avatar',
      'photo',
    ]);
    final image = rawImage.startsWith('http') ? rawImage : '';

    return SizedBox(
      height: _internalOpsContactCardHeight,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: showYellowBorder
                ? const Color(0xFFFACC15)
                : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: showYellowBorder
                      ? const Color(0xFFFACC15)
                      : const Color(0xFFF1F5F9),
                  child: ClipOval(
                    child: image.isNotEmpty && image.toLowerCase() != 'null'
                        ? ImageWidget(
                            image: image,
                            width: 32,
                            height: 32,
                            fit: BoxFit.cover,
                          )
                        : TextWidget(
                            text: _initial(name),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E293B),
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextWidget(
                        text: name,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E293B),
                      ),
                      TextWidget(
                        text: displayUsername,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                    ],
                  ),
                ),
                if (isPrimary)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF9C3),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const TextWidget(
                      text: 'Main',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFCA8A04),
                    ),
                  ),
                if (!isPrimary && widget.isFromAdmin)
                  GestureDetector(
                    onTap: () => _removeInternalOpsContact(contact),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const ImageWidget(image: Paths.delete, width: 14),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _contactInfoLine(
              icon: Icons.email,
              iconColor: const Color(0xFFD8B4FE),
              text: email,
            ),
            const SizedBox(height: 8),
            _contactInfoLine(
              icon: Icons.phone,
              iconColor: const Color(0xFFE11D48),
              text: phone,
            ),
            if (language.isNotEmpty) ...[
              const SizedBox(height: 8),
              _contactInfoLine(
                icon: Icons.translate,
                iconColor: const Color(0xFF22C55E),
                text: language,
              ),
            ],
            if (!isPrimary) ...[
              const SizedBox(height: 8),
              _contactInfoLine(
                icon: Icons.shield,
                iconColor: const Color(0xFF3B82F6),
                text: 'View only',
              ),
            ],
            const Spacer(),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _contactActionBtn(
                  icon: Icons.edit_outlined,
                  label: 'Edit',
                  color: const Color(0xFF475569),
                  bgColor: const Color(0xFFF1F5F9),
                  onTap: () async {
                    final saved = await _showEditContactDialog(
                      context,
                      contact,
                    );
                    if (saved == true && mounted) {
                      context.read<CustomerPro>().getMyNetworkTabs(
                        ctx: context,
                        clientId: widget.id,
                      );
                    }
                  },
                ),
                _contactActionBtn(
                  icon: Icons.key_outlined,
                  label: 'Reset PW',
                  color: const Color(0xFF475569),
                  bgColor: const Color(0xFFF1F5F9),
                  onTap: () => _showResetPasswordDialog(context, contact),
                ),
                if (widget.isFromAdmin)
                  _contactActionBtn(
                    icon: Icons.login_rounded,
                    label: 'Login',
                    color: Colors.white,
                    bgColor: const Color(0xFF22C55E),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _contactActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: bgColor == Colors.transparent
                ? const Color(0xFFE2E8F0)
                : bgColor,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            TextWidget(
              text: label,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ],
        ),
      ),
    );
  }

  Widget _contactInfoLine({
    required IconData icon,
    required Color iconColor,
    required String text,
  }) {
    return Row(
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 7),
        Expanded(
          child: TextWidget(
            text: text,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF475569),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _addContactCard() {
    return SizedBox(
      width: double.infinity,
      height: _internalOpsContactCardHeight,
      child: DottedBorder(
        options: const RoundedRectDottedBorderOptions(
          radius: Radius.circular(12),
          color: Color(0xFFCBD5E1),
          strokeWidth: 1,
          dashPattern: [4, 4],
          padding: EdgeInsets.zero,
        ),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_add_alt_1, size: 24, color: Color(0xFF94A3B8)),
              SizedBox(height: 8),
              TextWidget(
                text: 'Add Contact',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyContactCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      alignment: Alignment.center,
      child: const TextWidget(
        text: 'No contacts found.',
        fontSize: 14,
        color: Color(0xFF64748B),
        fontWeight: FontWeight.w500,
      ),
    );
  }

  String _primaryEmail(Map<String, dynamic> contact) {
    final direct = _pickString(contact, const ['email']);
    if (direct.isNotEmpty) return direct;
    final details = _asMap(contact['contact_details'] ?? {});
    final emails = _asList(contact['emails'] ?? details['emails']);
    return emails.isEmpty ? '' : emails.first.toString();
  }

  String _primaryPhone(Map<String, dynamic> contact) {
    final direct = _pickString(contact, const [
      'phone',
      'phone_number',
      'mobile',
    ]);
    if (direct.isNotEmpty) return direct;
    final details = _asMap(contact['contact_details'] ?? {});
    final phones = _asList(contact['phones'] ?? details['phones']);
    if (phones.isEmpty) return '';
    final first = phones.first;
    if (first is Map) {
      return _pickString(_asMap(first), const ['number', 'value', 'phone']);
    }
    return first.toString();
  }

  String _primaryLanguage(Map<String, dynamic> contact) {
    final languageNames = _asList(contact['language_names']);
    if (languageNames.isNotEmpty) return languageNames.first.toString();
    final details = _asMap(contact['contact_details'] ?? {});
    final detailNames = _asList(details['language_names']);
    if (detailNames.isNotEmpty) return detailNames.first.toString();
    return _pickString(contact, const ['language', 'language_name']);
  }

  ContactFormModel _contactFormFromMap(Map<String, dynamic> contact) {
    final model = ContactFormModel();
    final contactId = _pickInt(contact, const ['id', 'contact_id', 'user_id']);
    model.id = contactId == 0 ? null : contactId;
    model.existingId = model.id;
    model.username.text = _pickString(contact, const ['username']);

    final first = _pickString(contact, const ['name', 'first_name']);
    final last = _pickString(contact, const ['last_name', 'surname']);
    if (last.isEmpty && first.contains(' ')) {
      final parts = first.split(RegExp(r'\s+'));
      model.firstName.text = parts.first;
      model.lastName.text = parts.skip(1).join(' ');
    } else {
      model.firstName.text = first;
      model.lastName.text = last;
    }

    model.emails.first.text = _primaryEmail(contact);
    model.phoneFields.first.controller.text = _primaryPhone(contact);
    model.existingImageUrl = _pickString(contact, const [
      'image_url',
      'image',
      'avatar',
      'photo',
    ]);
    final details = _asMap(contact['contact_details'] ?? {});
    final languageIds = _asList(contact['languages'] ?? details['languages']);
    model.selectedLanguageIds = languageIds
        .map((item) => item is Map ? _pickInt(_asMap(item), const ['id']) : 0)
        .where((id) => id != 0)
        .toList();
    return model;
  }

  Future<bool?> _showEditContactDialog(
    BuildContext context,
    Map<String, dynamic> contact,
  ) {
    final model = _contactFormFromMap(contact);
    final contactId = model.existingId ?? 0;
    final isEditing = contactId != 0;
    int? openPhoneDropdownIndex;

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Container(
                width: 560,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _contactHeader(
                      dialogContext,
                      isEditing ? 'Edit Contact' : 'New Contact',
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _contactProfileImage(model, setState),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: _editContactField(
                                    controller: model.firstName,
                                    label: 'First Name',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _editContactField(
                                    controller: model.lastName,
                                    label: 'Last Name',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _editContactField(
                                    controller: model.username,
                                    label: 'Username',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _contactLanguageSec(model, setState),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _contactEmailSection(model, setState),
                            const SizedBox(height: 12),
                            _contactPhoneSection(
                              model,
                              setState,
                              openPhoneDropdownIndex,
                              (idx) =>
                                  setState(() => openPhoneDropdownIndex = idx),
                            ),
                            if (!isEditing || _activeTab == 2) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _editContactField(
                                      controller: model.password,
                                      label: 'Password',
                                      obscure: model.obscurePass,
                                      isPassword: true,
                                      onToggle: () => setState(
                                        () => model.obscurePass =
                                            !model.obscurePass,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _editContactField(
                                      controller: model.confirmPassword,
                                      label: 'Confirm Password',
                                      obscure: model.obscureConfirm,
                                      isPassword: true,
                                      onToggle: () => setState(
                                        () => model.obscureConfirm =
                                            !model.obscureConfirm,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 24),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                GestureDetector(
                                  onTap: () async {
                                    if (!isEditing &&
                                        model.password.text.trim() !=
                                            model.confirmPassword.text.trim()) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Passwords do not match',
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                    final success = await context
                                        .read<CustomerPro>()
                                        .saveClientContact(
                                          clientId: widget.id,
                                          contactId: isEditing
                                              ? contactId
                                              : null,
                                          contact: model,
                                          context: context,
                                        );
                                    if (!context.mounted) return;
                                    if (success)
                                      Navigator.pop(dialogContext, true);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF22C55E),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        TextWidget(
                                          text: isEditing
                                              ? 'Update Contact'
                                              : 'Save Contact',
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                GestureDetector(
                                  onTap: () =>
                                      Navigator.pop(dialogContext, false),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const TextWidget(
                                      text: 'Cancel',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _contactHeader(BuildContext context, String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextWidget(
            text: title,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.close, color: Colors.white, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _contactProfileImage(ContactFormModel model, StateSetter setState) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onTap: () async {
                  FilePickerResult? result = await FilePicker.platform
                      .pickFiles(type: FileType.image);
                  if (result != null) {
                    setState(() {
                      model.image = File(result.files.single.path!);
                    });
                  }
                },
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300, width: 2),
                    image: model.image != null
                        ? DecorationImage(
                            image: FileImage(model.image!),
                            fit: BoxFit.cover,
                          )
                        : (model.existingImageUrl != null &&
                              model.existingImageUrl!.isNotEmpty)
                        ? DecorationImage(
                            image: NetworkImage(model.existingImageUrl!),
                            fit: BoxFit.cover,
                          )
                        : DecorationImage(
                            image: AssetImage(Paths.user),
                            fit: BoxFit.contain,
                          ),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  onTap: () async {
                    FilePickerResult? result = await FilePicker.platform
                        .pickFiles(type: FileType.image);
                    if (result != null) {
                      setState(() {
                        model.image = File(result.files.single.path!);
                      });
                    }
                  },
                  child: ImageWidget(image: Paths.edit, width: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextWidget(
            text: "Profile photo · JPG, PNG, WEBP, GIF (max 800KB)",
            fontSize: 12,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w400,
          ),
        ],
      ),
    );
  }

  Widget _contactLanguageSec(ContactFormModel model, StateSetter setState) {
    final pro = getAdminPro(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 15),
          child: TextWidget(
            text: 'Language',
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: Color(0xFF020617),
          ),
        ),
        const SizedBox(height: 5),
        GestureDetector(
          onTap: () {
            setState(
              () => model.showLanguageDropdown = !model.showLanguageDropdown,
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade400, width: 1.3),
              color: Colors.white,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: model.selectedLanguageIds.isEmpty
                        ? [
                            TextWidget(
                              text: "Select",
                              color: Colors.grey.shade500,
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                          ]
                        : model.selectedLanguageIds.map((id) {
                            final lang = pro.languages.firstWhere(
                              (e) => e.id == id,
                              orElse: () => pro.languages.first,
                            );

                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE9F5D4),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextWidget(
                                    text: lang.name,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        model.selectedLanguageIds.remove(id);
                                      });
                                    },
                                    child: const Icon(Icons.close, size: 16),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                  ),
                ),
                Icon(
                  model.showLanguageDropdown
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: Colors.grey.shade500,
                ),
              ],
            ),
          ),
        ),
        if (model.showLanguageDropdown)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade400, width: 1.3),
              color: Colors.white,
            ),
            child: Column(
              children: pro.languages.map((lang) {
                bool selected = model.selectedLanguageIds.contains(lang.id);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (selected) {
                        model.selectedLanguageIds.remove(lang.id);
                      } else {
                        model.selectedLanguageIds.add(lang.id);
                      }
                      model.showLanguageDropdown = false;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 14,
                    ),
                    margin: const EdgeInsets.only(bottom: 3, top: 3),
                    color: Colors.transparent,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextWidget(
                          text: lang.name,
                          fontSize: 13,
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.w500,
                        ),
                        if (selected)
                          const Icon(
                            Icons.check_circle,
                            size: 20,
                            color: Colors.green,
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _contactEmailSection(ContactFormModel model, StateSetter setState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 15),
          child: TextWidget(
            text: "Email (s)",
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: const Color(0xFF020617),
          ),
        ),
        const SizedBox(height: 5),
        Column(
          children: List<Widget>.from(
            model.emails.asMap().entries.map((
              MapEntry<int, TextEditingController> entry,
            ) {
              int index = entry.key;
              TextEditingController ctrl = entry.value;
              bool isLast = index == model.emails.length - 1;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(child: EmailListTextField(controller: ctrl)),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        if (isLast) {
                          setState(
                            () => model.emails.add(TextEditingController()),
                          );
                        } else {
                          setState(() => model.emails.removeAt(index));
                        }
                      },
                      child: Container(
                        width: 41,
                        height: 41,
                        decoration: isLast
                            ? const BoxDecoration(
                                color: Color(0xFF22C55E),
                                shape: BoxShape.circle,
                              )
                            : null,
                        child: isLast
                            ? const Icon(
                                Icons.add,
                                size: 22,
                                color: Colors.white,
                              )
                            : Container(
                                padding: const EdgeInsets.all(10),
                                width: 45,
                                height: 45,
                                child: ImageWidget(
                                  image: Paths.delete,
                                  width: 12,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _contactPhoneSection(
    ContactFormModel model,
    StateSetter setState,
    int? openIndex,
    ValueChanged<int?> onOpenIndexChanged,
  ) {
    final List<PhoneType> phoneTypes = [
      PhoneType("Phone", Paths.call, "mobile"),
      PhoneType("Land Phone", Paths.landPhone, "phone"),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 15),
          child: TextWidget(
            text: "Phone(s)",
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: const Color(0xFF020617),
          ),
        ),
        const SizedBox(height: 5),
        Column(
          children: List<Widget>.from(
            model.phoneFields.asMap().entries.map((
              MapEntry<int, PhoneField> entry,
            ) {
              int index = entry.key;
              PhoneField field = entry.value;
              bool isLast = index == model.phoneFields.length - 1;
              return Column(
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          onOpenIndexChanged(openIndex == index ? null : index);
                        },
                        child: Container(
                          height: 48,
                          width: 90,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.grey.shade400,
                              width: 1.3,
                            ),
                            color: Colors.white,
                          ),
                          child: Row(
                            children: [
                              ImageWidget(image: field.type.image, width: 20),
                              const Spacer(),
                              Icon(
                                openIndex == index
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.grey.shade400,
                              width: 1.3,
                            ),
                            color: Colors.white,
                          ),
                          child: TextField(
                            controller: field.controller,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: field.type.label == "Phone"
                                  ? "Type Phone No"
                                  : field.type.label == "Land Phone"
                                  ? "Landline"
                                  : "other",
                              hintStyle: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 14,
                              ),
                            ),
                            inputFormatters: [InternationalPhoneFormatter()],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () {
                          if (isLast) {
                            setState(() {
                              model.phoneFields.add(
                                PhoneField(
                                  type: phoneTypes[1],
                                  controller: TextEditingController(),
                                ),
                              );
                            });
                          } else {
                            setState(() => model.phoneFields.removeAt(index));
                          }
                        },
                        child: Container(
                          width: 45,
                          height: 45,
                          decoration: isLast
                              ? const BoxDecoration(
                                  color: Color(0xFF22C55E),
                                  shape: BoxShape.circle,
                                )
                              : null,
                          child: isLast
                              ? const Icon(
                                  Icons.add,
                                  size: 23,
                                  color: Colors.white,
                                )
                              : Container(
                                  padding: const EdgeInsets.all(10),
                                  width: 45,
                                  height: 45,
                                  child: ImageWidget(
                                    image: Paths.delete,
                                    width: 12,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                  if (index != model.phoneFields.length - 1)
                    const SizedBox(height: 10),
                  if (openIndex == index)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 6, bottom: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.grey.shade400,
                          width: 1.3,
                        ),
                      ),
                      child: Column(
                        children: List<Widget>.from(
                          phoneTypes.map((PhoneType type) {
                            bool selected = field.type.label == type.label;
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  field.type = type;
                                  onOpenIndexChanged(null);
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 14,
                                ),
                                margin: const EdgeInsets.only(
                                  bottom: 3,
                                  top: 5,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  color: selected
                                      ? const Color(0xFFE9F5D4)
                                      : Colors.grey.shade200,
                                ),
                                child: Row(
                                  children: [
                                    ImageWidget(image: type.image, width: 22),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextWidget(
                                        text: type.label,
                                        fontSize: 13,
                                        fontWeight: selected
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                      ),
                                    ),
                                    if (selected)
                                      const Icon(
                                        Icons.check_circle,
                                        size: 22,
                                        color: Colors.green,
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _editContactField({
    required TextEditingController controller,
    required String label,
    bool obscure = false,
    bool isPassword = false,
    VoidCallback? onToggle,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 15),
          child: TextWidget(
            text: label,
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: const Color(0xFF020617),
          ),
        ),
        const SizedBox(height: 5),
        CustomTextField(
          controller: controller,
          passField: isPassword,
          obscureText: obscure,
          regExpCondition: isPassword
              ? Regx.optionalPasswordRegExp
              : Regx.optionalText,
          hintText: 'Type $label',
          filled: true,
          fillColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 15),
          suffixIcon: isPassword
              ? GestureDetector(
                  onTap: onToggle,
                  child: Icon(
                    obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                    color: Colors.grey,
                  ),
                )
              : null,
        ),
      ],
    );
  }

  void _showResetPasswordDialog(
    BuildContext context,
    Map<String, dynamic> contact,
  ) {
    final contactId = _pickInt(contact, const ['id', 'contact_id', 'user_id']);
    final passCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Container(
            width: 460,
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                  children: [
                    Expanded(
                      child: TextWidget(
                        text: 'Reset Password',
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                TextWidget(
                  text: _fullName(contact),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                ),
                const SizedBox(height: 18),
                _editContactField(
                  controller: passCtrl,
                  label: 'New Password',
                  obscure: true,
                ),
                const SizedBox(height: 12),
                _editContactField(
                  controller: confirmCtrl,
                  label: 'Confirm Password',
                  obscure: true,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        if (passCtrl.text.trim() != confirmCtrl.text.trim()) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Passwords do not match'),
                            ),
                          );
                          return;
                        }
                        final success = await context
                            .read<ClientPro>()
                            .resetContactPassword(
                              ctx: context,
                              contactId: contactId,
                              password: passCtrl.text.trim(),
                              passwordConfirmation: confirmCtrl.text.trim(),
                            );
                        if (!context.mounted) return;
                        if (success) Navigator.pop(dialogContext);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.check, color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            TextWidget(
                              text: 'Update Password',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => Navigator.pop(dialogContext),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const TextWidget(
                          text: 'Cancel',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            ),
          ),
        );
      },
    );
  }

  void _showToggleClientStatusDialog(
    BuildContext context,
    String clientName,
    bool currentStatus,
  ) {
    final action = currentStatus ? 'Deactivate' : 'Activate';
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextWidget(
                  text: '$action Client',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
                const SizedBox(height: 12),
                TextWidget(
                  text: 'Are you sure you want to $action "$clientName"?',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF475569),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(dialogContext),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const TextWidget(
                          text: 'Cancel',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () async {
                        final clientPro = context.read<ClientPro>();
                        Navigator.pop(dialogContext);
                        await clientPro.toggleStatus(
                          widget.id,
                          !currentStatus,
                          context,
                        );
                        if (context.mounted) {
                          context.read<CustomerPro>().getMyNetworkTabs(
                            ctx: context,
                            clientId: widget.id,
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: currentStatus
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: TextWidget(
                          text: action,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _removeInternalOpsContact(Map<String, dynamic> contact) async {
    final contactId = _pickInt(contact, const ['id', 'contact_id', 'user_id']);
    if (contactId == 0) return;
    final data = _unwrapData(context.read<CustomerPro>().myNetworkTabs);
    final internalOps = _asMap(_asMap(data['tabs'])['internal_ops']);
    final contacts = _asList(internalOps['contacts']);
    final ids = contacts
        .map(
          (item) =>
              _pickInt(_asMap(item), const ['id', 'contact_id', 'user_id']),
        )
        .where((id) => id != 0 && id != contactId)
        .toList();
    final success = await context
        .read<ClientPro>()
        .updateClientInternalOpsContacts(
          clientId: widget.id,
          contactIds: ids,
          showLoader: true,
        );
    if (success && mounted) {
      context.read<CustomerPro>().getMyNetworkTabs(
        ctx: context,
        clientId: widget.id,
      );
    }
  }

  Future<void> _unassignStaff(Map<String, dynamic> staffMap) async {
    final staffId = _pickInt(staffMap, ['id', 'user_id']);
    if (staffId == 0) return;
    final success = await context.read<ClientPro>().unassignStaff(
      clientId: widget.id,
      staffId: staffId,
    );
    if (success && mounted) {
      context.read<CustomerPro>().getMyNetworkTabs(
        ctx: context,
        clientId: widget.id,
      );
    }
  }

  void _showAssignSpecialistsDialog(
    BuildContext context,
    List<dynamic> currentSpecialists,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return _AssignSpecialistsDialogWidget(
          clientId: widget.id,
          currentSpecialists: currentSpecialists,
          onUpdate: () {
            context.read<CustomerPro>().getMyNetworkTabs(
              ctx: context,
              clientId: widget.id,
            );
          },
        );
      },
    );
  }

  void _showStaffSelection(BuildContext context, {required bool isSupervisor}) {
    final clientPro = context.read<ClientPro>();
    if (clientPro.staffList.isEmpty) {
      clientPro.fetchStaff(showLoader: false);
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Container(
            width: 520,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextWidget(
                        text: isSupervisor
                            ? 'Select Supervisor'
                            : 'Select Specialist',
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Consumer<ClientPro>(
                  builder: (context, provider, _) {
                    final staff = provider.staffList.where((item) {
                      return isSupervisor ? item.role == 1 : item.role == 2;
                    }).toList();
                    return Container(
                      constraints: const BoxConstraints(maxHeight: 360),
                      child: staff.isEmpty
                          ? const Center(
                              child: TextWidget(
                                text: 'No staff available.',
                                fontSize: 14,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: staff.length,
                              separatorBuilder: (_, _) => const Divider(
                                height: 1,
                                color: Color(0xFFF1F5F9),
                              ),
                              itemBuilder: (_, index) {
                                final item = staff[index];
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    radius: 20,
                                    backgroundColor: const Color(0xFFF1F5F9),
                                    child: TextWidget(
                                      text: _initial(item.name),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                  title: TextWidget(
                                    text: item.name,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  trailing: const Icon(
                                    Icons.chevron_right,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  onTap: () async {
                                    final clientPro = context.read<ClientPro>();
                                    final success = isSupervisor
                                        ? await clientPro.assignSupervisor(
                                            clientId: widget.id,
                                            supervisorId: item.id,
                                            showLoader: false,
                                          )
                                        : await clientPro.assignSpecialists(
                                            clientId: widget.id,
                                            specialistIds: [item.id],
                                            showLoader: false,
                                          );
                                    if (!context.mounted) return;
                                    if (success) {
                                      Navigator.pop(dialogContext);
                                      context
                                          .read<CustomerPro>()
                                          .getMyNetworkTabs(
                                            ctx: context,
                                            clientId: widget.id,
                                          );
                                    }
                                  },
                                );
                              },
                            ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _dialogButton({
    required String text,
    bool filled = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          color: filled ? const Color(0xFF22C55E) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: filled ? null : Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: TextWidget(
          text: text,
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: filled ? Colors.white : const Color(0xFF475569),
        ),
      ),
    );
  }

  Future<dynamic> _openRightSideSheet(BuildContext context, Widget child) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "RightSideSheet",
      barrierColor: Colors.black.withValues(alpha: .25),
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, _, _) {
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 420,
              height: MediaQuery.of(context).size.height,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  bottomLeft: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(-4, 0),
                  ),
                ],
              ),
              child: child,
            ),
          ),
        );
      },
      transitionBuilder: (_, anim, _, child) {
        return SlideTransition(
          position: Tween(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
    );
  }
}

class _AssignSpecialistsDialogWidget extends StatefulWidget {
  final int clientId;
  final List<dynamic> currentSpecialists;
  final VoidCallback onUpdate;

  const _AssignSpecialistsDialogWidget({
    required this.clientId,
    required this.currentSpecialists,
    required this.onUpdate,
  });

  @override
  State<_AssignSpecialistsDialogWidget> createState() =>
      _AssignSpecialistsDialogWidgetState();
}

class _AssignSpecialistsDialogWidgetState
    extends State<_AssignSpecialistsDialogWidget> {
  bool _isExpanded = false;
  bool _isLoading = false;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();
  List<StaffModel> _selected = [];

  @override
  void initState() {
    super.initState();
    _selected = widget.currentSpecialists
        .map((item) {
          final map = item is Map ? item : (item as dynamic).toJson();
          final id = map['id'] ?? map['user_id'] ?? 0;
          final firstName = map['first_name'] ?? '';
          final lastName = map['last_name'] ?? '';
          final name =
              map['name'] ??
              (firstName.toString().isEmpty
                  ? 'Unknown'
                  : '$firstName $lastName'.trim());
          return StaffModel(
            id: int.tryParse(id.toString()) ?? 0,
            name: name,
            role: 2,
          );
        })
        .where((staff) => staff.id != 0)
        .toList();

    _fetchStaff();
  }

  Future<void> _fetchStaff() async {
    final clientPro = context.read<ClientPro>();
    if (clientPro.staffList.isEmpty) {
      setState(() => _isLoading = true);
      await clientPro.fetchStaff(showLoader: false);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 580,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const TextWidget(
                            text: 'Assign Specialists',
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                          const SizedBox(height: 4),
                          const TextWidget(
                            text:
                                'Select one or more specialists for this client.',
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(
                        Icons.close,
                        color: Color(0xFF94A3B8),
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TextWidget(
                      text: 'Assign Specialist Members',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF94A3B8),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isExpanded = !_isExpanded;
                        });
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _selected.isEmpty
                                  ? const TextWidget(
                                      text: 'Select specialists...',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF94A3B8),
                                    )
                                  : Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: _selected.map((staff) {
                                        String displayName = staff.name;
                                        if (displayName.length > 12) {
                                          displayName =
                                              '${displayName.substring(0, 12)}...';
                                        }
                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              TextWidget(
                                                text: displayName,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFF000000),
                                              ),
                                              const SizedBox(width: 6),
                                              GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    _selected.removeWhere(
                                                      (s) => s.id == staff.id,
                                                    );
                                                  });
                                                },
                                                child: const ImageWidget(
                                                  image: Paths.delete,
                                                  width: 16,
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
                              color: const Color(0xFF475569),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_isExpanded) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _searchCtrl,
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val.toLowerCase();
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search specialist members...',
                          hintStyle: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(
                              color: Color(0xFF22C55E),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Consumer<ClientPro>(
                        builder: (context, provider, _) {
                          final staffList = provider.staffList
                              .where(
                                (item) =>
                                    item.role == 2 &&
                                    item.name.toLowerCase().contains(
                                      _searchQuery,
                                    ),
                              )
                              .toList();
                          if (_isLoading) {
                            return Container(
                              constraints: const BoxConstraints(minHeight: 100),
                              alignment: Alignment.center,
                              child: const CircularProgressIndicator(
                                color: Color(0xFF22C55E),
                              ),
                            );
                          }

                          return Container(
                            constraints: const BoxConstraints(maxHeight: 220),
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: staffList.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (_, index) {
                                final item = staffList[index];
                                final isSelected = _selected.any(
                                  (s) => s.id == item.id,
                                );
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      if (isSelected) {
                                        _selected.removeWhere(
                                          (s) => s.id == item.id,
                                        );
                                      } else {
                                        _selected.add(item);
                                      }
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFFDCFCE7)
                                          : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFF22C55E)
                                            : Colors.transparent,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        TextWidget(
                                          text: item.name,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF1E293B),
                                        ),
                                        if (isSelected)
                                          const Icon(
                                            Icons.check_circle,
                                            color: Color(0xFF22C55E),
                                            size: 18,
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const TextWidget(
                          text: 'Cancel',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () async {
                        final success = await context
                            .read<ClientPro>()
                            .assignSpecialists(
                              clientId: widget.clientId,
                              specialistIds: _selected
                                  .map((item) => item.id)
                                  .toList(),
                              showLoader: false,
                            );
                        if (!context.mounted) return;
                        if (success) {
                          Navigator.pop(context);
                          widget.onUpdate();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const TextWidget(
                          text: 'Update Specialists',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
