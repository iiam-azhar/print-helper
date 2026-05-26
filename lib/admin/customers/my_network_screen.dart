import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_pro.dart';
import '../../providers/client_pro.dart';
import '../../constants/paths.dart';
import '../../providers/cust_pro.dart';
import '../../providers/admin_pro.dart';
import '../../constants/colors.dart';
import '../../providers/setting_pro.dart';
import '../../models/settings_models.dart';
import '../../models/customer_models.dart';
import '../../models/client_models.dart' hide ContactModel;
import '../../widgets/image_widget.dart';
import '../../widgets/loaders.dart';
import '../../widgets/text_widget.dart';
import '../../widgets/toasts.dart';
import '../../widgets/field_widget.dart';
import '../../utils/regx.dart';
import '../../utils/formatter.dart';
import 'add_customer.dart';
import '../../widgets/spacers.dart';
import '../../widgets/custom_button.dart';
import '../../models/accounts_models.dart' hide ContactModel;
import '../../models/contact_form_models.dart';
import '../../models/client_info_tabs_model.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/download_service.dart';

class MyNetworkScreen extends StatefulWidget {
  final bool isFromAdmin;
  final bool isFromStaff;
  final bool isFromClient;
  final int id;

  const MyNetworkScreen({
    super.key,
    required this.isFromAdmin,
    required this.isFromStaff,
    required this.isFromClient,
    required this.id,
  });

  @override
  State<MyNetworkScreen> createState() => _MyNetworkScreenState();
}

class _MyNetworkScreenState extends State<MyNetworkScreen> {
  int _activeTab = 0;
  final TextEditingController _searchCtrl = TextEditingController();
  final Set<String> _expandedCustomers = <String>{};
  int? _selectedCompanyType;
  int?
  _selectedStatus; // Set to null initially to ensure customers are listed regardless of status mapping
  Timer? _debounce;
  bool _hasSearched = false;

  Color _hexToColor(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    final intVal = int.tryParse(buffer.toString(), radix: 16);
    return intVal != null ? Color(intVal) : Colors.black;
  }

