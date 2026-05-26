import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:print_helper/admin/chat/models/group_participants_model.dart';
import 'package:print_helper/admin/chat/provider/chat_pro.dart';
import '../../../tab_utils/console_util.dart';
import '../../../tab_widgets/tab_custom_button.dart';
import 'package:provider/provider.dart';

import '../../../tab_constants/colors.dart';
import '../../../tab_constants/paths.dart';
import 'package:print_helper/models/search_modals.dart';
import '../../../tab_services/helpers.dart';
import '../../../tab_widgets/tab_image_widget.dart';
import '../../../tab_widgets/tab_spacers.dart';
import '../../../tab_widgets/tab_text_widget.dart';
import '../../../tab_widgets/tab_toasts.dart';

class CreateChatGroup extends StatefulWidget {
  final VoidCallback? onSuccess;
  const CreateChatGroup({super.key, this.onSuccess});

  @override
  State<CreateChatGroup> createState() => CreateChatGroupState();
}

class CreateChatGroupState extends State<CreateChatGroup>
    with SingleTickerProviderStateMixin {
  final _groupNameCntrler = TextEditingController();
  final _staffSearchCntrler = TextEditingController();
  final _clientCompanySearchCntrler = TextEditingController();
  final _clientMemberSearchCntrler = TextEditingController();

  late TabController _tabController;
  bool pickingFile = false;
  File? selectedImage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final pro = context.read<ChatPro>();
        pro.clearGroupCreationState();
        pro.fetchGroupParticipants();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _groupNameCntrler.dispose();
    _staffSearchCntrler.dispose();
    _clientCompanySearchCntrler.dispose();
    _clientMemberSearchCntrler.dispose();
    super.dispose();
  }

  Future<void> pickImage() async {
    if (pickingFile) return;
    pickingFile = true;
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'png', 'jpeg'],
      );
      if (result != null && result.files.single.path != null) {
        setState(() => selectedImage = File(result.files.single.path!));
      }
    } catch (e) {
      printData(title: 'from pickImage', data: '$e', e: true);
    } finally {
      setState(() => pickingFile = false);
    }
  }

  Future<void> _onSave() async {
    final chatPro = getChatPro(context);
    if (_groupNameCntrler.text.trim().isEmpty) {
      showToast(message: "Group name is required");
      return;
    }
    if (chatPro.selectedUsers.length < 2) {
      showToast(message: "Select at least 2 members");
      return;
    }
    final userIds = chatPro.selectedUsers.map((e) => e.id).toList();
    FocusScope.of(context).unfocus();
    final success = await chatPro.createGroup(
      title: _groupNameCntrler.text.trim(),
      userIds: userIds,
      image: selectedImage,
      context: context,
    );
    if (!mounted) return;
    if (success) {
      showToast(message: "Group Created Successfully");
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Column(
        children: [
          _header(context),
          Divider(thickness: 1, color: Colors.grey.shade200, height: 0),
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Spacers.sb20(),
                  _profileImageSection(),
                  Spacers.sb20(),
                  _buildLabel("Group Name"),
                  Spacers.sb8(),
                  _groupNameField(),
                  Spacers.sb15(),
                  _buildLabel("Add Members"),
                  Spacers.sb8(),
                  _tabBar(),
                  Spacers.sb12(),
                  AnimatedBuilder(
                    animation: _tabController,
                    builder: (context, _) {
                      if (_tabController.index == 0) {
                        return _staffsTab();
                      } else {
                        return _clientsTab();
                      }
                    },
                  ),
                  Consumer<ChatPro>(
                    builder: (context, pro, _) =>
                        _buildSelectedMembersList(pro),
                  ),
                  Spacers.sb20(),
                ],
              ),
            ),
          ),
          _bottomButtons(context),
        ],
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────

  Widget _header(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: TextWidget(
              text: "Create Group",
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.black,
            ),
          ),
          GestureDetector(
            onTap: () {
              context.read<ChatPro>().clearGroupCreationState();
              Navigator.of(context).pop();
            },
            child: Container(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close, size: 24, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Profile Image ──────────────────────────────────────────────────────────

  Widget _profileImageSection() {
    return Center(
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onTap: pickImage,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey.shade300,
                    border: Border.all(color: Colors.grey.shade300, width: 2),
                    image: selectedImage != null
                        ? DecorationImage(
                            image: FileImage(selectedImage!),
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
                  onTap: pickImage,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFCC00),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.camera_alt,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Spacers.sb8(),
          GestureDetector(
            onTap: pickImage,
            child: TextWidget(
              text: "Add group photo",
              fontSize: 13,
              color: Colors.blueGrey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Group Name Field ───────────────────────────────────────────────────────

  Widget _groupNameField() {
    return TextField(
      controller: _groupNameCntrler,
      decoration: _inputDecoration("Enter group name"),
      style: TextStyle(fontSize: 13, color: Colors.black87),
    );
  }

  // ─── Tab Bar ────────────────────────────────────────────────────────────────

  Widget _tabBar() {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.black,
        unselectedLabelColor: Colors.grey.shade600,
        labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        unselectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
        tabs: const [
          Tab(text: 'Specialist'),
          Tab(text: 'Clients'),
        ],
      ),
    );
  }

  // ─── STAFFS TAB ─────────────────────────────────────────────────────────────

  Widget _staffsTab() {
    return Consumer<ChatPro>(
      builder: (context, pro, _) {
        // Filter list against search
        final query = _staffSearchCntrler.text.toLowerCase();
        final filtered = pro.staffList.where((u) {
          if (query.isEmpty) return true;
          return u.fullName.toLowerCase().contains(query) ||
              (u.email?.toLowerCase().contains(query) ?? false);
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextWidget(
              text: 'Search Staffs',
              fontSize: 13,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
            Spacers.sb5(),
            _searchTextField(
              controller: _staffSearchCntrler,
              hint: 'Search staffs',
              onChanged: (_) => setState(() {}),
            ),
            Spacers.sb10(),
            if (pro.isFetchingGroupParticipants)
              _loadingCard()
            else if (filtered.isEmpty)
              _emptyCard('No staffs found')
            else
              _staffList(filtered, pro),
          ],
        );
      },
    );
  }

  Widget _staffList(List<SearchUsers> staffs, ChatPro pro) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: List.generate(staffs.length, (index) {
          final user = staffs[index];
          final isSelected = pro.selectedUsers.any((u) => u.id == user.id);
          final isLast = index == staffs.length - 1;
          return _staffTile(user, isSelected, isLast, pro);
        }),
      ),
    );
  }

  Widget _staffTile(
    SearchUsers user,
    bool isSelected,
    bool isLast,
    ChatPro pro,
  ) {
    return GestureDetector(
      onTap: () => pro.toggleUserSelection(user),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.btnClr.withValues(alpha: 0.06)
              : Colors.transparent,
          border: isLast
              ? null
              : Border(
                  bottom: BorderSide(color: Colors.grey.shade100, width: 1),
                ),
          borderRadius: isLast
              ? BorderRadius.only(
                  bottomLeft: Radius.circular(14),
                  bottomRight: Radius.circular(14),
                )
              : null,
        ),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            _userAvatar(user, size: 42),
            Spacers.sbw12(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextWidget(
                    text: user.fullName,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                  if (user.email != null && user.email!.isNotEmpty)
                    TextWidget(
                      text: user.email!,
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: Colors.grey.shade500,
                    ),
                ],
              ),
            ),
            _checkOrAddIcon(isSelected),
          ],
        ),
      ),
    );
  }

  // ─── CLIENTS TAB ─────────────────────────────────────────────────────────────

  Widget _clientsTab() {
    return Consumer<ChatPro>(
      builder: (context, pro, _) {
        if (pro.isFetchingGroupParticipants) return _loadingCard();

        if (pro.selectedClientCompany == null) {
          return _clientCompanyListView(pro);
        } else {
          return _clientDetailView(pro);
        }
      },
    );
  }

  // State 1: Company selection
  Widget _clientCompanyListView(ChatPro pro) {
    final query = _clientCompanySearchCntrler.text.toLowerCase();
    final filtered = pro.clientCompanies.where((c) {
      if (query.isEmpty) return true;
      return c.companyName.toLowerCase().contains(query);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextWidget(
          text: 'Search Client Companies',
          fontSize: 13,
          color: Colors.grey.shade600,
          fontWeight: FontWeight.w500,
        ),
        Spacers.sb5(),
        _searchTextField(
          controller: _clientCompanySearchCntrler,
          hint: 'Search client companies',
          onChanged: (_) => setState(() {}),
        ),
        Spacers.sb10(),
        if (filtered.isEmpty)
          _emptyCard('No clients found')
        else
          _clientCompanyList(filtered, pro),
      ],
    );
  }

  Widget _clientCompanyList(List<ClientCompanyModel> companies, ChatPro pro) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: List.generate(companies.length, (index) {
          final company = companies[index];
          final isSelected = pro.selectedClientCompany?.id == company.id;
          final isLast = index == companies.length - 1;
          return _clientCompanyTile(company, isSelected, isLast, pro);
        }),
      ),
    );
  }

  Widget _clientCompanyTile(
    ClientCompanyModel company,
    bool isSelected,
    bool isLast,
    ChatPro pro,
  ) {
    return GestureDetector(
      onTap: () {
        pro.setClientCompany(company);
        _clientMemberSearchCntrler.clear();
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0F9F0) : Colors.transparent,
          border: Border(
            left: isSelected
                ? const BorderSide(color: Colors.green, width: 3)
                : BorderSide.none,
            bottom: isLast
                ? BorderSide.none
                : BorderSide(color: Colors.grey.shade100, width: 1),
          ),
          borderRadius: isLast
              ? BorderRadius.only(
                  bottomLeft: Radius.circular(14),
                  bottomRight: Radius.circular(14),
                )
              : null,
        ),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            _companyAvatar(company),
            Spacers.sbw12(),
            Expanded(
              child: TextWidget(
                text: company.companyName,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.green : Colors.grey.shade300,
                  width: 1.5,
                ),
                color: isSelected ? Colors.green : Colors.transparent,
              ),
              child: isSelected
                  ? Icon(Icons.check, size: 13, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // State 2: Client detail view (contacts + customers)
  Widget _clientDetailView(ChatPro pro) {
    final company = pro.selectedClientCompany!;
    final query = _clientMemberSearchCntrler.text.toLowerCase();

    // Build the combined list based on filter
    List<SearchUsers> members = [];
    if (pro.selectedClientFilter == 'All') {
      members = [...company.contacts, ...company.customers];
    } else if (pro.selectedClientFilter == 'Contacts') {
      members = company.contacts;
    } else {
      members = company.customers;
    }

    if (query.isNotEmpty) {
      members = members
          .where((u) => u.fullName.toLowerCase().contains(query))
          .toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Company list with selection highlight
        _clientCompanyListView(pro),
        Spacers.sb12(),
        // Selected client card + Clear button
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextWidget(
                      text: 'SELECTED CLIENT',
                      fontSize: 10,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w600,
                    ),
                    Spacers.sb2(),
                    TextWidget(
                      text: company.companyName,
                      fontSize: 13,
                      color: Colors.black87,
                      fontWeight: FontWeight.w700,
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => pro.setClientCompany(null),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade100),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.close, size: 14, color: Colors.red.shade600),
                      Spacers.sbw5(),
                      TextWidget(
                        text: 'Clear',
                        fontSize: 12,
                        color: Colors.red.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Spacers.sb10(),
        // Member search
        _searchTextField(
          controller: _clientMemberSearchCntrler,
          hint: 'Search users by name...',
          prefixIcon: Icons.search,
          onChanged: (_) => setState(() {}),
        ),
        Spacers.sb10(),
        // Filter chips: All / Contacts / Customers
        _filterChips(pro),
        Spacers.sb10(),
        // Members list
        if (members.isEmpty)
          _emptyCard('No members found')
        else
          _clientMembersList(members, pro),
        Spacers.sb8(),
        // "Only one client per group" notice
        Row(
          children: [
            Icon(Icons.circle, size: 8, color: Colors.red.shade400),
            Spacers.sbw5(),
            TextWidget(
              text: 'ONLY ONE CLIENT PER GROUP',
              fontSize: 10,
              color: Colors.red.shade400,
              fontWeight: FontWeight.w600,
            ),
          ],
        ),
        Spacers.sb5(),
      ],
    );
  }

  Widget _filterChips(ChatPro pro) {
    const filters = ['All', 'Contacts', 'Customers'];
    return Row(
      children: filters.map((f) {
        final isActive = pro.selectedClientFilter == f;
        return Padding(
          padding: EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => pro.setClientMemberFilter(f),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: isActive ? Colors.black87 : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive ? Colors.black87 : Colors.grey.shade300,
                ),
              ),
              child: TextWidget(
                text: f,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _clientMembersList(List<SearchUsers> members, ChatPro pro) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: List.generate(members.length, (index) {
          final user = members[index];
          final isSelected = pro.selectedUsers.any((u) => u.id == user.id);
          final isLast = index == members.length - 1;
          return _clientMemberTile(user, isSelected, isLast, pro);
        }),
      ),
    );
  }

  Widget _clientMemberTile(
    SearchUsers user,
    bool isSelected,
    bool isLast,
    ChatPro pro,
  ) {
    return GestureDetector(
      onTap: () => pro.toggleUserSelection(user),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: isLast
              ? null
              : Border(
                  bottom: BorderSide(color: Colors.grey.shade100, width: 1),
                ),
        ),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            _userAvatar(user, size: 42),
            Spacers.sbw12(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextWidget(
                    text: user.fullName,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                  Spacers.sb2(),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: user.userType == 'CONTACT'
                          ? Colors.blue.shade50
                          : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: TextWidget(
                      text: user.userType,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: user.userType == 'CONTACT'
                          ? Colors.blue.shade600
                          : Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
            ),
            _checkOrAddIcon(isSelected),
          ],
        ),
      ),
    );
  }

  // ─── Added Members ──────────────────────────────────────────────────────────

  Widget _buildSelectedMembersList(ChatPro pro) {
    if (pro.selectedUsers.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Spacers.sb15(),
        _buildLabel("Added Users"),
        Spacers.sb8(),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: List.generate(pro.selectedUsers.length, (index) {
              final user = pro.selectedUsers[index];
              final isLast = index == pro.selectedUsers.length - 1;
              return _selectedMemberTile(user, pro, isLast);
            }),
          ),
        ),
      ],
    );
  }

  Widget _selectedMemberTile(SearchUsers user, ChatPro pro, bool isLast) {
    final isStaff = user.userType == 'STAFF';
    final statusText = isStaff
        ? (user.isOnline
              ? 'Online'
              : user.lastSeenAt != null
              ? 'Last seen ${_formatLastSeen(user.lastSeenAt!)}'
              : user.email ?? '')
        : user.userType;

    return Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: Colors.grey.shade100, width: 1)),
      ),
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          // Avatar with online dot for staff
          Stack(
            clipBehavior: Clip.none,
            children: [
              _userAvatar(user, size: 44),
              if (isStaff)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: user.isOnline
                          ? Colors.green
                          : Colors.grey.shade400,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          Spacers.sbw12(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextWidget(
                  text: user.fullName,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.black87,
                ),
                Spacers.sb2(),
                TextWidget(
                  text: statusText,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: (isStaff && user.isOnline)
                      ? Colors.green
                      : Colors.grey.shade500,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => pro.removeSelectedUser(user),
            child: Container(
              padding: EdgeInsets.all(6),
              child: ImageWidget(image: Paths.delete, width: 20, height: 20),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  String _formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final diff = now.difference(lastSeen);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    final month = [
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
    ][lastSeen.month - 1];
    return '$month ${lastSeen.day}';
  }

  Widget _userAvatar(SearchUsers user, {double size = 42}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(50),
      child: ImageWidget(
        image: user.image != null && user.image!.isNotEmpty
            ? user.image!
            : Paths.user,
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _companyAvatar(ClientCompanyModel company) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(50),
      child: ImageWidget(
        image: company.image != null && company.image!.isNotEmpty
            ? company.image!
            : Paths.user,
        width: 42,
        height: 42,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _checkOrAddIcon(bool isSelected) {
    if (isSelected) {
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade300, width: 1.5),
        ),
        child: Icon(Icons.check, size: 14, color: Colors.grey.shade600),
      );
    }
    return Container(
      width: 28,
      height: 28,
      decoration: const BoxDecoration(
        color: AppColors.btnClr,
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.add, size: 16, color: Colors.white),
    );
  }

  Widget _loadingCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _emptyCard(String msg) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: TextWidget(
          text: msg,
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: Colors.grey.shade500,
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return TextWidget(
      text: text,
      color: Colors.black87,
      fontWeight: FontWeight.w700,
      fontSize: 13,
    );
  }

  Widget _searchTextField({
    required TextEditingController controller,
    required String hint,
    required ValueChanged<String> onChanged,
    IconData? prefixIcon,
  }) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, size: 18, color: Colors.grey.shade400)
            : null,
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.grey),
        ),
      ),
      style: TextStyle(fontSize: 13, color: Colors.black87),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
      filled: true,
      fillColor: Colors.white,
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.grey),
      ),
    );
  }

  // ─── Bottom Buttons ─────────────────────────────────────────────────────────

  Widget _bottomButtons(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: CustomButton(
              height: 44,
              textColor: AppColors.black,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              showBorder: true,
              buttonColor: Colors.white,
              stadium: false,
              borderRadius: 22,
              borderWidth: 1.5,
              title: 'Cancel',
              onTap: () {
                context.read<ChatPro>().clearGroupCreationState();
                Navigator.of(context).pop();
              },
            ),
          ),
          Spacers.sbw12(),
          Expanded(
            child: CustomButton(
              height: 44,
              title: 'Create Group',
              onTap: _onSave,
              buttonColor: AppColors.btnClr,
              textColor: AppColors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              stadium: false,
              borderRadius: 22,
            ),
          ),
        ],
      ),
    );
  }
}
