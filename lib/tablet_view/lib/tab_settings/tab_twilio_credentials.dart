import 'package:flutter/material.dart';
import '../tab_constants/colors.dart';
import '../tab_constants/paths.dart';
import 'package:print_helper/models/twilio_models.dart';
import '../tab_widgets/tab_image_widget.dart';
import 'package:provider/provider.dart';
import 'package:print_helper/admin/chat/provider/chat_pro.dart';
import '../tab_widgets/loaders.dart';
import '../tab_widgets/tab_text_widget.dart';
import '../tab_widgets/tab_spacers.dart';

class TwilioCredentialsWeb extends StatefulWidget {
  const TwilioCredentialsWeb({super.key});

  @override
  State<TwilioCredentialsWeb> createState() => _TwilioCredentialsWebState();
}

class _TwilioCredentialsWebState extends State<TwilioCredentialsWeb> {
  final _phoneSearchController = TextEditingController();
  final _companySearchController = TextEditingController();
  final _contactSearchController = TextEditingController();
  final _accountSearchController = TextEditingController();

  // Twilio Credentials Form Controllers
  final _accountSidController = TextEditingController();
  final _apiKeySidController = TextEditingController();
  final _apiKeySecretController = TextEditingController();
  final _twimlAppSidController = TextEditingController();

  late Map<int, bool> expandedClients;
  bool _didSyncSelections = false;
  bool _didUserModify = false;
  String? _lastSyncKey;
  bool _didSyncCredentials = false;
  final Map<int, List<AssignedAccount>> _staffByClientCache = {};

  Future<void> _ensureStaffForClient(
    int? clientId, {
    TwilioCredential? credential,
  }) async {
    if (clientId == null) return;

    List<AssignedAccount> staffList = [];
    if (_staffByClientCache.containsKey(clientId)) {
      staffList = _staffByClientCache[clientId]!;
    } else {
      final chatPro = Provider.of<ChatPro>(context, listen: false);
      staffList = await chatPro.fetchStaffByClient(clientId: clientId);
      if (mounted) {
        setState(() {
          _staffByClientCache[clientId] = staffList;
        });
      }
    }

    if (credential != null && mounted) {
      setState(() {
        final validIds = staffList.map((s) => s.id).toSet();
        credential.assignedAccounts.removeWhere(
          (acc) => !validIds.contains(acc.id),
        );
      });
    }
  }