  Color _getSidebarColor(BuildContext context) {
    try {
      final authPro = Provider.of<AuthPro>(context, listen: false);
      final custPro = Provider.of<CustomerPro>(context, listen: false);
      final clPro = Provider.of<ClientPro>(context, listen: false);

      final role = authPro.user?.roleName;
      final isCustomer = role == "CUSTOMER";
      final isContact = role == "CONTACT"; // Client

      if (isCustomer || isContact) {
        String? primaryHex = custPro.client?.brandingPrimaryColor;
        if (primaryHex == null || primaryHex.isEmpty) {
          primaryHex = clPro.selectedClient?.primaryColor;
        }

        if (primaryHex != null && primaryHex.isNotEmpty) {
          return _hexToColor(primaryHex);
        }
        return Colors.black;
      }
    } catch (e) {
      debugPrint("Error getting sidebar color: $e");
    }
    return const Color(0xFFEAB308); // Default yellow
  }

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
      // Perform initial search to populate the list if needed, or rely on tabs
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

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
              children: [
                _topBar(clientName, isActive, companyLogo),
                Expanded(
                  child: Container(
                    color: const Color(0xFFF3F4F7),
                    child: provider.myNetworkLoad
                        ? Center(child: showLoader())
                        : RefreshIndicator(
                            onRefresh: () => provider.getMyNetworkTabs(
                              ctx: context,
                              clientId: widget.id,
                            ),
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.fromLTRB(
                                12.w,
                                12.h,
                                12.w,
                                20.h,
                              ),
                              children: [
                                _cardShell(
                                  child: Column(
                                    children: [
                                      _tabsHeader(),
                                      Padding(
                                        padding: EdgeInsets.fromLTRB(
                                          12.w,
                                          12.h,
                                          12.w,
                                          14.h,
                                        ),
                                        child: [
                                          _customersTab(data, clientName),
                                          _assignedTeamTab(data),
                                          _internalOpsTab(data),
                                        ][_activeTab],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
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
      height: 68.h,
      padding: EdgeInsets.symmetric(horizontal: 10.w),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 14,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20.sp,
              color: Colors.black,
            ),
          ),
          SizedBox(width: 4.w),
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade200, width: 1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(50.r),
              child:
                  companyLogo.isNotEmpty && companyLogo.toLowerCase() != 'null'
                  ? ImageWidget(
                      image: companyLogo,
                      width: 34,
                      height: 34,
                      fit: BoxFit.cover,
                    )
                  : ImageWidget(
                      image: Paths.user,
                      width: 34,
                      height: 34,
                      fit: BoxFit.cover,
                    ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: TextWidget(
              text: clientName,
              fontWeight: FontWeight.w700,
              fontSize: 19,
              color: Colors.black,
              maxLines: 1,
            ),
          ),
          if (isAdminOrStaff)
            GestureDetector(
              onTap: () =>
                  _showToggleClientStatusDialog(context, clientName, isActive),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(
                    color: isActive
                        ? const Color(0xFFF87171)
                        : const Color(0xFF34D399),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isActive ? Icons.block : Icons.check_circle_outline,
                      size: 14,
                      color: isActive
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF10B981),
                    ),
                    const SizedBox(width: 6),
                    TextWidget(
                      text: isActive ? 'Deactivate' : 'Activate',
                      fontSize: 12,
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

  Widget _cardShell({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: child,
    );
  }

  Widget _tabsHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 10.h),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (int i = 0; i < _tabs.length; i++) ...[
              _tabChip(_tabs[i], i),
              if (i != _tabs.length - 1) SizedBox(width: 8.w),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tabChip(String label, int index) {
    final active = _activeTab == index;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = index),
      child: Container(
        height: 38.h,
        constraints: BoxConstraints(minWidth: 102.w),
        padding: EdgeInsets.symmetric(horizontal: 14.w),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? Colors.white : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(19.r),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: TextWidget(
          text: label,
          fontSize: 13,
          fontWeight: active ? FontWeight.w700 : FontWeight.w600,
          color: const Color(0xFF475569),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
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

  Widget _customersTab(Map<String, dynamic> data, String clientName) {
    final pro = context.read<AdminPro>();
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
        ? allCustomers // If server searched, we assume it's already filtered
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
          children: [
            Expanded(
              child: TextWidget(
                text:
                    'End customers of $clientName. Admin can add, edit, and delete on behalf of the client.',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
              ),
            ),
            SizedBox(width: 8.w),
            _greenButton(
              '+ Customer',
              onTap: () async {
                final res = await showModalBottomSheet<bool>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  barrierColor: Colors.black.withValues(alpha: .25),
                  builder: (_) => FractionallySizedBox(
                    heightFactor: .98,
                    child: AddCustomer(
                      clientId: widget.id,
                      isFromClient: widget.isFromClient,
                    ),
                  ),
                );
                if (res == true && context.mounted) {
                  context.read<CustomerPro>().getMyNetworkTabs(
                    ctx: context,
                    clientId: widget.id,
                  );
                }
              },
            ),
          ],
        ),
        _searchField(onChanged: _onSearchChanged),
        SizedBox(height: 10.h),
        Row(
          children: [
            Expanded(
              child: _filterDropdown<int>(
                label: 'All Types',
                value: _selectedCompanyType,
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: TextWidget(
                      text: 'All Types',
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  ...companyTypes.map(
                    (e) => DropdownMenuItem(
                      value: e.id,
                      child: TextWidget(
                        text: e.name,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
                onChanged: (v) {
                  setState(() => _selectedCompanyType = v);
                  _performSearch();
                },
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: _filterDropdown<int>(
                label: 'Status',
                value: _selectedStatus,
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: TextWidget(
                      text: 'All Status',
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 1,
                    child: TextWidget(
                      text: 'Active',
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 0,
                    child: TextWidget(
                      text: 'Inactive',
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
                onChanged: (v) {
                  setState(() => _selectedStatus = v);
                  _performSearch();
                },
              ),
            ),
            SizedBox(width: 8.w),
            _roundIcon(
              Icons.refresh,
              onTap: () {
                setState(() {
                  _selectedCompanyType = null;
                  _selectedStatus = null;
                  _searchCtrl.clear();
                  _hasSearched = false;
                });
                context.read<CustomerPro>().getMyNetworkTabs(
                  ctx: context,
                  clientId: widget.id,
                );
              },
            ),
            SizedBox(width: 8.w),
            _pageDot(customers.length.toString()),
          ],
        ),
        SizedBox(height: 12.h),
        if (customers.isEmpty)
          _emptyCard('No customers found.')
        else
          ...List.generate(customers.length, (index) {
            final item = customers[index];
            final map = _asMap(item);
            final customerKey = _pickString(
              map,
              const ['id', 'customer_id', 'uuid'],
              fallback:
                  '${_pickString(map, const ['company_name', 'name'], fallback: 'customer')}-$index',
            );
            final isExpanded = _expandedCustomers.contains(customerKey);

            return Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: _customerRowCard(
                item: item,
                isExpanded: isExpanded,
                onToggle: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedCustomers.remove(customerKey);
                    } else {
                      _expandedCustomers.add(customerKey);
                    }
                  });
                },
              ),
            );
          }),
      ],
    );
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

  Widget _assignedTeamTab(Map<String, dynamic> rootData) {
    // Handle new nested structure: data.tabs.assigned_team
    final tabs = _asMap(rootData['tabs']);
    final data = tabs.containsKey('assigned_team')
        ? _asMap(tabs['assigned_team'])
        : rootData;

    final contactDataRaw = data['contactData'] ?? data['contact_data'];
    final contactData = _asMap(contactDataRaw);
    final specialistsRaw = _asList(data['assigned_specialists']);
    final supervisorsRaw = _asList(data['supervisor']);

    final allStaff = (specialistsRaw.isNotEmpty || supervisorsRaw.isNotEmpty)
        ? [...specialistsRaw, ...supervisorsRaw]
        : _asList(contactData['assigned_staff']);

    // Find supervisor: from dedicated list, from root, or from contactData
    var supervisorRaw = supervisorsRaw.isNotEmpty
        ? supervisorsRaw.first
        : (data['supervisor'] ?? contactData['supervisor']);

    if (supervisorRaw is List && supervisorRaw.isNotEmpty) {
      supervisorRaw = supervisorRaw.first;
    }

    if (supervisorRaw == null || _asMap(supervisorRaw).isEmpty) {
      supervisorRaw = allStaff.firstWhere((s) {
        final m = _asMap(s);
        final desc = _pickString(m, ['designation']).toLowerCase();
        final role = _pickInt(m, ['role']);
        return desc.contains('supervisor') || role == 1;
      }, orElse: () => null);
    }

    final supervisor = _asMap(supervisorRaw);
    final supervisorId = _pickInt(supervisor, ['id', 'user_id']);

    // Specialists are everyone else in assigned_staff
    final specialists = allStaff.where((s) {
      final id = _pickInt(_asMap(s), ['id', 'user_id']);
      return id != supervisorId;
    }).toList();

    final contactNumbers = _asList(contactData['contact_numbers']);
    final assignedStaff = _asList(contactData['assigned_staff']);
    final supportLines = _asList(contactData['support_lines']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final horizontal = constraints.maxWidth >= 980;
            final specialistsCard = _groupCard(
              title: 'ASSIGNED SPECIALISTS',
              child: Column(
                children: [
                  if (specialists.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: TextWidget(
                        text: 'No specialists assigned.',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    )
                  else
                    ...List.generate(specialists.length, (index) {
                      return Column(
                        children: [
                          _specialistRow(specialists[index]),
                          if (index < specialists.length - 1) ...[
                            SizedBox(height: 10.h),
                            const Divider(color: Color(0xFFE5E7EB), height: 1),
                            SizedBox(height: 10.h),
                          ],
                        ],
                      );
                    }),
                  if (widget.isFromAdmin) ...[
                    SizedBox(height: 14.h),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _outlineButton(
                        '+ Assign Specialist',
                        onTap: () =>
                            _showAssignSpecialistsDialog(context, specialists),
                      ),
                    ),
                  ],
                ],
              ),
            );

            final supervisorCard = _groupCard(
              title: 'SUPERVISOR',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (supervisor.isEmpty)
                    const TextWidget(
                      text: 'No supervisor assigned.',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    )
                  else
                    _supervisorRow(supervisor),
                  if (supervisor.isEmpty && widget.isFromAdmin) ...[
                    SizedBox(height: 12.h),
                    _outlineButton(
                      '+ Assign Supervisor',
                      onTap: () =>
                          _showStaffSelection(context, isSupervisor: true),
                    ),
                  ],
                ],
              ),
            );

            if (!horizontal) {
              return Column(
                children: [
                  specialistsCard,
                  SizedBox(height: 12.h),
                  supervisorCard,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: specialistsCard),
                SizedBox(width: 12.w),
                Expanded(flex: 4, child: supervisorCard),
              ],
            );
          },
        ),
        SizedBox(height: 12.h),
        _supportLinesSection(
          contactNumbers: contactNumbers,
          assignedStaff: assignedStaff,
          supportLines: supportLines,
        ),
      ],
    );
  }

  Widget _supervisorRow(Map<String, dynamic> map) {
    final title = _fullName(map);
    final image = _pickString(map, ['image', 'avatar', 'photo']);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 22.r,
          backgroundColor: const Color(0xFFF5F3FF),
          child: ClipOval(
            child: image.isNotEmpty && image.toLowerCase() != 'null'
                ? ImageWidget(
                    image: image,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                  )
                : TextWidget(
                    text: _initial(title),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF7C3AED),
                  ),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextWidget(
                text: title,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4.h),
              const TextWidget(
                text: 'Supervisor',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ],
          ),
        ),
        if (widget.isFromAdmin) ...[
          SizedBox(width: 12.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: const Color(0xFFF3E8FF),
              borderRadius: BorderRadius.circular(99),
            ),
            child: const TextWidget(
              text: 'Supervisor',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF9333EA),
            ),
          ),
          SizedBox(width: 8.w),
          GestureDetector(
            onTap: () => _showStaffSelection(context, isSupervisor: true),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: const Color(0xFFD1D5DB)),
              ),
              child: const TextWidget(
                text: 'Change',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
          ),
        ] else ...[
          SizedBox(width: 12.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: const Color(0xFFF3E8FF),
              borderRadius: BorderRadius.circular(99),
            ),
            child: const TextWidget(
              text: 'Supervisor',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF9333EA),
            ),
          ),
        ],
      ],
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
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: TextWidget(
            text: 'PH PORTAL SUPPORT LINES',
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
        SizedBox(height: 8.h),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: TextWidget(
            text: 'Lines assigned to this client. Managed in Settings.',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
        ),
        SizedBox(height: 16.h),
        if (supportLines.isEmpty &&
            contactNumbers.isEmpty &&
            assignedStaff.isEmpty)
          _emptyCard('No support lines found.')
        else ...[
          // Structured support lines
          ...supportLines.map((item) {
            final m = _asMap(item);
            final phone = _pickString(m, ['phone_number']);
            final client = _asMap(m['client']);
            final staff = _asList(m['assigned_staff']);
            final contacts = _asList(m['contact_numbers']);

            final groupItems = <Map<String, dynamic>>[];
            if (client.isNotEmpty) {
              groupItems.add({
                'name': _pickString(client, ['company_name']),
                'designation': 'Client',
                'image': _pickString(client, ['image']),
                'phone': phone,
                'show_phone': true,
              });
            }
            for (final s in staff) {
              final sMap = _asMap(s);
              groupItems.add({
                'name': _pickString(sMap, ['name']),
                'designation': _pickString(sMap, [
                  'designation',
                ], fallback: 'Staff'),
                'image': _pickString(sMap, ['image']),
                'show_phone': false,
              });
            }
            for (final c in contacts) {
              final cMap = _asMap(c);
              groupItems.add({
                'name': _pickString(cMap, ['name']),
                'designation': 'Client Contact',
                'image': _pickString(cMap, ['image']),
                'show_phone': false,
              });
            }

            return Padding(
              padding: EdgeInsets.only(bottom: 16.h),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  children: List.generate(groupItems.length, (index) {
                    final gItem = groupItems[index];
                    return Column(
                      children: [
                        _supportLineRow(gItem),
                        if (index < groupItems.length - 1)
                          const Divider(color: Color(0xFFF1F5F9), height: 1),
                      ],
                    );
                  }),
                ),
              ),
            );
          }),

          // Legacy flat support staff (if any)
          if (supportLines.isEmpty &&
              (contactNumbers.isNotEmpty || assignedStaff.isNotEmpty))
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                children:
                    [
                          ...contactNumbers.map(
                            (c) => _supportLineRow({
                              ..._asMap(c),
                              'designation': 'Client Contact',
                              'show_phone': true,
                            }),
                          ),
                          ...assignedStaff.map((s) => _supportLineRow(s)),
                        ]
                        .map(
                          (row) => Column(
                            children: [
                              row,
                              const Divider(
                                height: 1,
                                color: Color(0xFFF1F5F9),
                              ),
                            ],
                          ),
                        )
                        .toList(),
              ),
            ),
        ],
      ],
    );
  }

  Widget _supportLineRow(dynamic item) {
    final map = _asMap(item);
    final title = _fullName(map);
    final subtitle = _pickString(map, [
      'designation',
      'role_name',
    ], fallback: 'Specialist');
    final image = _pickString(map, ['image', 'avatar', 'photo']);
    final phone = _pickString(map, [
      'phone',
      'contact_number',
    ], fallback: '---');

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20.r,
            backgroundColor: const Color(0xFFE5E7EB),
            child: ClipOval(
              child: image.isNotEmpty && image.toLowerCase() != 'null'
                  ? ImageWidget(
                      image: image,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    )
                  : TextWidget(
                      text: _initial(title),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF64748B),
                    ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextWidget(
                  text: title,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                TextWidget(
                  text: subtitle,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                ),
              ],
            ),
          ),
          if (map['show_phone'] != false)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: TextWidget(
                text: phone,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1F2937),
              ),
            ),
        ],
      ),
    );
  }

  Widget _internalOpsTab(Map<String, dynamic> rootData) {
    final tabs = _asMap(rootData['tabs']);
    final internalOps = _asMap(tabs['internal_ops']);
    final assignedTeam = _asMap(tabs['assigned_team']);
    final contactData = _asMap(
      assignedTeam['contact_data'] ?? assignedTeam['contactData'],
    );

    final supportLines = _asList(contactData['support_lines']);
    final contactNumbers = _asList(contactData['contact_numbers']);
    final assignedStaff = _asList(contactData['assigned_staff']);

    final contacts = _asList(internalOps['contacts']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: TextWidget(
                text:
                    'Main contact can manage all contacts. Additional contacts are view-only except their own settings.',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
            SizedBox(width: 10.w),
            _greenButton(
              '+ Add Contact',
              onTap: () async {
                final res = await _showEditContactBottomSheet(context, {});
                if (res == true && mounted) {
                  context.read<CustomerPro>().getMyNetworkTabs(
                    ctx: context,
                    clientId: widget.id,
                  );
                }
              },
            ),
          ],
        ),
        SizedBox(height: 14.h),
        if (contacts.isEmpty)
          _emptyCard('No internal contacts found.')
        else ...[
          _mainContactCard(contacts.first),
          ...List.generate(contacts.length - 1, (index) {
            final contact = contacts[index + 1];
            return Padding(
              padding: EdgeInsets.only(top: 12.h),
              child: _contactCard(
                _asMap(contact),
                showMain: true,
                customerId: null,
              ),
            );
          }),
        ],
        SizedBox(height: 24.h),
        const Divider(color: Color(0xFFDFE6EE), height: 1),
        SizedBox(height: 24.h),
        const TextWidget(
          text: 'AGREEMENT & STANDARDS',
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: Color(0xFF111827),
          letterSpacing: 1.5,
        ),
        SizedBox(height: 12.h),
        _agreementSection(
          rootData,
          _clientName(context.read<CustomerPro>(), rootData),
        ),
      ],
    );
  }

  Widget _searchField({ValueChanged<String>? onChanged}) {
    return Container(
      height: 42.h,
      padding: EdgeInsets.symmetric(horizontal: 10.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 20, color: Color(0xFF94A3B8)),
          SizedBox(width: 8.w),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: onChanged,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: 'Search customers...',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _greenButton(String text, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: const Color(0xFF22C55E),
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: TextWidget(
          text: text,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _outlineButton(String text, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: const Color(0xFFD1D5DB)),
        ),
        child: TextWidget(
          text: text,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF334155),
        ),
      ),
    );
  }

  Widget _roundIcon(IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34.w,
        height: 34.w,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFD1D5DB)),
        ),
        child: Icon(icon, size: 18, color: const Color(0xFF64748B)),
      ),
    );
  }

  Widget _filterDropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      height: 38.h,
      padding: EdgeInsets.symmetric(horizontal: 10.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFD1D5DB)),
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
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF64748B),
          ),
          items: items,
          onChanged: onChanged,
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
        ),
      ),
    );
  }

  Widget _pageDot(String text) {
    return Container(
      width: 34.w,
      height: 34.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      child: TextWidget(text: text, fontSize: 12, fontWeight: FontWeight.w600),
    );
  }

  Widget _groupCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextWidget(
            text: title,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF64748B),
          ),
          SizedBox(height: 8.h),
          Container(height: 1, color: const Color(0xFFE5E7EB)),
          SizedBox(height: 12.h),
          child,
        ],
      ),
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
    final date = _prettyDateTime(dateRaw);
    final contacts = _asList(
      map['contacts'] ?? map['customer_contacts'] ?? map['contact_data'],
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (subtype != 'Personal') ...[
                CircleAvatar(
                  radius: 22.r,
                  backgroundColor: const Color(0xFFE5E7EB),
                  child: ClipOval(
                    child: ImageWidget(
                      image: _safeImage(image),
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextWidget(
                      text: title,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 3.h),
                    TextWidget(
                      text: subtype,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF9CA3AF),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (date.isNotEmpty) ...[
                      SizedBox(height: 2.h),
                      TextWidget(
                        text: date,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF9CA3AF),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 42.w,
                    height: 24.h,
                    child: Transform.scale(
                      scale: 0.86,
                      child: Switch(
                        value: true,
                        onChanged: (_) {},
                        activeTrackColor: const Color(0xFF10B981),
                        activeThumbColor: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  GestureDetector(
                    onTap: () {
                      _showDeleteCustomerDialog(context, map);
                    },
                    child: Container(
                      width: 34.w,
                      height: 34.w,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE4E6),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(8.w),
                        child: ImageWidget(
                          image: Paths.delete,
                          color: const Color(0xFFEF4444),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Row(
            children: [
              Expanded(
                child: TextWidget(
                  text: '$projects Projects  •  $files Files',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF4B5563),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 6.w),
              GestureDetector(
                onTap: onToggle,
                child: Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          if (isExpanded) ...[
            SizedBox(height: 12.h),
            Container(height: 1, color: const Color(0xFFE5E7EB)),
            SizedBox(height: 12.h),
            _expandedContactsArea(
              contacts,
              customerId: _pickInt(map, ['id', 'customer_id']),
              customerMap: map,
            ),
          ],
        ],
      ),
    );
  }

  String _prettyDateTime(String raw) {
    final input = raw.trim();
    if (input.isEmpty) return '';

    final dt = DateTime.tryParse(input);
    if (dt == null) return input;

    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final year = (dt.year % 100).toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final suffix = dt.hour >= 12 ? 'pm' : 'am';

    return '$month/$day/$year • $hour12:$minute$suffix';
  }

  Widget _expandedContactsArea(
    List<dynamic> contacts, {
    int? customerId,
    Map<String, dynamic>? customerMap,
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
        SizedBox(height: 10.h),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > 640;
            final cardWidth = constraints.maxWidth > 340
                ? constraints.maxWidth * 0.86
                : 292.w;
            final contactCard = mainContact.isEmpty
                ? _emptyContactCard()
                : _contactCard(
                    mainContact,
                    customerId: customerId,
                    customerMap: customerMap,
                  );
            final addCard = GestureDetector(
              onTap: () async {
                final res = await _showEditContactBottomSheet(
                  context,
                  {},
                  customer:
                      customerMap ??
                      (mainContact.isNotEmpty ? mainContact : null),
                );
                if (res == true && mounted) {
                  context.read<CustomerPro>().getMyNetworkTabs(
                    ctx: context,
                    clientId: widget.id,
                  );
                }
              },
              child: _addContactCard(),
            );

            if (wide) {
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: contactCard),
                    SizedBox(width: 12.w),
                    Expanded(child: addCard),
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: cardWidth, child: contactCard),
                    SizedBox(width: 10.w),
                    SizedBox(width: cardWidth, child: addCard),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _contactCard(
    Map<String, dynamic> contact, {
    bool showMain = true,
    int? customerId,
    Map<String, dynamic>? customerMap,
  }) {
    final bool isAdminOrStaff = widget.isFromAdmin || widget.isFromStaff;
    final Color sidebarColor = _getSidebarColor(context);
    final name = _fullName(contact);
    final username = _pickString(contact, const [
      'username',
    ], fallback: '@user');
    String email = _pickString(contact, const ['email']);
    if (email.isEmpty) {
      final details = _asMap(contact['contact_details'] ?? {});
      final emailsList = _asList(contact['emails'] ?? details['emails']);
      if (emailsList.isNotEmpty) {
        email = emailsList.first.toString();
      }
    }
    if (email.isEmpty) email = 'No email';

    String phone = _pickString(contact, const [
      'phone',
      'phone_number',
      'mobile',
    ]);
    if (phone.isEmpty) {
      final details = _asMap(contact['contact_details'] ?? {});
      final phonesList = _asList(contact['phones'] ?? details['phones']);
      if (phonesList.isNotEmpty) {
        final firstPhone = _asMap(phonesList.first);
        phone = _pickString(firstPhone, const ['number', 'value', 'phone']);
      }
    }
    if (phone.isEmpty) phone = 'No phone';

    String language = '';
    final langNames = _asList(contact['language_names']);
    if (langNames.isNotEmpty) {
      language = langNames.first.toString();
    } else {
      final details = _asMap(contact['contact_details'] ?? {});
      final langNamesDetails = _asList(details['language_names']);
      if (langNamesDetails.isNotEmpty) {
        language = langNamesDetails.first.toString();
      }
    }

    final isPrimary =
        contact['is_primary'] == true ||
        contact['is_primary'] == 1 ||
        contact['is_primary'] == '1' ||
        contact['is_primary'] == 'true';

    final showYellowBorder = isPrimary;
    final showPill = showMain && isPrimary;

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

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: showYellowBorder
              ? (isAdminOrStaff ? const Color(0xFFEAB308) : sidebarColor)
              : const Color(0xFFE5E7EB),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16.r,
                backgroundColor: showYellowBorder
                    ? (isAdminOrStaff
                          ? const Color(0xFFFACC15)
                          : sidebarColor.withValues(alpha: 0.2))
                    : const Color(0xFFFFEDD5),
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
                          color: const Color(0xFF111827),
                        ),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextWidget(
                      text: name,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
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
              if (showPill)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 3.h,
                  ),
                  decoration: BoxDecoration(
                    color: isAdminOrStaff
                        ? const Color(0xFFFDE68A)
                        : sidebarColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: TextWidget(
                    text: 'Main',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isAdminOrStaff
                        ? const Color(0xFF92400E)
                        : Colors.white,
                  ),
                )
              else if (!isPrimary)
                GestureDetector(
                  onTap: () {
                    // Placeholder for delete action if needed
                  },
                  child: Container(
                    padding: EdgeInsets.all(4.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: ImageWidget(
                      image: Paths.delete,
                      width: 16.sp,
                      height: 16.sp,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Icon(Icons.email, size: 14.sp, color: const Color(0xFFCBD5E1)),
              SizedBox(width: 6.w),
              Expanded(
                child: TextWidget(
                  text: email,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Row(
            children: [
              Icon(Icons.phone, size: 14.sp, color: const Color(0xFFE11D48)),
              SizedBox(width: 6.w),
              Expanded(
                child: TextWidget(
                  text: phone,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          if (language.isNotEmpty) ...[
            SizedBox(height: 6.h),
            Row(
              children: [
                Icon(
                  Icons.g_translate,
                  size: 14.sp,
                  color: const Color(0xFF22C55E),
                ),
                SizedBox(width: 6.w),
                Expanded(
                  child: TextWidget(
                    text: language,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
          if (!isPrimary) ...[
            SizedBox(height: 6.h),
            Row(
              children: [
                Icon(
                  Icons.remove_red_eye,
                  size: 14.sp,
                  color: const Color(0xFF3B82F6),
                ),
                SizedBox(width: 6.w),
                Expanded(
                  child: TextWidget(
                    text: 'View only',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
          SizedBox(height: 10.h),
          Row(
            children: [
              Expanded(
                child: _contactActionChip(
                  icon: Icons.edit_outlined,
                  label: 'Edit',
                  bg: const Color(0xFFF3F4F6),
                  fg: const Color(0xFF475569),
                  compact: true,
                  onTap: () async {
                    final res = await _showEditContactBottomSheet(
                      context,
                      contact,
                      customer: customerMap,
                    );
                    if (res == true && mounted) {
                      context.read<CustomerPro>().getMyNetworkTabs(
                        ctx: context,
                        clientId: widget.id,
                      );
                    }
                  },
                ),
              ),
              SizedBox(width: 6.w),
              Expanded(
                child: _contactActionChip(
                  icon: Icons.key_outlined,
                  label: 'Reset PW',
                  bg: const Color(0xFFF3F4F6),
                  fg: const Color(0xFF475569),
                  compact: true,
                  onTap: () => _showResetPasswordDialog(context, contact),
                ),
              ),
              if (widget.isFromAdmin) ...[
                SizedBox(width: 6.w),
                Expanded(
                  child: _contactActionChip(
                    icon: Icons.login_rounded,
                    label: 'Login',
                    bg: const Color(0xFF22C55E),
                    fg: Colors.white,
                    compact: true,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyContactCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFEAB308), width: 1.2),
      ),
      child: const TextWidget(
        text: 'No contacts found.',
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: Color(0xFF64748B),
      ),
    );
  }

  Widget _addContactCard() {
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: const Color(0xFFD1D5DB),
        radius: 12.r,
      ),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12.r)),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.person_add_alt_1_outlined, color: Color(0xFF9CA3AF)),
              SizedBox(height: 8),
              TextWidget(
                text: 'Add Contact',
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contactActionChip({
    required IconData icon,
    required String label,
    required Color bg,
    required Color fg,
    bool compact = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8.w : 12.w,
          vertical: compact ? 7.h : 8.h,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: compact ? 12 : 14, color: fg),
            SizedBox(width: compact ? 4.w : 5.w),
            Flexible(
              child: TextWidget(
                text: label,
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w600,
                color: fg,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _initial(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'C';
    return trimmed.characters.first.toUpperCase();
  }

  Widget _specialistRow(dynamic item) {
    final map = _asMap(item);
    final title = _fullName(map);
    final subtitle = _pickString(map, ['designation', 'role_name']).isNotEmpty
        ? _pickString(map, ['designation', 'role_name'])
        : (_pickInt(map, ['role']) == 1 ? 'Supervisor' : 'Specialist');
    final rawImage = _pickString(map, [
      'image_url',
      'image',
      'avatar',
      'photo',
    ]);
    final image = rawImage.startsWith('http') ? rawImage : '';

    return Row(
      children: [
        CircleAvatar(
          radius: 22.r,
          backgroundColor: const Color(0xFFE2E8F0),
          child: ClipOval(
            child: image.isNotEmpty && image.toLowerCase() != 'null'
                ? ImageWidget(
                    image: image,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                  )
                : TextWidget(
                    text: _initial(title),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF64748B),
                  ),
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextWidget(
                text: title,
                fontSize: 15,
                fontWeight: FontWeight.w700,
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
        if (widget.isFromAdmin)
          GestureDetector(
            onTap: () async {
              final staffId = _pickInt(map, ['id', 'user_id']);
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
            },
            child: Container(
              width: 34.w,
              height: 34.w,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFCA5A5), width: 1.w),
              ),
              child: Center(
                child: ImageWidget(
                  image: Paths.delete,
                  width: 15,
                  color: const Color(0xFFEF4444),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _mainContactCard(dynamic item) {
    final bool isAdminOrStaff = widget.isFromAdmin || widget.isFromStaff;
    final Color sidebarColor = _getSidebarColor(context);
    final map = _asMap(item);
    final title = _fullName(map);
    final username = _pickString(map, ['username'], fallback: '@user');

    String email = _pickString(map, ['email']);
    if (email.isEmpty) {
      final details = _asMap(map['contact_details'] ?? {});
      final emailsList = _asList(map['emails'] ?? details['emails']);
      if (emailsList.isNotEmpty) {
        email = emailsList.first.toString();
      }
    }
    if (email.isEmpty) email = 'No email';

    String phone = _pickString(map, const ['phone', 'phone_number', 'mobile']);
    if (phone.isEmpty) {
      final details = _asMap(map['contact_details'] ?? {});
      final phonesList = _asList(map['phones'] ?? details['phones']);
      if (phonesList.isNotEmpty) {
        final firstPhone = _asMap(phonesList.first);
        phone = _pickString(firstPhone, const ['number', 'value', 'phone']);
      }
    }
    if (phone.isEmpty) phone = 'No phone';

    String language = '';
    final langNames = _asList(map['language_names']);
    if (langNames.isNotEmpty) {
      language = langNames.first.toString();
    } else {
      final details = _asMap(map['contact_details'] ?? {});
      final langNamesDetails = _asList(details['language_names']);
      if (langNamesDetails.isNotEmpty) {
        language = langNamesDetails.first.toString();
      }
    }

    final isPrimary =
        map['is_primary'] == true ||
        map['is_primary'] == 1 ||
        map['is_primary'] == '1' ||
        map['is_primary'] == 'true';

    final rawImage = _pickString(map, [
      'image_url',
      'image',
      'avatar',
      'photo',
    ]);
    final image = rawImage.startsWith('http') ? rawImage : '';

    String displayUsername = username;
    if (displayUsername.isNotEmpty && !displayUsername.startsWith('@')) {
      displayUsername = '@$displayUsername';
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isPrimary
              ? (isAdminOrStaff ? const Color(0xFFEAB308) : sidebarColor)
              : const Color(0xFFE5E7EB),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22.r,
                backgroundColor: isPrimary
                    ? (isAdminOrStaff
                          ? const Color(0xFFFACC15)
                          : sidebarColor.withValues(alpha: 0.2))
                    : const Color(0xFFFFEDD5),
                child: ClipOval(
                  child: image.isNotEmpty && image.toLowerCase() != 'null'
                      ? ImageWidget(
                          image: image,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                        )
                      : TextWidget(
                          text: _initial(title),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF111827),
                        ),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextWidget(
                      text: title,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
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
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 3.h,
                  ),
                  decoration: BoxDecoration(
                    color: isAdminOrStaff
                        ? const Color(0xFFFDE68A)
                        : sidebarColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: TextWidget(
                    text: 'Main',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isAdminOrStaff
                        ? const Color(0xFF92400E)
                        : Colors.white,
                  ),
                ),
            ],
          ),
          SizedBox(height: 12.h),
          Container(height: 1, color: const Color(0xFFE5E7EB)),
          SizedBox(height: 12.h),
          Row(
            children: [
              Icon(Icons.email, size: 14.sp, color: const Color(0xFFCBD5E1)),
              SizedBox(width: 6.w),
              Expanded(
                child: TextWidget(
                  text: email,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Row(
            children: [
              Icon(Icons.phone, size: 14.sp, color: const Color(0xFFE11D48)),
              SizedBox(width: 6.w),
              Expanded(
                child: TextWidget(
                  text: phone,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          if (language.isNotEmpty) ...[
            SizedBox(height: 6.h),
            Row(
              children: [
                Icon(
                  Icons.g_translate,
                  size: 14.sp,
                  color: const Color(0xFF22C55E),
                ),
                SizedBox(width: 6.w),
                Expanded(
                  child: TextWidget(
                    text: language,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: _miniAction(
                  icon: Icons.edit_outlined,
                  label: 'Edit',
                  onTap: () async {
                    final res = await _showEditContactBottomSheet(
                      context,
                      map,
                      customer: map,
                    );
                    if (res == true && mounted) {
                      context.read<CustomerPro>().getMyNetworkTabs(
                        ctx: context,
                        clientId: widget.id,
                      );
                    }
                  },
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _miniAction(
                  icon: Icons.key_outlined,
                  label: 'Reset PW',
                  onTap: () => _showResetPasswordDialog(context, map),
                ),
              ),
              if (widget.isFromAdmin) ...[
                SizedBox(width: 8.w),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 4.w,
                      vertical: 8.h,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(
                          Icons.login_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                        SizedBox(width: 6),
                        TextWidget(
                          text: 'Login',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniAction({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: const Color(0xFF475569)),
            SizedBox(width: 5.w),
            TextWidget(
              text: label,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
          ],
        ),
      ),
    );
  }

  void _showResetPasswordDialog(
    BuildContext context,
    Map<String, dynamic> contact,
  ) {
    final name = _fullName(contact);
    final contactId = _pickInt(contact, ['id', 'user_id']);
    final passCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    final formKey = GlobalKey<FormState>();
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(20.w),
            child: StatefulBuilder(
              builder: (context, setState) {
                return Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const TextWidget(
                                text: 'Reset Password',
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                              TextWidget(
                                text: name,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF94A3B8),
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: const Icon(Icons.close, color: Colors.black),
                          ),
                        ],
                      ),
                      SizedBox(height: 10.h),
                      Container(height: 1, color: const Color(0xFFF1F5F9)),
                      SizedBox(height: 10.h),
                      _dialogField(
                        controller: passCtrl,
                        label: "New Password",
                        hint: 'Enter new password',
                        obscure: obscureNew,
                        suffixIcon: GestureDetector(
                          onTap: () => setState(() => obscureNew = !obscureNew),
                          child: Icon(
                            obscureNew
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 20.sp,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                        regExpCondition: Regx.passwordRegExp,
                        errorText: "Required",
                        regErrorText: "Invalid Password Format",
                      ),
                      SizedBox(height: 5.h),
                      _dialogField(
                        controller: confirmCtrl,
                        label: "Confirm Password",
                        hint: 'Confirm password',
                        obscure: obscureConfirm,
                        suffixIcon: GestureDetector(
                          onTap: () =>
                              setState(() => obscureConfirm = !obscureConfirm),
                          child: Icon(
                            obscureConfirm
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 20.sp,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                        regExpCondition: Regx.passwordRegExp,
                        errorText: "Required",
                        regErrorText: "Invalid Password Format",
                      ),
                      SizedBox(height: 24.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _outlineButton(
                            'Cancel',
                            onTap: () => Navigator.pop(context),
                          ),
                          SizedBox(width: 12.w),
                          GestureDetector(
                            onTap: () async {
                              if (!(formKey.currentState?.validate() ??
                                  false)) {
                                return;
                              }
                              if (passCtrl.text.trim() !=
                                  confirmCtrl.text.trim()) {
                                showToast(message: "Passwords do not match");
                                return;
                              }

                              final success = await context
                                  .read<ClientPro>()
                                  .resetContactPassword(
                                    ctx: context,
                                    contactId: contactId,
                                    password: passCtrl.text.trim(),
                                    passwordConfirmation: confirmCtrl.text
                                        .trim(),
                                  );

                              if (success && mounted) {
                                Navigator.pop(context);
                              }
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16.w,
                                vertical: 10.h,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF22C55E),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.check,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 8.w),
                                  const TextWidget(
                                    text: 'Update Password',
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
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _dialogField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool obscure = false,
    Widget? suffixIcon,
    required RegExp regExpCondition,
    String? errorText,
    String? regErrorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextWidget(
          text: label,
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: const Color(0xFF1E293B),
        ),
        SizedBox(height: 6.h),
        CustomTextField(
          controller: controller,
          obscureText: obscure,
          passField: true,
          hintText: hint,
          suffixIcon: suffixIcon,
          regExpCondition: regExpCondition,
          errorText: errorText,
          regErrorText: regErrorText,
          filled: true,
          fillColor: Colors.white,
          errorStyle: const TextStyle(
            color: Color(0xFFEF4444),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        ),
      ],
    );
  }

  Widget _emptyCard(String message) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 34.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      child: Center(
        child: TextWidget(
          text: message,
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF4B5563),
        ),
      ),
    );
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

    // Fallback: many payloads return tab headers in `tabs`, but actual data
    // is available under root keys (for example `customers.items`).
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

      // Nested fallback shapes.
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
          next.containsKey('internal_ops') ||
          next.containsKey('internal_operations');

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
    if (value is CustomerModel) return value.toJson();
    if (value is ContactModel) return value.toJson();
    if (value is AssignedSpecialistModel) return value.toJson();
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) {
          return decoded.map((k, v) => MapEntry(k.toString(), v));
        }
      } catch (_) {}
    }
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

  String _safeImage(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.toLowerCase() == 'null') return Paths.user;
    return trimmed;
  }

  void _showAssignSpecialistsDialog(
    BuildContext context,
    List<dynamic> currentSpecialists,
  ) {
    final clientPro = Provider.of<ClientPro>(context, listen: false);
    if (clientPro.staffList.isEmpty) {
      clientPro.fetchStaff(showLoader: false);
    }

    // Initialize selected specialists from current data
    List<StaffModel> selected = [];
    for (var item in currentSpecialists) {
      final map = _asMap(item);
      final id = _pickInt(map, ['id', 'user_id']);
      final name = _fullName(map);
      selected.add(StaffModel(id: id, name: name, role: 2));
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28.r),
              ),
              insetPadding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Container(
                padding: EdgeInsets.all(24.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const TextWidget(
                          text: 'Assign Specialists',
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(
                            Icons.close,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    const TextWidget(
                      text: 'Select one or more specialists for this client.',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                    SizedBox(height: 24.h),
                    const TextWidget(
                      text: 'Assign Specialist Members',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF94A3B8),
                    ),
                    SizedBox(height: 12.h),

                    // Multi-select field with pills
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 8.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Wrap(
                        spacing: 8.w,
                        runSpacing: 8.h,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ...selected.map((s) {
                            return Container(
                              padding: EdgeInsets.only(
                                left: 12.w,
                                right: 8.w,
                                top: 6.h,
                                bottom: 6.h,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD9E396),
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextWidget(
                                    text: s.name.length > 10
                                        ? '${s.name.substring(0, 8)}...'
                                        : s.name,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF334155),
                                  ),
                                  SizedBox(width: 8.w),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        selected.removeWhere(
                                          (item) => item.id == s.id,
                                        );
                                      });
                                    },
                                    child: ImageWidget(
                                      image: Paths.delete,
                                      width: 14,
                                      color: const Color(0xFF334155),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          GestureDetector(
                            onTap: () => _showStaffPickerSheet(
                              context,
                              selectedIds: selected.map((s) => s.id).toSet(),
                              initiallySelected: selected,
                              onDone: (picked) => setState(() {
                                selected
                                  ..clear()
                                  ..addAll(picked);
                              }),
                            ),
                            child: Container(
                              width: 30.w,
                              height: 30.w,
                              decoration: BoxDecoration(
                                color: const Color(0xFFD9E396),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.add,
                                size: 18,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 32.h),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 12.h),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14.r),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: const TextWidget(
                                text: 'Cancel',
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final ids = selected.map((e) => e.id).toList();
                              final success =
                                  await Provider.of<ClientPro>(
                                    context,
                                    listen: false,
                                  ).assignSpecialists(
                                    clientId: widget.id,
                                    specialistIds: ids,
                                    showLoader: false,
                                  );

                              if (!context.mounted) return;

                              if (success) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Specialists updated successfully',
                                    ),
                                  ),
                                );
                                context.read<CustomerPro>().getMyNetworkTabs(
                                  ctx: context,
                                  clientId: widget.id,
                                );
                              }
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 12.h),
                              decoration: BoxDecoration(
                                color: const Color(0xFF22C55E),
                                borderRadius: BorderRadius.circular(14.r),
                              ),
                              alignment: Alignment.center,
                              child: const TextWidget(
                                text: 'Update',
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
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
      },
    );
  }

  void _showAssignInternalOpsContactsDialog(
    BuildContext context,
    List<dynamic> currentContacts,
  ) {
    // Initialize selected contacts from current data
    List<Map<String, dynamic>> selected = [];
    for (var item in currentContacts) {
      final map = _asMap(item);
      final id = _pickInt(map, ['id', 'user_id']);
      final name = _fullName(map);
      selected.add({
        'id': id,
        'name': name,
        'display_name': _pickString(map, ['display_name', 'name']),
      });
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28.r),
              ),
              insetPadding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Container(
                padding: EdgeInsets.all(24.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const TextWidget(
                          text: 'Manage Internal Ops Contacts',
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(
                            Icons.close,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    const TextWidget(
                      text: 'Select contacts to assign to Internal Operations.',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                    SizedBox(height: 24.h),
                    const TextWidget(
                      text: 'Assigned Contacts',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF94A3B8),
                    ),
                    SizedBox(height: 12.h),

                    // Multi-select field with pills
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 8.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Wrap(
                        spacing: 8.w,
                        runSpacing: 8.h,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ...selected.map((contact) {
                            return Container(
                              padding: EdgeInsets.only(
                                left: 12.w,
                                right: 8.w,
                                top: 6.h,
                                bottom: 6.h,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD9E396),
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextWidget(
                                    text:
                                        contact['display_name']
                                                .toString()
                                                .length >
                                            12
                                        ? '${contact['display_name'].toString().substring(0, 10)}...'
                                        : contact['display_name'].toString(),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF334155),
                                  ),
                                  SizedBox(width: 8.w),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        selected.removeWhere(
                                          (item) => item['id'] == contact['id'],
                                        );
                                      });
                                    },
                                    child: ImageWidget(
                                      image: Paths.delete,
                                      width: 14,
                                      color: const Color(0xFF334155),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          GestureDetector(
                            onTap: () => _showInternalOpsContactPickerSheet(
                              context,
                              selectedIds: selected
                                  .map((c) => c['id'] as int)
                                  .toSet(),
                              onDone: (pickedContacts) => setState(() {
                                selected
                                  ..clear()
                                  ..addAll(pickedContacts);
                              }),
                            ),
                            child: Container(
                              width: 30.w,
                              height: 30.w,
                              decoration: BoxDecoration(
                                color: const Color(0xFFD9E396),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.add,
                                size: 18,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 32.h),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 12.h),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14.r),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: const TextWidget(
                                text: 'Cancel',
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final ids = selected
                                  .map((e) => e['id'] as int)
                                  .toList();
                              final success =
                                  await Provider.of<ClientPro>(
                                    context,
                                    listen: false,
                                  ).updateClientInternalOpsContacts(
                                    clientId: widget.id,
                                    contactIds: ids,
                                    showLoader: false,
                                  );

                              if (!context.mounted) return;

                              if (success) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Internal ops contacts updated successfully',
                                    ),
                                  ),
                                );
                                context.read<CustomerPro>().getMyNetworkTabs(
                                  ctx: context,
                                  clientId: widget.id,
                                );
                              }
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 12.h),
                              decoration: BoxDecoration(
                                color: const Color(0xFF22C55E),
                                borderRadius: BorderRadius.circular(14.r),
                              ),
                              alignment: Alignment.center,
                              child: const TextWidget(
                                text: 'Update',
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
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
      },
    );
  }

  void _showStaffPickerSheet(
    BuildContext context, {
    required Set<int> selectedIds,
    required List<StaffModel> initiallySelected,
    required void Function(List<StaffModel>) onDone,
  }) {
    final clientPro = Provider.of<ClientPro>(context, listen: false);
    clientPro.fetchStaffPaged(reset: true);

    final searchCtrl = TextEditingController();
    final scrollCtrl = ScrollController();
    final tempSelectedIds = Set<int>.from(selectedIds);
    final tempSelectedModels = <int, StaffModel>{
      for (final s in initiallySelected) s.id: s,
    };

    scrollCtrl.addListener(() {
      if (scrollCtrl.position.pixels >=
          scrollCtrl.position.maxScrollExtent - 100) {
        clientPro.fetchStaffPaged(search: searchCtrl.text);
      }
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheet) {
            return Consumer<ClientPro>(
              builder: (sheetCtx, pro, _) {
                final items = pro.pagedStaffList;
                return Container(
                  height: MediaQuery.of(sheetCtx).size.height * 0.75,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24.r),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        margin: EdgeInsets.only(top: 12.h),
                        width: 40.w,
                        height: 4.h,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(2.r),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 0),
                        child: Row(
                          children: [
                            const TextWidget(
                              text: 'Select Specialist',
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () => Navigator.pop(sheetCtx),
                              child: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20.w,
                          vertical: 12.h,
                        ),
                        child: TextField(
                          controller: searchCtrl,
                          decoration: InputDecoration(
                            hintText: 'Search...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            contentPadding: EdgeInsets.symmetric(
                              vertical: 10.h,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                              borderSide: const BorderSide(
                                color: Color(0xFFCBD5E1),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                              borderSide: const BorderSide(
                                color: Color(0xFFCBD5E1),
                              ),
                            ),
                          ),
                          onChanged: (val) {
                            pro.fetchStaffPaged(search: val, reset: true);
                          },
                        ),
                      ),
                      Expanded(
                        child: items.isEmpty && !pro.isLoadingStaff
                            ? Center(
                                child: TextWidget(
                                  text: pro.pagedStaffList.isEmpty
                                      ? 'No results found'
                                      : 'All staff already selected',
                                  fontSize: 14,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              )
                            : ListView.separated(
                                controller: scrollCtrl,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 20.w,
                                  vertical: 4.h,
                                ),
                                itemCount:
                                    items.length + (pro.isLoadingStaff ? 1 : 0),
                                separatorBuilder: (_, _) => Divider(
                                  height: 1,
                                  color: const Color(0xFFF1F5F9),
                                ),
                                itemBuilder: (_, index) {
                                  if (index == items.length) {
                                    return Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 16.h,
                                      ),
                                      child: const Center(
                                        child: CupertinoActivityIndicator(),
                                      ),
                                    );
                                  }
                                  final s = items[index];
                                  final isSelected = tempSelectedIds.contains(
                                    s.id,
                                  );
                                  if (isSelected) tempSelectedModels[s.id] = s;
                                  return ListTile(
                                    contentPadding: EdgeInsets.symmetric(
                                      vertical: 4.h,
                                    ),
                                    leading: CircleAvatar(
                                      radius: 20.r,
                                      backgroundColor: isSelected
                                          ? const Color(0xFFD9E396)
                                          : const Color(0xFFF1F5F9),
                                      child: TextWidget(
                                        text: _initial(s.name),
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ),
                                    title: TextWidget(
                                      text: s.name,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    trailing: isSelected
                                        ? const Icon(
                                            Icons.check_circle,
                                            color: Color(0xFF22C55E),
                                            size: 22,
                                          )
                                        : null,
                                    onTap: () {
                                      setSheet(() {
                                        if (isSelected) {
                                          tempSelectedIds.remove(s.id);
                                          tempSelectedModels.remove(s.id);
                                        } else {
                                          tempSelectedIds.add(s.id);
                                          tempSelectedModels[s.id] = s;
                                        }
                                      });
                                    },
                                  );
                                },
                              ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 20.h),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF22C55E),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 14.h),
                            ),
                            onPressed: () {
                              Navigator.pop(sheetCtx);
                              final picked = tempSelectedIds
                                  .map((id) => tempSelectedModels[id])
                                  .whereType<StaffModel>()
                                  .toList();
                              onDone(picked);
                            },
                            child: const TextWidget(
                              text: 'Done',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showInternalOpsContactPickerSheet(
    BuildContext context, {
    required Set<int> selectedIds,
    required void Function(List<Map<String, dynamic>>) onDone,
  }) {
    // Get all internal ops contacts from the current client info tabs
    final clientPro = Provider.of<ClientPro>(context, listen: false);
    final tabsData = clientPro.currentClientInfoTabs;

    List<Map<String, dynamic>> allContacts = [];
    if (tabsData != null && tabsData.internalOps.isNotEmpty) {
      // Extract contacts from the internal ops section
      for (var contact in tabsData.internalOps) {
        allContacts.add({
          'id': contact.id,
          'display_name': contact.displayName,
          'name': '${contact.name} ${contact.lastName}',
          'initial': contact.initial,
        });
      }
    }

    final tempSelectedIds = Set<int>.from(selectedIds);
    final tempSelectedModels = <int, Map<String, dynamic>>{};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheet) {
            return Container(
              height: MediaQuery.of(sheetCtx).size.height * 0.75,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: EdgeInsets.only(top: 12.h),
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 0),
                    child: Row(
                      children: [
                        const TextWidget(
                          text: 'Select Internal Ops Contacts',
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => Navigator.pop(sheetCtx),
                          child: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: allContacts.isEmpty
                        ? Center(
                            child: TextWidget(
                              text: 'No internal ops contacts available',
                              fontSize: 14,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          )
                        : ListView.separated(
                            padding: EdgeInsets.symmetric(
                              horizontal: 20.w,
                              vertical: 12.h,
                            ),
                            itemCount: allContacts.length,
                            separatorBuilder: (_, _) => Divider(
                              height: 1,
                              color: const Color(0xFFF1F5F9),
                            ),
                            itemBuilder: (_, index) {
                              final contact = allContacts[index];
                              final contactId = contact['id'] as int;
                              final isSelected = tempSelectedIds.contains(
                                contactId,
                              );
                              if (isSelected) {
                                tempSelectedModels[contactId] = contact;
                              }
                              return ListTile(
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 4.h,
                                ),
                                leading: CircleAvatar(
                                  radius: 20.r,
                                  backgroundColor: isSelected
                                      ? const Color(0xFFD9E396)
                                      : const Color(0xFFF1F5F9),
                                  child: TextWidget(
                                    text: contact['initial']?.toString() ?? 'U',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                                title: TextWidget(
                                  text:
                                      contact['display_name']?.toString() ??
                                      'Unknown',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                trailing: isSelected
                                    ? const Icon(
                                        Icons.check_circle,
                                        color: Color(0xFF22C55E),
                                        size: 22,
                                      )
                                    : null,
                                onTap: () {
                                  setSheet(() {
                                    if (isSelected) {
                                      tempSelectedIds.remove(contactId);
                                      tempSelectedModels.remove(contactId);
                                    } else {
                                      tempSelectedIds.add(contactId);
                                      tempSelectedModels[contactId] = contact;
                                    }
                                  });
                                },
                              );
                            },
                          ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 20.h),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF22C55E),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                        ),
                        onPressed: () {
                          Navigator.pop(sheetCtx);
                          final picked = tempSelectedIds
                              .map((id) => tempSelectedModels[id])
                              .whereType<Map<String, dynamic>>()
                              .toList();
                          onDone(picked);
                        },
                        child: const TextWidget(
                          text: 'Done',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
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
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Padding(
            padding: EdgeInsets.all(24.w),
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
                SizedBox(height: 12.h),
                TextWidget(
                  text: 'Are you sure you want to $action "$clientName"?',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF475569),
                ),
                SizedBox(height: 24.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(dialogContext),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 10.h,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: const TextWidget(
                          text: 'Cancel',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
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
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 10.h,
                        ),
                        decoration: BoxDecoration(
                          color: currentStatus
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(8.r),
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
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Padding(
            padding: EdgeInsets.all(24.w),
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
                SizedBox(height: 12.h),
                TextWidget(
                  text:
                      'Are you sure you want to delete "$title"? This action cannot be undone.',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF475569),
                ),
                SizedBox(height: 24.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(dialogContext),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 10.h,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: const TextWidget(
                          text: 'Cancel',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
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
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 10.h,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(8.r),
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

  void _showStaffSelection(BuildContext context, {required bool isSupervisor}) {
    final clientPro = Provider.of<ClientPro>(context, listen: false);
    if (clientPro.staffList.isEmpty) {
      clientPro.fetchStaff(showLoader: false);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Consumer<ClientPro>(
              builder: (context, provider, child) {
                // Filter staff based on role if needed
                // For now, showing all, but can filter by isSupervisor if role mapping is clear
                final staff = provider.staffList.where((s) {
                  if (isSupervisor) {
                    return s.role == 1; // Assuming role 1 is supervisor
                  }
                  return s.role == 2; // Assuming role 2 is specialist
                }).toList();

                return Container(
                  height: MediaQuery.of(context).size.height * 0.7,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24.r),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        margin: EdgeInsets.only(top: 12.h),
                        width: 40.w,
                        height: 4.h,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(2.r),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(20.w),
                        child: Row(
                          children: [
                            TextWidget(
                              text: isSupervisor
                                  ? 'Select Supervisor'
                                  : 'Select Specialist',
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: staff.isEmpty
                            ? Center(
                                child: TextWidget(
                                  text: provider.staffList.isEmpty
                                      ? 'Loading staff...'
                                      : 'No matching staff found.',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey,
                                ),
                              )
                            : ListView.separated(
                                padding: EdgeInsets.symmetric(horizontal: 20.w),
                                itemCount: staff.length,
                                separatorBuilder: (_, _) => Divider(
                                  height: 1,
                                  color: const Color(0xFFF1F5F9),
                                ),
                                itemBuilder: (context, index) {
                                  final s = staff[index];
                                  return ListTile(
                                    contentPadding: EdgeInsets.symmetric(
                                      vertical: 4.h,
                                    ),
                                    leading: CircleAvatar(
                                      radius: 20.r,
                                      backgroundColor: const Color(0xFFF1F5F9),
                                      child: TextWidget(
                                        text: _initial(s.name),
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ),
                                    title: TextWidget(
                                      text: s.name,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    subtitle: TextWidget(
                                      text: s.role == 1
                                          ? 'Supervisor'
                                          : 'Specialist',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                      color: Colors.grey,
                                    ),
                                    onTap: () async {
                                      final pro = Provider.of<ClientPro>(
                                        context,
                                        listen: false,
                                      );
                                      bool success = false;

                                      if (isSupervisor) {
                                        success = await pro.assignSupervisor(
                                          clientId: widget.id,
                                          supervisorId: s.id,
                                          showLoader: true,
                                        );
                                      } else {
                                        // For specialist in single-select mode (if ever used this way)
                                        success = await pro.assignSpecialists(
                                          clientId: widget.id,
                                          specialistIds: [s.id],
                                          showLoader: true,
                                        );
                                      }

                                      if (!context.mounted) return;

                                      if (success) {
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '${isSupervisor ? 'Supervisor' : 'Specialist'} updated successfully',
                                            ),
                                          ),
                                        );
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
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
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

  Future<bool?> _showEditContactBottomSheet(
    BuildContext context,
    Map<String, dynamic> contact, {
    Map<String, dynamic>? customer,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: .25),
      builder: (_) => FractionallySizedBox(
        heightFactor: .98,
        child: _EditContactForm(
          contact: contact,
          customer: customer,
          clientId: widget.id,
        ),
      ),
    );
  }

  Widget _agreementSection(Map<String, dynamic> rootData, String clientName) {
    final clientPro = context.watch<ClientPro>();
    final tabsModel = clientPro.currentClientInfoTabs;

    if (tabsModel == null || tabsModel.agreementStandards.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const TextWidget(
          text: 'No agreement and standards available.',
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Color(0xFF6B7280),
        ),
      );
    }

    final item = tabsModel.agreementStandards.first;
    final hasSigned = item.hasSigned;
    final canSign = item.canSign;
    final templateName = item.template.name;
    final version = item.template.version;

    final authPro = Provider.of<AuthPro>(context, listen: false);
    final roleName = authPro.user?.roleName ?? '';
    final isAdmin = roleName == 'ADMIN';

    final clientMap = _asMap(rootData['client']);
    final contactsList = _asList(clientMap['contacts']);
    String contactName = 'N/A';
    if (contactsList.isNotEmpty) {
      final primaryMap = contactsList.firstWhere(
        (c) => _asMap(c)['is_primary'] == 1 || _asMap(c)['is_primary'] == true,
        orElse: () => contactsList.first,
      );
      final pName = _pickString(_asMap(primaryMap), ['name']);
      if (pName.trim().isNotEmpty) {
        contactName = pName.trim();
      }
    }

    final statusLabel = hasSigned
        ? 'Signed by ${item.signerName.isNotEmpty ? item.signerName : contactName}'
        : 'Pending signature from $contactName';

    String formatSignedAt(String raw) {
      if (raw.isEmpty) return '';
      final parsed = DateTime.tryParse(raw);
      if (parsed == null) return raw;
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final month = months[parsed.month - 1];
      final day = parsed.day.toString().padLeft(2, '0');
      var hour = parsed.hour;
      final minute = parsed.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      if (hour > 12) hour -= 12;
      if (hour == 0) hour = 12;
      return '$month $day, ${parsed.year} • $hour:$minute $period.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: hasSigned
                ? const Color(0xFFF0FDF4)
                : const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: hasSigned
                  ? const Color(0xFF86EFAC)
                  : const Color(0xFFEAB308),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38.w,
                    height: 38.w,
                    decoration: BoxDecoration(
                      color: hasSigned
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFF3E8BE),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.description_outlined,
                      size: 18,
                      color: hasSigned
                          ? const Color(0xFF15803D)
                          : const Color(0xFFB07A00),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Flexible(
                              child: TextWidget(
                                text: templateName,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                maxLines: 2,
                              ),
                            ),
                            SizedBox(width: 6.w),
                            TextWidget(
                              text: 'v$version',
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF9CA3AF),
                            ),
                          ],
                        ),
                        SizedBox(height: 2.h),
                        TextWidget(
                          text: statusLabel,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF4B5563),
                        ),
                        const TextWidget(
                          text:
                              'Please review and sign the service agreement to confirm your partnership with Print Helpers.',
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF4B5563),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: [
                  _agreementStatusChip(hasSigned: hasSigned),
                  if (hasSigned) ...[
                    _agreementActionButton(
                      icon: Icons.remove_red_eye_outlined,
                      label: 'View Agreement',
                      onPressed: () => _showAgreementBottomSheet(
                        rootData: rootData,
                        item: item,
                      ),
                    ),
                    if (item.pdfUrl.isNotEmpty)
                      _agreementActionButton(
                        icon: Icons.download_rounded,
                        label: 'Download PDF',
                        outlined: true,
                        onPressed: () => _downloadAgreementPdf(
                          item.pdfUrl,
                          item.template.name,
                        ),
                      ),
                  ] else if (canSign) ...[
                    _agreementActionButton(
                      icon: Icons.draw_outlined,
                      label: 'Sign Agreement',
                      bgColorOverride: const Color(0xFF92400E),
                      textColorOverride: Colors.white,
                      borderColorOverride: const Color(0xFF92400E),
                      onPressed: () => _showAgreementBottomSheet(
                        rootData: rootData,
                        item: item,
                      ),
                    ),
                  ],
                  if (isAdmin && !hasSigned)
                    _agreementActionButton(
                      icon: Icons.notifications_none_rounded,
                      label: 'Send Reminder',
                      outlined: true,
                      onPressed: () {
                        String agreementId = item.id;
                        if (agreementId.isEmpty ||
                            agreementId == '0' ||
                            agreementId == 'null') {
                          agreementId = 'client_${widget.id}';
                        }

                        debugPrint(
                          'Agreements Tab - Sending Reminder for ID: $agreementId',
                        );
                        final adminPro = Provider.of<AdminPro>(
                          context,
                          listen: false,
                        );
                        adminPro.sendContractReminder(agreementId);
                      },
                    ),
                ],
              ),
              if (hasSigned) ...[
                SizedBox(height: 10.h),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle,
                        size: 16,
                        color: Color(0xFF15803D),
                      ),
                      SizedBox(width: 6.w),
                      Expanded(
                        child: TextWidget(
                          text:
                              'Agreement signed by ${item.signerName} on ${formatSignedAt(item.signedAt)} • IP: ${item.ipAddress}',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF15803D),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                SizedBox(height: 10.h),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5EBC8),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: Color(0xFF9A6700),
                      ),
                      SizedBox(width: 6.w),
                      Expanded(
                        child: TextWidget(
                          text: canSign
                              ? 'Agreement has not been signed yet. Click "Sign Agreement" to complete the process.'
                              : 'Agreement has not been signed yet. Only the primary contact can sign this agreement.',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF9A6700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        if (item.rules.isNotEmpty) ...[
          SizedBox(height: 14.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 10.h),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TextWidget(
                  text:
                      'These are some of the most important standards of our community. By working with us, you agree to uphold these principles in every interaction.',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
                SizedBox(height: 12.h),
                ..._groupRulesByCategory(item.rules).entries.map((entry) {
                  final category = entry.key;
                  final rules = entry.value;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextWidget(
                        text: category.toUpperCase(),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF64748B),
                        letterSpacing: 3,
                      ),
                      SizedBox(height: 8.h),
                      ...rules.map(_standardRuleTile),
                      SizedBox(height: 10.h),
                    ],
                  );
                }),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Map<String, List<ClientStandardRuleModel>> _groupRulesByCategory(
    List<ClientStandardRuleModel> rules,
  ) {
    final grouped = <String, List<ClientStandardRuleModel>>{};
    for (final rule in rules) {
      final key = rule.categoryName.trim().isEmpty
          ? 'General'
          : rule.categoryName.trim();
      grouped.putIfAbsent(key, () => <ClientStandardRuleModel>[]).add(rule);
    }
    return grouped;
  }

  Widget _standardRuleTile(ClientStandardRuleModel rule) {
    final iconColor = _resolveIconColor(
      colorHex: rule.colorHex,
      iconColorToken: rule.iconColor,
    );
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: const Color(0xFFDFE6EE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30.w,
            height: 30.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconColor.withOpacity(0.16),
            ),
            alignment: Alignment.center,
            child: rule.iconSvgUrl.trim().isNotEmpty
                ? SvgPicture.network(
                    rule.iconSvgUrl,
                    width: 16.w,
                    height: 16.w,
                    colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                    placeholderBuilder: (context) => Icon(
                      _ruleIcon(
                        rule.iconName.isNotEmpty ? rule.iconName : rule.icon,
                      ),
                      size: 16,
                      color: iconColor,
                    ),
                  )
                : Icon(
                    _ruleIcon(
                      rule.iconName.isNotEmpty ? rule.iconName : rule.icon,
                    ),
                    size: 16,
                    color: iconColor,
                  ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextWidget(
                  text: rule.title,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1F2937),
                ),
                if (rule.description.trim().isNotEmpty)
                  Text(
                    rule.description,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                      height: 1.45,
                    ),
                    softWrap: true,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildElectronicSignatureSection({
    required ClientAgreementStandardsModel item,
    required String contactName,
    required bool isConfirmed,
    required ValueChanged<bool> onConfirmedChanged,
    required StateSetter setModalState,
    required TextEditingController nameController,
    required String dateString,
  }) {
    final hasSigned = item.hasSigned;
    final canSign = item.canSign;

    String formatSignedDateOnly(String raw) {
      if (raw.isEmpty) return '';
      final parsed = DateTime.tryParse(raw);
      if (parsed == null) return raw;
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final month = months[parsed.month - 1];
      final day = parsed.day.toString().padLeft(2, '0');
      return '$month $day, ${parsed.year}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 12.h),
        const TextWidget(
          text: 'Electronic Signature',
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Color(0xFF111827),
        ),
        SizedBox(height: 10.h),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: const Color(0xFFFEF3C7)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TextWidget(
                text:
                    'By typing your full name and clicking "I Agree & Sign" below, you acknowledge that:',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF92400E),
              ),
              SizedBox(height: 10.h),
              _signatureRequirementItem(
                'You have read and understand this Agreement and all linked policies;',
              ),
              _signatureRequirementItem(
                'You have authority to enter into this Agreement;',
              ),
              _signatureRequirementItem(
                'You agree to be legally bound by all terms herein;',
              ),
              _signatureRequirementItem(
                'Your electronic signature is binding under the Uniform Electronic Transactions Act (UETA) and has the same legal effect as a handwritten signature;',
              ),
              _signatureRequirementItem(
                'You consent to Service Provider collecting your IP address for security and record-keeping purposes.',
              ),
            ],
          ),
        ),
        if (hasSigned) ...[
          SizedBox(height: 12.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: const Color(0xFF86EFAC)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TextWidget(
                  text: 'Record of electronic signature',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF15803D),
                ),
                SizedBox(height: 8.h),
                const TextWidget(
                  text:
                      'The name, date, and confirmation below reflect what was submitted when this agreement was signed.',
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF15803D),
                ),
                SizedBox(height: 8.h),
                Text.rich(
                  TextSpan(
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: const Color(0xFF15803D),
                    ),
                    children: const [
                      TextSpan(text: 'The '),
                      TextSpan(
                        text: 'terms & conditions',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(
                        text:
                            ' and specialist standards shown above are part of this agreement and are included in your PDF download.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TextWidget(
                      text: 'FULL LEGAL NAME',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6B7280),
                      letterSpacing: 1.5,
                    ),
                    SizedBox(height: 6.h),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 10.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: TextWidget(
                        text: item.signerName.isNotEmpty
                            ? item.signerName
                            : item.signature,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF111827),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TextWidget(
                      text: 'DATE SIGNED',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6B7280),
                      letterSpacing: 1.5,
                    ),
                    SizedBox(height: 6.h),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 10.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: TextWidget(
                        text: formatSignedDateOnly(item.signedAt),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF111827),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          TextWidget(
            text: 'IP address (recorded): ${item.ipAddress}',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF4B5563),
          ),
          SizedBox(height: 12.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 20,
                width: 20,
                child: Checkbox(
                  value: true,
                  onChanged: null,
                  activeColor: const Color(0xFFD58F16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              const Expanded(
                child: TextWidget(
                  text:
                      'I confirmed that I had read and agreed to the statements above at the time of signing.',
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
        ] else if (canSign) ...[
          SizedBox(height: 16.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TextWidget(
                      text: 'FULL LEGAL NAME *',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6B7280),
                      letterSpacing: 1.5,
                    ),
                    SizedBox(height: 6.h),
                    TextFormField(
                      controller: nameController,
                      onChanged: (val) {
                        setModalState(() {});
                      },
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 12.h,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        hintText: contactName.toLowerCase() == 'n/a'
                            ? 'First Last'
                            : contactName.split(RegExp(r'\s+')).length >= 2
                            ? contactName
                            : '$contactName Last',
                        hintStyle: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF9CA3AF),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E7EB),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E7EB),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                          borderSide: const BorderSide(
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ),
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    SizedBox(height: 4.h),
                    TextWidget(
                      text: contactName.toLowerCase() == 'n/a'
                          ? "Please enter your full first and last name."
                          : contactName.split(RegExp(r'\s+')).length >= 2
                          ? "Must match '$contactName' to be valid."
                          : "Must match '$contactName' and include your last name to be valid.",
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF9CA3AF),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TextWidget(
                      text: 'DATE',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6B7280),
                      letterSpacing: 1.5,
                    ),
                    SizedBox(height: 6.h),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 12.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: TextWidget(
                        text: dateString,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 20,
                width: 20,
                child: Checkbox(
                  value: isConfirmed,
                  onChanged: (val) {
                    onConfirmedChanged(val ?? false);
                  },
                  activeColor: const Color(0xFFD58F16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              const Expanded(
                child: TextWidget(
                  text:
                      'I confirm that I have read and agree to the statements above.',
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
        ] else ...[
          SizedBox(height: 12.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Color(0xFF475569),
                ),
                SizedBox(width: 8.w),
                const Expanded(
                  child: TextWidget(
                    text:
                        'View only: only the primary contact is allowed to sign this agreement.',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 10.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 20,
                width: 20,
                child: Checkbox(
                  value: false,
                  onChanged: null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              const Expanded(
                child: TextWidget(
                  text:
                      'I confirm that I have read and agree to the statements above. Only the primary contact can check this when signing.',
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _signatureRequirementItem(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TextWidget(
            text: '•',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF92400E),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: TextWidget(
              text: text,
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF92400E),
              maxLines: 4,
            ),
          ),
        ],
      ),
    );
  }

  IconData _ruleIcon(String iconName) {
    final key = iconName.toLowerCase();
    if (key.contains('briefcase')) {
      return Icons.work_rounded;
    }
    if (key.contains('money') || key.contains('bill') || key.contains('cash')) {
      return Icons.payments_rounded;
    }
    if (key.contains('triangle') || key.contains('exclamation')) {
      return Icons.warning_rounded;
    }
    if (key.contains('user-tie')) {
      return Icons.badge_rounded;
    }
    if (key.contains('warn') || key.contains('alert')) {
      return Icons.warning_rounded;
    }
    if (key.contains('check') || key.contains('done')) {
      return Icons.task_alt_rounded;
    }
    if (key.contains('user') || key.contains('group') || key.contains('team')) {
      return Icons.groups_rounded;
    }
    if (key.contains('doc') || key.contains('file')) {
      return Icons.description_rounded;
    }
    return Icons.circle_notifications_rounded;
  }

  Color _resolveIconColor({
    required String colorHex,
    required String iconColorToken,
  }) {
    if (colorHex.trim().isNotEmpty) {
      return _hexToColor(colorHex);
    }

    final token = iconColorToken.toLowerCase();
    if (token.contains('orange')) return const Color(0xFFF97316);
    if (token.contains('red')) return const Color(0xFFEF4444);
    if (token.contains('purple')) return const Color(0xFFA855F7);
    if (token.contains('green')) return const Color(0xFF22C55E);
    if (token.contains('blue')) return const Color(0xFF3B82F6);
    if (token.contains('amber') || token.contains('yellow')) {
      return const Color(0xFFF59E0B);
    }
    return const Color(0xFF64748B);
  }

  Widget _agreementStatusChip({required bool hasSigned}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: hasSigned ? const Color(0xFFDCFCE7) : const Color(0xFFF5EBC8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasSigned ? Icons.check_circle : Icons.error,
            size: 14,
            color: hasSigned
                ? const Color(0xFF15803D)
                : const Color(0xFF9A6700),
          ),
          SizedBox(width: 4.w),
          TextWidget(
            text: hasSigned ? 'Signed' : 'Pending Signature',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: hasSigned
                ? const Color(0xFF15803D)
                : const Color(0xFF9A6700),
          ),
        ],
      ),
    );
  }

  Widget _agreementActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool outlined = false,
    Color? bgColorOverride,
    Color? textColorOverride,
    Color? borderColorOverride,
  }) {
    final borderColor =
        borderColorOverride ??
        (outlined ? const Color(0xFFD58F16) : const Color(0xFFD1D5DB));
    final bgColor =
        bgColorOverride ??
        (outlined ? Colors.transparent : const Color(0xFFF8FAFC));
    final textColor =
        textColorOverride ??
        (outlined ? const Color(0xFF9A6700) : const Color(0xFF1E3A8A));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onPressed,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: textColor),
              SizedBox(width: 5.w),
              TextWidget(
                text: label,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _stripHtml(String html) {
    final withBreaks = html
        .replaceAll(RegExp(r'<\s*br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<\s*/\s*li\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<\s*li[^>]*>', caseSensitive: false), '- ')
        .replaceAll(RegExp(r'<\s*/\s*p\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<\s*p[^>]*>', caseSensitive: false), '');
    return withBreaks
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll(RegExp(r'\n\s*\n+'), '\n')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .trim();
  }

  Future<void> _downloadAgreementPdf(String url, String templateName) async {
    try {
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          final photos = await Permission.photos.request();
          if (!photos.isGranted) {
            showToast(message: "Storage permission denied");
            return;
          }
        }
      }

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      // Sanitise templateName to create a safe file name
      final safeName = templateName.replaceAll(RegExp(r'[^\w\s\-]'), '_');
      final fileName = '${safeName}_agreement.pdf';

      showToast(message: "Starting download...");
      await DownloadService.instance.downloadFile(
        url: url,
        fileName: fileName,
        headers: {'Authorization': 'Bearer $token'},
      );
    } catch (e) {
      debugPrint("Download agreement error: $e");
      showToast(message: "Failed to download agreement");
    }
  }

  void _showAgreementBottomSheet({
    required Map<String, dynamic> rootData,
    required ClientAgreementStandardsModel item,
  }) {
    final templateName = item.template.name.trim().isEmpty
        ? 'Client Template Name'
        : item.template.name.trim();
    final version = item.template.version.trim().isEmpty
        ? '1.0'
        : item.template.version.trim();

    final clientMap = _asMap(rootData['client']);
    final clientName = _pickString(clientMap, [
      'company_name',
    ], fallback: 'Client');
    final contactsList = _asList(clientMap['contacts']);
    String contactName = 'N/A';
    if (contactsList.isNotEmpty) {
      final primaryMap = contactsList.firstWhere(
        (c) => _asMap(c)['is_primary'] == 1 || _asMap(c)['is_primary'] == true,
        orElse: () => contactsList.first,
      );
      final pName = _pickString(_asMap(primaryMap), ['name']);
      final pLastName = _pickString(_asMap(primaryMap), ['last_name']);
      final fullName = '$pName $pLastName'.trim();
      if (fullName.isNotEmpty) {
        contactName = fullName;
      }
    }

    final addressMap = _asMap(clientMap['address']);
    final fullAddress = [
      _pickString(addressMap, ['address']),
      _pickString(addressMap, ['address2']),
      _pickString(addressMap, ['city']).isNotEmpty
          ? '${_pickString(addressMap, ['city'])},'
          : '',
      '${_pickString(addressMap, ['state'])} ${_pickString(addressMap, ['zipcode'])}'
          .trim(),
    ].where((s) => s.trim().isNotEmpty).join('\n');

    final clientSubtitle = 'Contact: $contactName\n$fullAddress';

    final agreementContent = _stripHtml(item.content);

    bool isConfirmed = false;
    final nameController = TextEditingController(
      text: contactName.toLowerCase() == 'n/a' ? '' : contactName,
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) {
        const months = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];
        final now = DateTime.now();
        final month = months[now.month - 1];
        final day = now.day.toString().padLeft(2, '0');
        final dateString = '$month $day, ${now.year}';

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final enteredText = nameController.text.trim();
            final enteredWords = enteredText
                .split(RegExp(r'\s+'))
                .where((w) => w.isNotEmpty)
                .toList();
            final hasFirstAndLastName = enteredWords.length >= 2;

            bool isNameValid = false;
            if (hasFirstAndLastName) {
              final contactWords = contactName
                  .split(RegExp(r'\s+'))
                  .where((w) => w.isNotEmpty)
                  .toList();
              if (contactWords.isEmpty || contactName.toLowerCase() == 'n/a') {
                isNameValid = true;
              } else {
                final expectedFirstName = contactWords.first.toLowerCase();
                final enteredFirstName = enteredWords.first.toLowerCase();
                final exactMatch =
                    enteredText.toLowerCase() == contactName.toLowerCase();
                isNameValid =
                    exactMatch || (enteredFirstName == expectedFirstName);
              }
            }

            final viewInsets = MediaQuery.of(context).viewInsets;
            final screenHeight = MediaQuery.of(context).size.height;
            final availableHeight = screenHeight - viewInsets.bottom;

            return Padding(
              padding: EdgeInsets.only(bottom: viewInsets.bottom),
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(14.r)),
                child: Container(
                  height: availableHeight * 0.9,
                  color: Colors.white,
                  child: Column(
                    children: [
                      Container(
                        color: Colors.black,
                        padding: EdgeInsets.symmetric(
                          horizontal: 18.w,
                          vertical: 12.h,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TextWidget(
                                    text: templateName,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                  SizedBox(height: 2.h),
                                  const TextWidget(
                                    text:
                                        'Print Helpers - Please read carefully before signing',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    color: Color(0xFF9CA3AF),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.pop(ctx),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 14.h),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Container(
                                      width: double.infinity,
                                      padding: EdgeInsets.all(12.w),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF9FAFB),
                                        borderRadius: BorderRadius.circular(
                                          10.r,
                                        ),
                                        border: Border.all(
                                          color: const Color(0xFFE5E7EB),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const TextWidget(
                                            text: 'SERVICE PROVIDER',
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF9CA3AF),
                                            letterSpacing: 1.6,
                                          ),
                                          SizedBox(height: 6.h),
                                          const TextWidget(
                                            text: 'Print Helpers LLC',
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF1E3A8A),
                                          ),
                                          SizedBox(height: 4.h),
                                          const TextWidget(
                                            text:
                                                'printhelpers.com\n2080 Empire Ave. #1032\nBurbank, CA 91504',
                                            fontSize: 12,
                                            fontWeight: FontWeight.w400,
                                            color: Color(0xFF4B5563),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 10.w),
                                  Expanded(
                                    child: Container(
                                      width: double.infinity,
                                      padding: EdgeInsets.all(12.w),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF9FAFB),
                                        borderRadius: BorderRadius.circular(
                                          10.r,
                                        ),
                                        border: Border.all(
                                          color: const Color(0xFFE5E7EB),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const TextWidget(
                                            text: 'CLIENT',
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF9CA3AF),
                                            letterSpacing: 1.6,
                                          ),
                                          SizedBox(height: 6.h),
                                          TextWidget(
                                            text: clientName,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF1E3A8A),
                                          ),
                                          SizedBox(height: 4.h),
                                          TextWidget(
                                            text: clientSubtitle,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w400,
                                            color: const Color(0xFF4B5563),
                                            maxLines: 4,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12.h),

                              SizedBox(height: 10.h),
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(14.w),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9FAFB),
                                  borderRadius: BorderRadius.circular(12.r),
                                  border: Border.all(
                                    color: const Color(0xFFD1D5DB),
                                  ),
                                ),
                                child: agreementContent.trim().isEmpty
                                    ? const TextWidget(
                                        text: 'No agreement content available.',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF6B7280),
                                      )
                                    : Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: agreementContent
                                            .split('\n')
                                            .map((s) => s.trim())
                                            .where((s) => s.isNotEmpty)
                                            .map(
                                              (s) => s.startsWith('-')
                                                  ? s.substring(1).trim()
                                                  : s,
                                            )
                                            .toList()
                                            .asMap()
                                            .entries
                                            .map((entry) {
                                              final index = entry.key;
                                              final text = entry.value;
                                              return Padding(
                                                padding: EdgeInsets.only(
                                                  bottom: 8.h,
                                                ),
                                                child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    TextWidget(
                                                      text: '${index + 1}. ',
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: const Color(
                                                        0xFF111827,
                                                      ),
                                                    ),
                                                    Expanded(
                                                      child: TextWidget(
                                                        text: text,
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: const Color(
                                                          0xFF111827,
                                                        ),
                                                        maxLines: 10,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            })
                                            .toList(),
                                      ),
                              ),
                              SizedBox(height: 12.h),
                              ..._groupRulesByCategory(item.rules).entries.map((
                                entry,
                              ) {
                                final category = entry.key;
                                final rules = entry.value;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextWidget(
                                      text: category.toUpperCase(),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF64748B),
                                      letterSpacing: 3,
                                    ),
                                    SizedBox(height: 8.h),
                                    ...rules.map(_standardRuleTile),
                                    SizedBox(height: 10.h),
                                  ],
                                );
                              }),
                              _buildElectronicSignatureSection(
                                item: item,
                                contactName: contactName,
                                isConfirmed: isConfirmed,
                                onConfirmedChanged: (val) {
                                  setModalState(() {
                                    isConfirmed = val;
                                  });
                                },
                                setModalState: setModalState,
                                nameController: nameController,
                                dateString: dateString,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 14.h),
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: item.hasSigned
                                  ? OutlinedButton(
                                      onPressed: item.pdfUrl.isNotEmpty
                                          ? () {
                                              _downloadAgreementPdf(
                                                item.pdfUrl,
                                                item.template.name,
                                              );
                                            }
                                          : null,
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(
                                          color: Color(0xFF2563EB),
                                        ),
                                        minimumSize: Size.fromHeight(44.h),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8.r,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.picture_as_pdf,
                                            color: Color(0xFF2563EB),
                                            size: 18,
                                          ),
                                          SizedBox(width: 8.w),
                                          TextWidget(
                                            text: 'Download PDF',
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF2563EB),
                                          ),
                                        ],
                                      ),
                                    )
                                  : ElevatedButton.icon(
                                      onPressed:
                                          (item.canSign &&
                                              isConfirmed &&
                                              isNameValid)
                                          ? () async {
                                              final pro =
                                                  Provider.of<ClientPro>(
                                                    context,
                                                    listen: false,
                                                  );
                                              final res = await pro
                                                  .signClientAgreement(
                                                    clientId: widget.id,
                                                    signerName: nameController
                                                        .text
                                                        .trim(),
                                                    signedDate: DateTime.now()
                                                        .toIso8601String(),
                                                  );
                                              if (res && context.mounted) {
                                                Navigator.pop(ctx);
                                              }
                                            }
                                          : null,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFFF5D070,
                                        ),
                                        disabledBackgroundColor: const Color(
                                          0xFFF5E8C4,
                                        ),
                                        foregroundColor: const Color(
                                          0xFF475569,
                                        ),
                                        disabledForegroundColor: const Color(
                                          0xFF94A3B8,
                                        ),
                                        minimumSize: Size.fromHeight(44.h),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8.r,
                                          ),
                                        ),
                                        elevation: 0,
                                      ),
                                      icon: Icon(
                                        Icons.draw_outlined,
                                        size: 18,
                                        color:
                                            (item.canSign &&
                                                isConfirmed &&
                                                isNameValid)
                                            ? const Color(0xFF475569)
                                            : const Color(0xFF94A3B8),
                                      ),
                                      label: Text(
                                        'I Agree & Sign',
                                        style: TextStyle(
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                            ),
                            SizedBox(width: 8.w),
                            OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: OutlinedButton.styleFrom(
                                minimumSize: Size(86.w, 44.h),
                                side: const BorderSide(
                                  color: Color(0xFFD1D5DB),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF374151),
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
          },
        );
      },
    );
  }
}

class _EditContactForm extends StatefulWidget {
  final Map<String, dynamic> contact;
  final Map<String, dynamic>? customer;
  final int clientId;
  const _EditContactForm({
    required this.contact,
    this.customer,
    required this.clientId,
  });

  @override
  State<_EditContactForm> createState() => _EditContactFormState();
}

class _EditContactFormState extends State<_EditContactForm> {
  late GlobalKey<FormState> _formKey;
  late TextEditingController _userCtrl;
  late TextEditingController _passCtrl;
  late TextEditingController _confirmCtrl;
  late TextEditingController _firstCtrl;
  late TextEditingController _lastCtrl;
  List<ContactFormModel> _contactModels = [];
  int _editingIndex = 0;
  int? _openPhoneDropdownIndex;
  final List<PhoneType> _phoneTypes = [
    PhoneType("Land Phone", Paths.landPhone, "landline"),
    PhoneType("Phone", Paths.call, "mobile"),
    PhoneType("Other", Paths.other, "another"),
  ];
  File? _selectedImage;
  String? _imageUrl;
  List<int> _selectedLangIds = [];
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  bool _showLangDropdown = false;

  @override
  void initState() {
    super.initState();
    _formKey = GlobalKey<FormState>();
    final c = widget.contact;
    final customer = widget.customer ?? c;
    final details = customer['contact_details'] ?? {};
    final contactsList = _asList(details['contacts'] ?? customer['contacts']);

    // Build models for all contacts to preserve them during editCust call
    if (contactsList.isEmpty) {
      _contactModels = [_parseToModel(c)];
      _editingIndex = 0;
    } else {
      _contactModels = contactsList
          .map((item) => _parseToModel(_asMap(item)))
          .toList();
      final targetId = _pickInt(c, ['id', 'account_id']);
      _editingIndex = _contactModels.indexWhere(
        (m) => m.existingId == targetId,
      );
      if (_editingIndex == -1) {
        _contactModels.add(_parseToModel(c));
        _editingIndex = _contactModels.length - 1;
      }
    }

    final activeModel = _contactModels[_editingIndex];
    _userCtrl = activeModel.username;
    _passCtrl = activeModel.password;
    _confirmCtrl = activeModel.confirmPassword;
    _firstCtrl = activeModel.firstName;
    _lastCtrl = activeModel.lastName;
    _imageUrl = activeModel.imageUrl;
    _selectedLangIds = activeModel.selectedLanguageIds;

    _obscurePass = true;
    _obscureConfirm = true;
    _showLangDropdown = false;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminPro>().fetchAllDropdownData(context);
    });
  }

  @override
  void dispose() {
    for (var m in _contactModels) {
      m.username.dispose();
      m.password.dispose();
      m.confirmPassword.dispose();
      m.firstName.dispose();
      m.lastName.dispose();
      for (var e in m.emails) {
        e.dispose();
      }
      for (var p in m.phoneFields) {
        p.controller.dispose();
      }
    }
    super.dispose();
  }

  ContactFormModel _parseToModel(Map<String, dynamic> c) {
    final model = ContactFormModel();
    model.existingId = _pickInt(c, ['id', 'account_id']);
    model.username.text = _pickString(c, ['username']);
    model.firstName.text = _pickString(c, ['name', 'first_name']);
    model.lastName.text = _pickString(c, ['last_name']);
    final rawImageUrl = _pickString(c, [
      'image_url',
      'image',
      'avatar',
      'photo',
    ]);
    model.imageUrl = rawImageUrl.startsWith('http') ? rawImageUrl : '';

    final details = c['contact_details'] ?? {};

    // Parse Phones
    final phonesList = _asList(details['phones'] ?? c['phones']);
    if (phonesList.isNotEmpty) {
      model.phoneFields = phonesList.map((p) {
        final map = _asMap(p);
        final apiType = _pickString(map, ['type']);
        final type = _phoneTypes.firstWhere(
          (t) => t.apiValue == apiType,
          orElse: () => _phoneTypes[1],
        );
        return PhoneField(
          type: type,
          controller: TextEditingController(
            text: _pickString(map, ['number', 'value', 'phone']),
          ),
        );
      }).toList();
    } else {
      model.phoneFields = [
        PhoneField(
          type: _phoneTypes[1],
          controller: TextEditingController(
            text: _pickString(c, ['phone', 'mobile']),
          ),
        ),
      ];
    }

    // Parse Emails
    final emailsList = _asList(details['emails'] ?? c['emails']);
    if (emailsList.isNotEmpty) {
      model.emails = emailsList
          .map((e) => TextEditingController(text: e.toString()))
          .toList();
    } else {
      model.emails = [
        TextEditingController(text: _pickString(c, ['email'])),
      ];
    }

    // Parse Languages
    final langs = details['languages'] ?? c['languages'];
    if (langs is List) {
      model.selectedLanguageIds = langs
          .map<int>((l) {
            if (l is int) return l;
            if (l is Map) return _pickInt(_asMap(l), ['id']);
            return 0;
          })
          .where((id) => id != 0)
          .toList();
    }

    return model;
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

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is CustomerModel) return value.toJson();
    if (value is ContactModel) return value.toJson();
    if (value is AssignedSpecialistModel) return value.toJson();
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) {
          return decoded.map((k, v) => MapEntry(k.toString(), v));
        }
      } catch (_) {}
    }
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

  int _pickInt(
    Map<String, dynamic> map,
    List<String> keys, {
    int fallback = 0,
  }) {
    for (final key in keys) {
      final value = map[key];
      if (value == null) continue;
      final numValue = int.tryParse(value.toString());
      if (numValue != null) return numValue;
    }
    return fallback;
  }

  Future<void> _pickImage() async {
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'png', 'jpeg'],
    );
    if (picked != null && picked.files.single.path != null) {
      setState(() {
        _selectedImage = File(picked.files.single.path!);
        _imageUrl = null;
      });
    }
  }

  Future<void> _onSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_passCtrl.text.isNotEmpty && _passCtrl.text != _confirmCtrl.text) {
      showToast(message: "Passwords do not match");
      return;
    }

    setState(() => _loading = true);
    final pro = context.read<CustomerPro>();
    final activeModel = _contactModels[_editingIndex];

    activeModel.image = _selectedImage;
    activeModel.selectedLanguageIds = _selectedLangIds;

    final success = await pro.saveClientContact(
      clientId: widget.clientId,
      contactId: activeModel.existingId,
      contact: activeModel,
      context: context,
    );

    if (!mounted) return;
    setState(() => _loading = false);
    if (success) {
      showToast(message: "Contact updated successfully");
      Navigator.pop(context, true);
    } else {
      showToast(message: "Failed to update contact");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        margin: EdgeInsets.only(top: 40.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30.r)),
        ),
        child: Column(
          children: [
            _header(),
            Divider(thickness: 2.w, color: const Color(0x5F9E9E9E)),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16.w),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _profileImage(),
                      Spacers.sb20(),
                      _field(
                        controller: _userCtrl,
                        label: "*User name",
                        hint: "Type User Name",
                        regExp: Regx.userNameRegExp,
                        errorText: "Required",
                      ),
                      Spacers.sb12(),
                      _field(
                        controller: _passCtrl,
                        label: "Password",
                        hint: "Type Password",
                        obscure: _obscurePass,
                        isPassword: true,
                        regExp: Regx.optionalPasswordRegExp,
                        onToggle: () =>
                            setState(() => _obscurePass = !_obscurePass),
                      ),
                      Spacers.sb12(),
                      _field(
                        controller: _confirmCtrl,
                        label: "Confirm Password",
                        hint: "Type Confirm Password",
                        obscure: _obscureConfirm,
                        isPassword: true,
                        regExp: Regx.optionalPasswordRegExp,
                        onToggle: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                      Spacers.sb12(),
                      _field(
                        controller: _firstCtrl,
                        label: "*First Name",
                        hint: "Type First Name",
                        regExp: Regx.nameRegExp,
                        errorText: "Required",
                      ),
                      Spacers.sb12(),
                      _field(
                        controller: _lastCtrl,
                        label: "*Last Name",
                        hint: "Type Last Name",
                        regExp: Regx.nameRegExp,
                        errorText: "Required",
                      ),
                      Spacers.sb12(),
                      _contactPhoneSection(_contactModels[_editingIndex]),
                      Spacers.sb12(),
                      _contactEmailSection(_contactModels[_editingIndex]),
                      Spacers.sb12(),
                      _languageSelector(),
                      Spacers.sb30(),
                      _actions(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 20.w),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30.r),
          topRight: Radius.circular(30.r),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 45.w,
            height: 5.h,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(10.r),
            ),
          ),
          Spacers.sb10(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const TextWidget(
                text: "Main Contact Info",
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(Icons.close, size: 26.sp, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _contactPhoneSection(ContactFormModel model) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 15.w),
          child: const TextWidget(
            text: "Phone(s) with Country Code",
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Colors.black,
          ),
        ),
        Spacers.sb8(),
        Column(
          children: model.phoneFields.asMap().entries.map((entry) {
            final index = entry.key;
            final field = entry.value;
            final isLast = index == model.phoneFields.length - 1;
            return Column(
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => setState(
                        () => _openPhoneDropdownIndex =
                            _openPhoneDropdownIndex == index ? null : index,
                      ),
                      child: Container(
                        height: 45.h,
                        width: 70.w,
                        padding: EdgeInsets.symmetric(horizontal: 10.w),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16.r),
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
                              _openPhoneDropdownIndex == index
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              size: 22.sp,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Spacers.sbw12(),
                    Expanded(
                      child: Container(
                        height: 45.h,
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16.r),
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
                            hintText: "Type Phone No",
                            hintStyle: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 14.sp,
                            ),
                          ),
                          inputFormatters: [InternationalPhoneFormatter()],
                        ),
                      ),
                    ),
                    Spacers.sbw12(),
                    GestureDetector(
                      onTap: () {
                        if (isLast) {
                          setState(
                            () => model.phoneFields.add(
                              PhoneField(
                                type: _phoneTypes[1], // Default to Phone/Mobile
                                controller: TextEditingController(),
                              ),
                            ),
                          );
                        } else {
                          setState(() => model.phoneFields.removeAt(index));
                        }
                      },
                      child: Container(
                        width: 40.w,
                        height: 40.h,
                        decoration: isLast
                            ? const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              )
                            : null,
                        child: isLast
                            ? Icon(Icons.add, size: 23.sp, color: Colors.white)
                            : Padding(
                                padding: EdgeInsets.all(7.w),
                                child: ImageWidget(image: Paths.delete),
                              ),
                      ),
                    ),
                  ],
                ),
                if (index != model.phoneFields.length - 1) Spacers.sb10(),
                if (_openPhoneDropdownIndex == index)
                  Container(
                    width: double.infinity,
                    margin: EdgeInsets.only(top: 6.h, bottom: 12.h),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(
                        color: Colors.grey.shade400,
                        width: 1.3,
                      ),
                    ),
                    child: Column(
                      children: _phoneTypes.map((type) {
                        final selected = field.type.label == type.label;
                        return GestureDetector(
                          onTap: () => setState(() {
                            field.type = type;
                            _openPhoneDropdownIndex = null;
                          }),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              vertical: 12.h,
                              horizontal: 14.w,
                            ),
                            margin: EdgeInsets.only(bottom: 3.h, top: 5.h),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14.r),
                              color: selected
                                  ? const Color(0xFFE9F5D4)
                                  : Colors.grey.shade200,
                            ),
                            child: Row(
                              children: [
                                ImageWidget(image: type.image, width: 22),
                                Spacers.sbw10(),
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
                                  Icon(
                                    Icons.check_circle,
                                    size: 22.sp,
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
          }).toList(),
        ),
      ],
    );
  }

  Widget _contactEmailSection(ContactFormModel model) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 15.w),
          child: const TextWidget(
            text: "Email (s)",
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        Spacers.sb8(),
        Column(
          children: model.emails.asMap().entries.map((entry) {
            final index = entry.key;
            final ctrl = entry.value;
            final isLast = index == model.emails.length - 1;
            return Padding(
              padding: EdgeInsets.only(bottom: 10.h),
              child: Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: ctrl,
                      hintText: "Type Email",
                      regExpCondition: Regx.emailRegExp,
                      filled: true,
                      fillColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 12.w,
                      ),
                    ),
                  ),
                  Spacers.sbw12(),
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
                      width: 40.w,
                      height: 40.h,
                      decoration: isLast
                          ? const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            )
                          : null,
                      child: isLast
                          ? Icon(Icons.add, size: 23.sp, color: Colors.white)
                          : Padding(
                              padding: EdgeInsets.all(7.w),
                              child: ImageWidget(image: Paths.delete),
                            ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _profileImage() {
    ImageProvider provider;
    if (_selectedImage != null) {
      provider = FileImage(_selectedImage!);
    } else if (_imageUrl != null && _imageUrl!.isNotEmpty) {
      provider = NetworkImage(_imageUrl!);
    } else {
      provider = AssetImage(Paths.user);
    }

    return Center(
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            width: 140.w,
            height: 140.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade200, width: 3),
              image: DecorationImage(image: provider, fit: BoxFit.cover),
            ),
          ),
          GestureDetector(
            onTap: () => _pickImage(),
            child: Container(
              padding: EdgeInsets.all(8.w),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
              ),
              child: Icon(
                Icons.edit_outlined,
                size: 20.sp,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool obscure = false,
    bool isPassword = false,
    RegExp? regExp,
    VoidCallback? onToggle,
    String? errorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 15.w, bottom: 6.h),
          child: TextWidget(
            text: label,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        CustomTextField(
          controller: controller,
          hintText: hint,
          passField: isPassword,
          obscureText: obscure,
          regExpCondition: regExp ?? Regx.optionalText,
          errorText: errorText,
          filled: true,
          fillColor: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.w),
          suffixIcon: isPassword
              ? GestureDetector(
                  onTap: onToggle,
                  child: Icon(
                    obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20.sp,
                    color: Colors.grey,
                  ),
                )
              : null,
        ),
      ],
    );
  }

  Widget _languageSelector() {
    final pro = context.watch<AdminPro>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 15.w, bottom: 6.h),
          child: const TextWidget(
            text: "Language",
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        GestureDetector(
          onTap: () => setState(() => _showLangDropdown = !_showLangDropdown),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.w),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: Colors.grey.shade400),
              color: Colors.white,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _selectedLangIds.isEmpty
                        ? [
                            const TextWidget(
                              text: "Select",
                              color: Colors.black54,
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                          ]
                        : _selectedLangIds.map((id) {
                            final lang = pro.languages.firstWhere(
                              (e) => e.id == id,
                              orElse: () =>
                                  DropdownItem(id: id, name: id.toString()),
                            );
                            return Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10.w,
                                vertical: 6.h,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE9F5D4),
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextWidget(
                                    text: lang.name,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                  Spacers.sbw8(),
                                  GestureDetector(
                                    onTap: () => setState(
                                      () => _selectedLangIds.remove(id),
                                    ),
                                    child: ImageWidget(
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
                  _showLangDropdown
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 30.sp,
                  color: Colors.black,
                ),
              ],
            ),
          ),
        ),
        if (_showLangDropdown)
          Container(
            margin: EdgeInsets.only(top: 6.h),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: Colors.grey.shade300),
              color: Colors.white,
            ),
            child: Container(
              constraints: BoxConstraints(maxHeight: 250.h),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: pro.languages.map((lang) {
                    final isSelected = _selectedLangIds.contains(lang.id);
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedLangIds.remove(lang.id);
                          } else {
                            _selectedLangIds.add(lang.id);
                          }
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          vertical: 12.h,
                          horizontal: 10.w,
                        ),
                        margin: EdgeInsets.symmetric(
                          vertical: 4.h,
                          horizontal: 10.w,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFE9F5D4)
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(
                            color: isSelected
                                ? Colors.green
                                : Colors.transparent,
                            width: 1.4,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextWidget(
                                text: lang.name,
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                              ),
                            ),
                            if (isSelected)
                              Icon(
                                Icons.check_circle,
                                size: 24.sp,
                                color: Colors.green,
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _actions() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.w),
      child: Row(
        children: [
          Expanded(
            child: CustomButton(
              title: "Cancel",
              onTap: () => Navigator.pop(context),
              buttonColor: Colors.white,
              textColor: Colors.black,
              showBorder: true,
              borderRadius: 18,
              height: 40,
              stadium: false,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(width: 20.w),
          Expanded(
            child: CustomButton(
              title: _loading ? "Saving..." : "Save",
              onTap: _loading ? null : () => _onSave(),
              buttonColor: AppColors.btnClr,
              textColor: Colors.white,
              borderRadius: 18,
              height: 40,
              stadium: false,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _MyNetworkSection {
  final String title;
  final String key;
  final List<dynamic> items;

  const _MyNetworkSection({
    required this.title,
    required this.key,
    required this.items,
  });
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  _DashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rect);
    final metrics = path.computeMetrics();

    const dash = 6.0;
    const gap = 4.0;

    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dash).clamp(0, metric.length).toDouble();
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}