  @override
  void initState() {
    super.initState();
    expandedClients = {};
    _didSyncSelections = false;
    _didUserModify = false;
    _lastSyncKey = null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatPro = Provider.of<ChatPro>(context, listen: false);
      // Load Twilio data from main ChatPro
      chatPro.fetchTwilioNumbers();
      chatPro.fetchTwilioClientsWithContacts();
      chatPro.fetchTwilioStaff();
      chatPro.fetchTwilioCredentials();
    });
  }

  @override
  void dispose() {
    _phoneSearchController.dispose();
    _companySearchController.dispose();
    _contactSearchController.dispose();
    _accountSearchController.dispose();
    _accountSidController.dispose();
    _apiKeySidController.dispose();
    _apiKeySecretController.dispose();
    _twimlAppSidController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatPro>(
      builder: (context, chatPro, _) {
        final twilioCredentials = chatPro.twilioNumbers;
        final syncKey =
            '${chatPro.twilioNumbersRevision}|${chatPro.twilioClientsRevision}|${chatPro.twilioStaffRevision}';
        if (_lastSyncKey != syncKey) {
          _lastSyncKey = syncKey;
          _didSyncSelections = false;
        }
        final shouldSyncSelections =
            !_didSyncSelections &&
            !_didUserModify &&
            !chatPro.isTwilioLoading &&
            !chatPro.twilioHasError &&
            !chatPro.isTwilioClientsLoading &&
            !chatPro.twilioClientsHasError &&
            !chatPro.isTwilioStaffLoading &&
            !chatPro.twilioStaffHasError &&
            twilioCredentials.isNotEmpty;
        if (shouldSyncSelections) {
          _didSyncSelections = true;
          _syncSelectionsFromApi(chatPro);
        }
        // Credentials sync not available in consolidated ChatPro - using API directly

        final shouldSyncCredentials =
            !_didSyncCredentials &&
            !chatPro.isTwilioCredentialsLoading &&
            !chatPro.twilioCredentialsHasError &&
            (chatPro.twilioAccountSid != null ||
                chatPro.twilioApiKeySid != null ||
                chatPro.twilioApiKeySecret != null ||
                chatPro.twilioTwimlAppSid != null);
        if (shouldSyncCredentials) {
          _didSyncCredentials = true;
          _accountSidController.text = chatPro.twilioAccountSid ?? '';
          _apiKeySidController.text = chatPro.twilioApiKeySid ?? '';
          _apiKeySecretController.text = chatPro.twilioApiKeySecret ?? '';
          _twimlAppSidController.text = chatPro.twilioTwimlAppSid ?? '';
        }

        return Container(
          decoration: BoxDecoration(color: Colors.white),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300, width: 1),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextWidget(
                        text: "Twilio Credentials",
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Spacers.sbw10(),

                    // View Settings button removed - Twilio credentials management not available in consolidated ChatPro
                    GestureDetector(
                      onTap: () {
                        _showTwilioCredentialsDialog();
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFFFC400),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: TextWidget(
                            text: "View Settings",
                            fontWeight: FontWeight.w500,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),

                    Spacers.sbw10(),

                    // Sync button removed - syncTwilioNumbers not available in consolidated ChatPro
                    GestureDetector(
                      onTap: () {
                        if (!chatPro.isTwilioSyncing) {
                          Provider.of<ChatPro>(
                            context,
                            listen: false,
                          ).syncTwilioNumbers();
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: Center(
                          child: chatPro.isTwilioSyncing
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: showLoader(size: 16),
                                )
                              : Icon(Icons.replay_rounded, color: Colors.black),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Search Filters - Single Row
              Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildSearchField(
                        controller: _phoneSearchController,
                        hint: "Type phone",
                        onChanged: (_) => _maybeResetSearch(),
                      ),
                    ),
                    Spacers.sbw8(),
                    Expanded(
                      child: _buildSearchField(
                        controller: _companySearchController,
                        hint: "Type client's company name",
                        onChanged: (_) => _maybeResetSearch(),
                      ),
                    ),
                    Spacers.sbw8(),
                    Expanded(
                      child: _buildSearchField(
                        controller: _contactSearchController,
                        hint: "Type client's contact name",
                        onChanged: (_) => _maybeResetSearch(),
                      ),
                    ),
                    Spacers.sbw8(),
                    Expanded(
                      child: _buildSearchField(
                        controller: _accountSearchController,
                        hint: "Type account name",
                        onChanged: (_) => _maybeResetSearch(),
                      ),
                    ),
                    Spacers.sbw8(),
                    GestureDetector(
                      onTap: () {
                        Provider.of<ChatPro>(
                          context,
                          listen: false,
                        ).fetchTwilioNumbersTab(
                          page: 1,
                          phone: _phoneSearchController.text,
                          client: _companySearchController.text,
                          contact: _contactSearchController.text,
                          account: _accountSearchController.text,
                        );
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFC400),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ImageWidget(
                          image: Paths.search,
                          width: 20,
                          height: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Table View
              Expanded(
                child: chatPro.isTwilioLoading
                    ? Center(child: showLoader())
                    : chatPro.twilioHasError
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 48,
                              color: Colors.red,
                            ),
                            Spacers.sb15(),
                            TextWidget(
                              text: 'Failed to load Twilio numbers',
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.red,
                            ),
                            Spacers.sb15(),
                            ElevatedButton(
                              onPressed: () => chatPro.fetchTwilioNumbers(),
                              child: const TextWidget(
                                text: 'Retry',
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : twilioCredentials.isEmpty
                    ? Center(
                        child: TextWidget(
                          text: 'No Twilio numbers available',
                          fontSize: 14,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      )
                    : SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              margin: const EdgeInsets.all(12),
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Color(0xfff1f1f2),
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  topRight: Radius.circular(12),
                                ),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 150,
                                    child: TextWidget(
                                      text: "Number",
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: TextWidget(
                                      text: "Assigned Client's Contact(s)",
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: TextWidget(
                                      text: "Assigned Account(s)",
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Table Rows
                            ...twilioCredentials.asMap().entries.map((entry) {
                              final credential = entry.value;
                              final isEvenRow = entry.key % 2 == 0;
                              return _buildTableRow(credential, isEvenRow);
                            }),
                          ],
                        ),
                      ),
              ),

              // Pagination removed - not supported in consolidated ChatPro.fetchTwilioNumbers
              if (!chatPro.isTwilioLoading &&
                  !chatPro.twilioHasError &&
                  twilioCredentials.isNotEmpty)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade300, width: 1),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // First page button
                      _buildPaginationButton(
                        icon: Icons.keyboard_double_arrow_left,
                        onTap: () {
                          if (chatPro.twilioCurrentPage > 1) {
                            chatPro.fetchTwilioNumbersTab(page: 1);
                          }
                        },
                        enabled: chatPro.twilioCurrentPage > 1,
                      ),
                      SizedBox(width: 8),
                      // Previous page button
                      _buildPaginationButton(
                        icon: Icons.chevron_left,
                        onTap: () {
                          if (chatPro.twilioCurrentPage > 1) {
                            chatPro.fetchTwilioNumbersTab(
                              page: chatPro.twilioCurrentPage - 1,
                            );
                          }
                        },
                        enabled: chatPro.twilioCurrentPage > 1,
                      ),
                      SizedBox(width: 12),
                      // Dynamic page numbers
                      ..._buildPageNumbers(chatPro),
                      SizedBox(width: 12),
                      // Next page button
                      _buildPaginationButton(
                        icon: Icons.chevron_right,
                        onTap: () {
                          if (chatPro.twilioCurrentPage <
                              chatPro.twilioLastPage) {
                            chatPro.fetchTwilioNumbersTab(
                              page: chatPro.twilioCurrentPage + 1,
                            );
                          }
                        },
                        enabled:
                            chatPro.twilioCurrentPage < chatPro.twilioLastPage,
                      ),
                      SizedBox(width: 8),
                      // Last page button
                      _buildPaginationButton(
                        icon: Icons.keyboard_double_arrow_right,
                        onTap: () {
                          if (chatPro.twilioCurrentPage <
                              chatPro.twilioLastPage) {
                            chatPro.fetchTwilioNumbersTab(
                              page: chatPro.twilioLastPage,
                            );
                          }
                        },
                        enabled:
                            chatPro.twilioCurrentPage < chatPro.twilioLastPage,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchField({
    required TextEditingController controller,
    required String hint,
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      height: 40,
      padding: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 12, color: Colors.black87),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  void _maybeResetSearch() {
    final isAllEmpty =
        _phoneSearchController.text.trim().isEmpty &&
        _companySearchController.text.trim().isEmpty &&
        _contactSearchController.text.trim().isEmpty &&
        _accountSearchController.text.trim().isEmpty;
    if (isAllEmpty) {
      Provider.of<ChatPro>(context, listen: false).fetchTwilioNumbers(
        // page: 1, // page parameter not supported in consolidated ChatPro
        phone: '',
        client: '',
        contact: '',
        account: '',
      );
    }
  }

  void _syncSelectionsFromApi(ChatPro chatPro) {
    for (final credential in chatPro.twilioNumbers) {
      final dynamic client = credential.client;
      if (credential.selectedClientId == null && client is Map) {
        credential.selectedClientId = client['id'] as int?;
      }

      if (credential.selectedContactIds.isEmpty &&
          credential.assignedClients.isNotEmpty) {
        credential.selectedContactIds = credential.assignedClients
            .map((contact) => contact.id)
            .toList();
      }

      if (credential.assignedAccounts.isNotEmpty) {
        credential.assignedAccounts = credential.assignedAccounts
            .map((account) => account.copyWith(isSelected: true))
            .toList();
      }
      if (credential.selectedClientId != null) {
        _ensureStaffForClient(credential.selectedClientId);
      }
    }
  }

  Future<void> _saveTwilioAssignments(TwilioCredential credential) async {
    _didUserModify = true;
    final chatPro = Provider.of<ChatPro>(context, listen: false);
    final accountIds = credential.assignedAccounts.map((a) => a.id).toList();
    await chatPro.updateTwilioNumberAssignments(
      numberId: credential.id,
      clientId: credential.selectedClientId,
      contactIds: credential.selectedContactIds,
      accountIds: accountIds,
    );
  }

  Widget _buildTableRow(TwilioCredential credential, bool isEvenRow) {
    return Container(
      margin: const EdgeInsets.only(left: 10, right: 10),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: const Color(0x5E9E9E9E), width: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 150,
            child: TextWidget(
              text: credential.phoneNumber,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          // Clients Contact Column
          Expanded(flex: 2, child: _buildClientsCellDropdown(credential)),
          Spacers.sbw12(),
          Expanded(flex: 2, child: _buildAccountsCellDropdown(credential)),
        ],
      ),
    );
  }

  Widget _buildClientsCellDropdown(TwilioCredential credential) {
    final chatPro = Provider.of<ChatPro>(context);
    final selectedClient = credential.selectedClientId != null
        ? chatPro.twilioClients.firstWhere(
            (c) => c.id == credential.selectedClientId,
            orElse: () => TwilioClient(
              id: -1,
              name: '',
              image: null,
              isCompany: false,
              contacts: [],
            ),
          )
        : null;
    final selectedContacts = selectedClient != null
        ? selectedClient.contacts
              .where(
                (contact) => credential.selectedContactIds.contains(contact.id),
              )
              .toList()
        : [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Builder(
          builder: (context) {
            return GestureDetector(
              onTap: () {
                final RenderBox button =
                    context.findRenderObject() as RenderBox;
                final RenderBox overlay =
                    Overlay.of(context).context.findRenderObject() as RenderBox;
                final RelativeRect position = RelativeRect.fromRect(
                  Rect.fromPoints(
                    button.localToGlobal(Offset.zero, ancestor: overlay),
                    button.localToGlobal(
                      button.size.bottomRight(Offset.zero),
                      ancestor: overlay,
                    ),
                  ),
                  Offset.zero & overlay.size,
                );
                _showClientMenu(
                  context: context,
                  position: position,
                  credential: credential,
                  chatPro: chatPro,
                );
              },
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical:
                      selectedClient != null && selectedClient.id != -1 ||
                          selectedContacts.isNotEmpty
                      ? 5
                      : 14,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                  color: Colors.white,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Expanded(
                      child:
                          (selectedClient != null && selectedClient.id != -1 ||
                              selectedContacts.isNotEmpty)
                          ? Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                if (selectedClient != null &&
                                    selectedClient.id != -1)
                                  _buildChip(
                                    label: selectedClient.name,
                                    image: selectedClient.image,
                                    onDelete: () {
                                      setState(() {
                                        credential.selectedClientId = null;
                                        credential.selectedContactIds = [];
                                      });
                                      _saveTwilioAssignments(credential);
                                    },
                                    backgroundColor: AppColors.primary,
                                  ),
                                ...selectedContacts.map((contact) {
                                  return _buildChip(
                                    label: contact.name,
                                    image: contact.image,
                                    onDelete: () {
                                      setState(() {
                                        credential.selectedContactIds
                                            .removeWhere(
                                              (id) => id == contact.id,
                                            );
                                      });
                                      _saveTwilioAssignments(credential);
                                    },
                                    backgroundColor: const Color(0xFFd2e28b),
                                  );
                                }),
                              ],
                            )
                          : SizedBox.shrink(),
                    ),
                    SizedBox(width: 8),
                    ImageWidget(image: Paths.down, width: 11),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAccountsCellDropdown(TwilioCredential credential) {
    final chatPro = Provider.of<ChatPro>(context, listen: false);
    final selectedAccounts = credential.assignedAccounts
        .where((account) => account.isSelected)
        .toList();
    return PopupMenuButton<AssignedAccount>(
      offset: Offset(0, 45),
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      constraints: BoxConstraints(maxWidth: 280, minWidth: 280),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
          color: Colors.white,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: selectedAccounts.isNotEmpty
                  ? Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: selectedAccounts
                          .map(
                            (account) => _buildChip(
                              label: account.accountName,
                              image: account.image,
                              onDelete: () {
                                setState(() {
                                  credential.assignedAccounts.removeWhere(
                                    (acc) => acc.id == account.id,
                                  );
                                });
                                _saveTwilioAssignments(credential);
                              },
                              backgroundColor: const Color(0xFFd2e28b),
                            ),
                          )
                          .toList(),
                    )
                  : SizedBox.shrink(),
            ),
            SizedBox(width: 8),
            ImageWidget(image: Paths.down, width: 11),
          ],
        ),
      ),
      itemBuilder: (context) {
        return [
          PopupMenuItem<AssignedAccount>(
            enabled: false,
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: TextField(
                decoration: InputDecoration(
                  hintText: "Search Accounts",
                  hintStyle: const TextStyle(fontSize: 10),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  prefixIcon: Icon(Icons.search, size: 26),
                ),
              ),
            ),
          ),
          PopupMenuItem<AssignedAccount>(
            enabled: false,
            padding: EdgeInsets.zero,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 250),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children:
                      (credential.selectedClientId != null
                              ? _staffByClientCache[credential
                                        .selectedClientId] ??
                                    []
                              : chatPro.twilioStaff)
                          .map((staff) {
                            final isSelected = credential.assignedAccounts.any(
                              (account) => account.id == staff.id,
                            );
                            return InkWell(
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    credential.assignedAccounts.removeWhere(
                                      (account) => account.id == staff.id,
                                    );
                                  } else {
                                    credential.assignedAccounts.add(
                                      AssignedAccount(
                                        id: staff.id,
                                        accountName: staff.accountName,
                                        image: staff.image,
                                        isSelected: true,
                                      ),
                                    );
                                  }
                                });
                                _saveTwilioAssignments(credential);
                              },
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFFE8F5E9)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            30,
                                          ),
                                          child: ImageWidget(
                                            image:
                                                staff.image
                                                        .toString()
                                                        .isEmpty ||
                                                    staff.image == null
                                                ? Paths.user
                                                : staff.image.toString(),
                                            fit: BoxFit.cover,
                                            width: 28,
                                            height: 28,
                                          ),
                                        ),
                                        Spacers.sbw8(),
                                        Expanded(
                                          child: TextWidget(
                                            text: staff.accountName,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        if (isSelected)
                                          Icon(
                                            Icons.check_circle,
                                            color: Colors.green,
                                            size: 18,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          })
                          .toList(),
                ),
              ),
            ),
          ),
        ];
      },
    );
  }

  Widget _buildChip({
    required String label,
    String? image,
    required VoidCallback onDelete,
    required Color backgroundColor,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: backgroundColor == AppColors.primary
              ? const Color(0xFFFFC400)
              : Colors.green.shade300,
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: ImageWidget(
              image: image == null || image.isEmpty ? Paths.user : image,
              fit: BoxFit.cover,
              width: 24,
              height: 24,
            ),
          ),
          Spacers.sbw5(),
          TextWidget(text: label, fontSize: 10, fontWeight: FontWeight.w500),
          Spacers.sbw5(),
          GestureDetector(
            onTap: onDelete,
            child: ImageWidget(
              image: Paths.delete,
              width: 13,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientListItem(
    TwilioClient client,
    TwilioCredential credential,
  ) {
    final isSelected = credential.selectedClientId == client.id;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFE8F5E9) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? Colors.green.shade300 : Colors.grey.shade300,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: const Color(0xFF00BCD4),
            backgroundImage: client.image != null && client.image!.isNotEmpty
                ? NetworkImage(client.image!)
                : null,
            child: client.image == null || client.image!.isEmpty
                ? TextWidget(
                    text: client.name.isNotEmpty
                        ? client.name[0].toUpperCase()
                        : 'C',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  )
                : null,
          ),
          Spacers.sbw10(),
          Expanded(
            child: TextWidget(
              text: client.name,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          if (client.contacts.isNotEmpty)
            Icon(Icons.expand_more, size: 20, color: Colors.grey.shade600),
        ],
      ),
    );
  }

  Widget _buildContactListItem(
    TwilioContact contact,
    TwilioCredential credential,
  ) {
    final isSelected = credential.selectedContactIds.contains(contact.id);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFE8F5E9) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? Colors.green.shade300 : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Contact avatar
          ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: ImageWidget(
              image: contact.image.toString().isEmpty || contact.image == null
                  ? Paths.user
                  : contact.image.toString(),
              fit: BoxFit.cover,
              width: 28,
              height: 28,
            ),
          ),
          Spacers.sbw10(),
          // Contact name
          Expanded(
            child: TextWidget(
              text: contact.name,
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          // Selection indicator
          if (isSelected)
            Icon(Icons.check_circle, color: Colors.green, size: 18),
        ],
      ),
    );
  }

  void _showClientMenu({
    required BuildContext context,
    required RelativeRect position,
    required TwilioCredential credential,
    required ChatPro chatPro,
  }) {
    showMenu<void>(
      context: context,
      position: position,
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      constraints: BoxConstraints(maxWidth: 320, minWidth: 320, maxHeight: 500),
      items: [
        PopupMenuItem(
          enabled: false,
          padding: EdgeInsets.zero,
          child: StatefulBuilder(
            builder: (context, setMenuState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // SEARCH
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: "Search Client's Company",
                          hintStyle: const TextStyle(fontSize: 12),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          prefixIcon: Icon(Icons.search, size: 22),
                        ),
                      ),
                    ),
                  ),
                  // CLIENTS + CONTACTS
                  ...chatPro.twilioClients.expand((client) {
                    final isClientSelected =
                        credential.selectedClientId == client.id;
                    return [
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        child: GestureDetector(
                          onTap: () async {
                            setState(() {
                              if (isClientSelected) {
                                credential.selectedClientId = null;
                                credential.selectedContactIds = <int>[];
                              } else {
                                credential.selectedClientId = client.id;
                                credential.selectedContactIds = <int>[];
                              }
                            });
                            setMenuState(() {});
                            if (credential.selectedClientId != null) {
                              await _ensureStaffForClient(
                                credential.selectedClientId,
                                credential: credential,
                              );
                            }
                            _saveTwilioAssignments(credential);
                          },
                          child: _buildClientListItem(client, credential),
                        ),
                      ),

                      if (isClientSelected)
                        ...client.contacts.map((contact) {
                          final isSelected = credential.selectedContactIds
                              .contains(contact.id);

                          return Padding(
                            padding: EdgeInsets.only(
                              left: 30,
                              right: 10,
                              top: 4,
                              bottom: 4,
                            ),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    credential.selectedContactIds = credential
                                        .selectedContactIds
                                        .where((id) => id != contact.id)
                                        .toList();
                                  } else {
                                    credential.selectedContactIds = [
                                      ...credential.selectedContactIds,
                                      contact.id,
                                    ];
                                  }
                                });
                                setMenuState(() {});
                                _saveTwilioAssignments(credential);
                              },
                              child: _buildContactListItem(contact, credential),
                            ),
                          );
                        }),
                    ];
                  }),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  //  Pagination methods removed - not supported in consolidated ChatPro

  List<Widget> _buildPageNumbers(ChatPro chatPro) {
    List<Widget> pageWidgets = [];
    int currentPage = chatPro.twilioCurrentPage;
    int lastPage = chatPro.twilioLastPage;

    // Always show first page
    pageWidgets.add(_buildPageNumber(1, chatPro));

    if (lastPage <= 1) return pageWidgets;

    // Show pages around current page
    if (currentPage > 3) {
      pageWidgets.add(SizedBox(width: 8));
      pageWidgets.add(
        TextWidget(
          text: "...",
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: Colors.grey.shade600,
        ),
      );
    }

    int start = currentPage > 2 ? currentPage - 1 : 2;
    int end = currentPage < lastPage - 1 ? currentPage + 1 : lastPage - 1;

    for (int i = start; i <= end; i++) {
      if (i > 1 && i < lastPage) {
        pageWidgets.add(SizedBox(width: 8));
        pageWidgets.add(_buildPageNumber(i, chatPro));
      }
    }

    // Show ellipsis before last page if needed
    if (currentPage < lastPage - 2) {
      pageWidgets.add(SizedBox(width: 8));
      pageWidgets.add(
        TextWidget(
          text: "...",
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: Colors.grey.shade600,
        ),
      );
    }

    // Always show last page if more than 1 page
    if (lastPage > 1) {
      pageWidgets.add(SizedBox(width: 8));
      pageWidgets.add(_buildPageNumber(lastPage, chatPro));
    }

    return pageWidgets;
  }

  Widget _buildPaginationButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool enabled,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: enabled ? Colors.grey.shade300 : Colors.grey.shade200,
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? Colors.grey.shade700 : Colors.grey.shade300,
        ),
      ),
    );
  }

  Widget _buildPageNumber(int pageNumber, ChatPro chatPro) {
    final bool isActive = chatPro.twilioCurrentPage == pageNumber;
    return GestureDetector(
      onTap: () {
        chatPro.fetchTwilioNumbersTab(page: pageNumber);
      },
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isActive ? Color(0xFFFFC400) : Colors.white,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: isActive ? Color(0xFFFFC400) : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Center(
          child: TextWidget(
            text: pageNumber.toString(),
            fontSize: 14,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            color: isActive ? Colors.black : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  void _showTwilioCredentialsDialog() {
    // This method is disabled - Twilio credentials management not available
    // in consolidated ChatPro. Feature moved to backend API.
    final chatPro = Provider.of<ChatPro>(context, listen: false);
    if (!chatPro.isTwilioCredentialsLoading &&
        (chatPro.twilioAccountSid == null &&
            chatPro.twilioApiKeySid == null &&
            chatPro.twilioApiKeySecret == null &&
            chatPro.twilioTwimlAppSid == null)) {
      chatPro.fetchTwilioCredentials();
    }
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          alignment: Alignment.topRight,
          insetPadding: EdgeInsets.only(right: 0, top: 0),
          child: Container(
            width: 360,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30),
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.only(left: 20, right: 20, top: 15),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextWidget(
                        text: "Twilio Credentials",
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Icon(Icons.close, size: 24),
                      ),
                    ],
                  ),
                ),
                Divider(),
                _buildCredentialField(
                  "Account SID",
                  _accountSidController,
                  false,
                ),
                SizedBox(height: 10),
                _buildCredentialField(
                  "API Key SID",
                  _apiKeySidController,
                  false,
                ),
                SizedBox(height: 10),
                _buildCredentialField(
                  "API Key Secret",
                  _apiKeySecretController,
                  true,
                ),
                SizedBox(height: 10),
                _buildCredentialField(
                  "TwiML App SID",
                  _twimlAppSidController,
                  false,
                ),
                SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey, width: 1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: TextWidget(
                          text: "Cancel",
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Color(0xFFFFC400),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: TextWidget(
                          text: "Save",
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    SizedBox(width: 24),
                  ],
                ),
                SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCredentialField(
    String label,
    TextEditingController controller,
    bool obscureText,
  ) {
    return Padding(
      padding: const EdgeInsets.only(left: 15, right: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 15),
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                  TextSpan(
                    text: ' *',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 8),
          TextField(
            controller: controller,
            obscureText: obscureText,
            style: TextStyle(
              fontSize: 14,
              color: Colors.black,
              fontWeight: FontWeight.w400,
            ),
            decoration: InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
