import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:print_helper/constants/colors.dart';
import 'package:print_helper/constants/paths.dart';
import 'package:print_helper/models/email_models.dart';
import 'package:print_helper/providers/email_pro.dart';
import 'package:print_helper/widgets/toasts.dart';
import 'package:provider/provider.dart';
import 'mobile_email_detail_screen.dart';
import 'mobile_email_compose_screen.dart';

class MobileEmailScreen extends StatefulWidget {
  const MobileEmailScreen({super.key});

  @override
  State<MobileEmailScreen> createState() => _MobileEmailScreenState();
}

class _MobileEmailScreenState extends State<MobileEmailScreen>
    with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _folderController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  bool _isSearching = false;
  String? _sectionTitleOverride;

  // Selection / move-to-folder
  final Set<String> _selectedIds = {};
  int? _moveToFolderId;

  String _resolveSectionTitle(EmailPro emailPro) {
    if (_sectionTitleOverride != null &&
        _sectionTitleOverride!.trim().isNotEmpty) {
      return _sectionTitleOverride!;
    }

    final folder = emailPro.selectedFolder.trim();
    if (folder.isEmpty) return 'Primary';

    final lower = folder.toLowerCase();
    switch (lower) {
      case 'inbox':
        return 'Inbox';
      case 'sent':
        return 'Sent';
      case 'drafts':
        return 'Drafts';
      case 'outbox':
        return 'Outbox';
      default:
        return folder;
    }
  }

  bool _canCompose(EmailPro emailPro) {
    final data = emailPro.emailData;
    if (data == null ||
        data.connectRequired ||
        data.selectedAccountId == null) {
      return false;
    }
    return data.accounts.any(
      (account) => account.isCurrent && account.isLoggedIn,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<EmailPro>().fetchMailData(context);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<EmailPro>().fetchMailData(context);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _searchFocus.dispose();
    _folderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final emailPro = context.watch<EmailPro>();
    final canCompose = _canCompose(emailPro);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Consumer<EmailPro>(
        builder: (context, emailPro, _) {
          if (emailPro.isLoading && emailPro.emailData == null) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.amber),
            );
          }

          // Show connect view if explicitly adding account (even if emailData is null)
          if (emailPro.isAddingAccount || emailPro.connectionError != null) {
            return SafeArea(child: _buildConnectView(context, emailPro));
          }

          if (emailPro.emailData == null) {
            return _buildLoadError(context, emailPro);
          }

          final bool needsConnect = emailPro.emailData!.connectRequired;

          if (needsConnect) {
            return SafeArea(child: _buildConnectView(context, emailPro));
          }

          return SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWidePhone = constraints.maxWidth >= 560;
                return Column(
                  children: [
                    _buildHeader(context, emailPro),
                    Expanded(
                      child: _buildMessages(context, emailPro, isWidePhone),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
      floatingActionButton:
          canCompose &&
              _selectedIds.isEmpty &&
              !(context.watch<EmailPro>().emailData?.connectRequired == true ||
                  context.watch<EmailPro>().isAddingAccount ||
                  context.watch<EmailPro>().connectionError != null)
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MobileEmailComposeScreen(),
                ),
              ),
              backgroundColor: const Color(0xFFFBBC04),
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              icon: const Icon(Icons.edit_outlined, color: Color(0xFF202124)),
              label: const Text(
                'Compose',
                style: TextStyle(
                  color: Color(0xFF202124),
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildLoadError(BuildContext context, EmailPro emailPro) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.mail_outline_rounded,
              size: 56,
              color: Colors.grey,
            ),
            const SizedBox(height: 12),
            const Text(
              'Could not load emails right now.',
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => emailPro.fetchMailData(context),
              style: FilledButton.styleFrom(backgroundColor: AppColors.amber),
              child: const Text('Retry'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () {
                emailPro.isAddingAccount = true;
                emailPro.connectionError = null;
                emailPro.refresh();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.amber,
                side: const BorderSide(color: AppColors.amber),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              icon: const Icon(Icons.login_rounded, size: 16),
              label: const Text('Re-login to mailbox'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, EmailPro emailPro) {
    final accounts = emailPro.emailData?.accounts ?? [];
    final selectedId = emailPro.emailData?.selectedAccountId;

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: _isSearching
          ? Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF5F6368)),
                  onPressed: () {
                    setState(() {
                      _isSearching = false;
                      _searchController.clear();
                    });
                    emailPro.searchMail(context, '');
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocus,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF202124),
                    ),
                    onSubmitted: (value) => emailPro.searchMail(context, value),
                    onChanged: (value) {
                      if (value.isEmpty) emailPro.searchMail(context, '');
                    },
                    decoration: const InputDecoration(
                      hintText: 'Search in mail',
                      hintStyle: TextStyle(color: Color(0xFF9AA0A6)),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _searchController,
                  builder: (_, val, _) => val.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Color(0xFF5F6368),
                          ),
                          onPressed: () {
                            _searchController.clear();
                            emailPro.searchMail(context, '');
                            _searchFocus.requestFocus();
                          },
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            )
          : Row(
              children: [
                IconButton(
                  onPressed: () => _openMailboxSidePanel(context, emailPro),
                  icon: const Icon(
                    Icons.menu_rounded,
                    color: Color(0xFF5F6368),
                  ),
                ),
                Expanded(
                  child: Text(
                    _resolveSectionTitle(emailPro),
                    style: const TextStyle(
                      color: Color(0xFF202124),
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _isSearching = true),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.amber,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.search_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _openMailboxSidePanel(
    BuildContext context,
    EmailPro emailPro,
  ) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'email-side-panel',
      barrierColor: Colors.black.withValues(alpha: 0.22),
      transitionDuration: const Duration(milliseconds: 220),
      transitionBuilder: (_, anim, _, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(-1, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
      pageBuilder: (ctx, _, _) {
        final customFolders =
            emailPro.emailData?.mailFolders ?? const <MailFolder>[];
        return Align(
          alignment: Alignment.centerLeft,
          child: Material(
            color: const Color(0xFFF8F9FB),
            child: SafeArea(
              right: false,
              child: Container(
                width: 300,
                height: double.infinity,
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSidePanelItem(
                        icon: Icons.folder_open_outlined,
                        label: 'Inbox',
                        active:
                            emailPro.selectedFolder == 'inbox' &&
                            emailPro.selectedFolderId == null,
                        onTap: () {
                          setState(() {
                            _sectionTitleOverride = null;
                            _selectedIds.clear();
                            _moveToFolderId = null;
                          });
                          emailPro.setFolder(context, 'inbox');
                          Navigator.pop(ctx);
                        },
                      ),
                      _buildSidePanelItem(
                        icon: Icons.near_me_outlined,
                        label: 'Sent',
                        active:
                            emailPro.selectedFolder == 'sent' &&
                            emailPro.selectedFolderId == null,
                        onTap: () {
                          setState(() {
                            _sectionTitleOverride = null;
                            _selectedIds.clear();
                            _moveToFolderId = null;
                          });
                          emailPro.setFolder(context, 'sent');
                          Navigator.pop(ctx);
                        },
                      ),
                      _buildSidePanelItem(
                        icon: Icons.article_outlined,
                        label: 'Drafts',
                        active:
                            emailPro.selectedFolder == 'drafts' &&
                            emailPro.selectedFolderId == null,
                        onTap: () {
                          setState(() {
                            _sectionTitleOverride = null;
                            _selectedIds.clear();
                            _moveToFolderId = null;
                          });
                          emailPro.setFolder(context, 'drafts');
                          Navigator.pop(ctx);
                        },
                      ),
                      _buildSidePanelItem(
                        icon: Icons.inventory_2_outlined,
                        label: 'Outbox',
                        active:
                            emailPro.selectedFolder == 'outbox' &&
                            emailPro.selectedFolderId == null,
                        onTap: () {
                          setState(() {
                            _sectionTitleOverride = null;
                            _selectedIds.clear();
                            _moveToFolderId = null;
                          });
                          emailPro.setFolder(context, 'outbox');
                          Navigator.pop(ctx);
                        },
                      ),
                      _buildSidePanelItem(
                        icon: Icons.edit_square,
                        label: 'Compose',
                        active: false,
                        onTap: () {
                          setState(() => _sectionTitleOverride = 'Compose');
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MobileEmailComposeScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: Color(0xFFE8EAED)),
                      const SizedBox(height: 12),
                      // ── Connected Accounts ──────────────────────────────
                      Row(
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Text(
                              'CONNECTED ACCOUNTS',
                              style: TextStyle(
                                color: Color(0xFF80868B),
                                fontSize: 11,
                                letterSpacing: 0.4,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () {
                              emailPro.isAddingAccount = true;
                              emailPro.refresh();
                              Navigator.pop(ctx);
                            },
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.add,
                                  size: 15,
                                  color: AppColors.amber,
                                ),
                                SizedBox(width: 2),
                                Text(
                                  'Add',
                                  style: TextStyle(
                                    color: AppColors.amber,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...emailPro.emailData!.accounts.map((account) {
                        final isCurrent =
                            account.id == emailPro.emailData?.selectedAccountId;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? const Color(0xFFF8F1D8)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isCurrent
                                  ? const Color(0xFFFFE082)
                                  : const Color(0xFFE8EAED),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isCurrent
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                size: 18,
                                color: isCurrent
                                    ? const Color(0xFF34A853)
                                    : const Color(0xFFBDBDBD),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      account.email,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isCurrent
                                            ? FontWeight.w700
                                            : FontWeight.w400,
                                        color: const Color(0xFF202124),
                                      ),
                                    ),
                                    if (isCurrent) ...[
                                      const SizedBox(height: 3),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              if (!isCurrent)
                                GestureDetector(
                                  onTap: () {
                                    emailPro.switchAccount(context, account.id);
                                    Navigator.pop(ctx);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: const Color(0xFFE8EAED),
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'Switch',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF374151),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                Icon(
                                  Icons.swap_horiz_rounded,
                                  size: 20,
                                  color: AppColors.amber,
                                ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () {
                                  showDialog(
                                    context: ctx,
                                    builder: (_) => AlertDialog(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      title: const Text(
                                        'Disconnect account?',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      content: Text(
                                        'Remove ${account.email} from connected accounts?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text(
                                            'Cancel',
                                            style: TextStyle(
                                              color: Color(0xFF6B7280),
                                            ),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(ctx);
                                            emailPro.disconnectAccount(
                                              context,
                                              account.id,
                                            );
                                            Navigator.pop(ctx);
                                          },
                                          child: const Text(
                                            'Remove',
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF0F0),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFFFFCDD2),
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(6),
                                  child: Image.asset(
                                    Paths.delete,
                                    fit: BoxFit.contain,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: Color(0xFFE8EAED)),
                      const SizedBox(height: 12),
                      // ── Folders ─────────────────────────────────────────
                      const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Text(
                          'FOLDERS',
                          style: TextStyle(
                            color: Color(0xFF80868B),
                            fontSize: 11,
                            letterSpacing: 0.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 36,
                              child: TextField(
                                controller: _folderController,
                                style: const TextStyle(
                                  color: Color(0xFF202124),
                                  fontSize: 14,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'New folder',
                                  hintStyle: const TextStyle(
                                    color: Color(0xFF9AA0A6),
                                    fontSize: 14,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(9),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFDADCE0),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(9),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFDADCE0),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(9),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFFBBC04),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          SizedBox(
                            height: 32,
                            child: FilledButton(
                              onPressed: () {
                                final name = _folderController.text.trim();
                                if (name.isEmpty) return;
                                emailPro.createFolder(context, name);
                                _folderController.clear();
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFFBBC04),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                'Add',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (customFolders.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Text(
                            'No custom folders found.',
                            style: TextStyle(
                              color: Color(0xFFA1AEC6),
                              fontSize: 13,
                            ),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: customFolders.length,
                          padding: EdgeInsets.zero,
                          itemBuilder: (_, index) {
                            final f = customFolders[index];
                            return _buildSidePanelItem(
                              icon: Icons.folder_outlined,
                              label: f.name,
                              active:
                                  emailPro.selectedFolder == f.name &&
                                  emailPro.selectedFolderId == f.id,
                              onTap: () {
                                setState(() => _sectionTitleOverride = f.name);
                                emailPro.setFolder(
                                  context,
                                  f.name,
                                  folderId: f.id,
                                );
                                Navigator.pop(ctx);
                              },
                            );
                          },
                        ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ), // SingleChildScrollView
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSidePanelItem({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFF8F1D8) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 40,
          child: Row(
            children: [
              const SizedBox(width: 10),
              Icon(
                icon,
                size: 18,
                color: active
                    ? const Color(0xFFF9AB00)
                    : const Color(0xFF202124),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: active
                      ? const Color(0xFFF9AB00)
                      : const Color(0xFF202124),
                  fontWeight: FontWeight.w500,
                  fontSize: 22 - 7,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessages(
    BuildContext context,
    EmailPro emailPro,
    bool isWidePhone,
  ) {
    final messages = emailPro.emailData?.messages ?? const <EmailMessage>[];

    if (messages.isEmpty && !emailPro.isLoading) {
      return RefreshIndicator(
        onRefresh: () => emailPro.fetchMailData(context),
        color: AppColors.amber,
        child: ListView(
          children: const [
            SizedBox(height: 120),
            Icon(Icons.inbox_outlined, size: 56, color: Color(0xFF7E869B)),
            SizedBox(height: 10),
            Center(
              child: Text(
                'No email in this folder',
                style: TextStyle(color: Color(0xFF9CA3AF)),
              ),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () => emailPro.fetchMailData(context),
          color: AppColors.amber,
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(
              10,
              0,
              10,
              _selectedIds.isNotEmpty ? 110 : 90,
            ),
            itemCount: messages.length,
            separatorBuilder: (context, index) =>
                const Divider(height: 1, color: Color(0xFFE8EAED)),
            itemBuilder: (context, index) {
              final message = messages[index];
              final subject = message.subject.isEmpty
                  ? '(No Subject)'
                  : message.subject;
              final snippet = _normalizeSnippet(message.bodySnippet);
              final isSelected = _selectedIds.contains(message.id);
              return Material(
                color: isSelected
                    ? AppColors.amber.withValues(alpha: 0.08)
                    : Colors.white,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onLongPress: () {
                    setState(() {
                      _selectedIds.add(message.id);
                    });
                  },
                  onTap: () async {
                    if (_selectedIds.isNotEmpty) {
                      setState(() {
                        if (isSelected) {
                          _selectedIds.remove(message.id);
                        } else {
                          _selectedIds.add(message.id);
                        }
                      });
                      return;
                    }
                    final accountId = emailPro.emailData?.selectedAccountId;
                    if (accountId == null) return;
                    await emailPro.fetchMessageDetails(
                      context,
                      message.id,
                      accountId,
                    );
                    if (!mounted) return;
                    final selected = emailPro.selectedMessage;
                    if (selected == null) return;
                    if (!mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            MobileEmailDetailScreen(message: selected),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_selectedIds.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: 8, top: 2),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: Checkbox(
                                value: isSelected,
                                activeColor: AppColors.amber,
                                side: BorderSide(
                                  color: Colors.grey.shade300,
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedIds.add(message.id);
                                    } else {
                                      _selectedIds.remove(message.id);
                                    }
                                  });
                                },
                              ),
                            ),
                          )
                        else
                          CircleAvatar(
                            radius: isWidePhone ? 21 : 18,
                            backgroundColor: _avatarColor(message.from),
                            child: Text(
                              _initial(message.from),
                              style: const TextStyle(
                                color: Color(0xFF202124),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      message.from,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: isWidePhone ? 14 : 13,
                                        fontWeight: message.isUnread
                                            ? FontWeight.w700
                                            : FontWeight.w600,
                                        color: const Color(0xFF202124),
                                      ),
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        _formatDate(message.date),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: message.isUnread
                                              ? const Color(0xFF202124)
                                              : const Color(0xFF5F6368),
                                          fontWeight: message.isUnread
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text(
                                subject,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: message.isUnread
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: const Color(0xFF202124),
                                ),
                              ),
                              const SizedBox(height: 3),
                              RichText(
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                text: TextSpan(
                                  text: snippet,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF5F6368),
                                    height: 1.35,
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
          ),
        ),
        if (emailPro.isLoading)
          Container(
            color: Colors.white.withValues(alpha: 0.45),
            child: const Center(
              child: CircularProgressIndicator(color: AppColors.amber),
            ),
          ),
        // Selection action bar
        if (_selectedIds.isNotEmpty)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
              decoration: BoxDecoration(
                color: Colors.white,
                border: const Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.07),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Select-all / deselect
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: Checkbox(
                      value: _selectedIds.length == messages.length,
                      activeColor: AppColors.amber,
                      side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedIds.addAll(messages.map((m) => m.id));
                          } else {
                            _selectedIds.clear();
                            _moveToFolderId = null;
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_selectedIds.length} selected',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        borderRadius: BorderRadius.circular(8),
                        color: const Color(0xFFF9FAFB),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _moveToFolderId,
                          isExpanded: true,
                          hint: const Text(
                            'Move to...',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF111827),
                          ),
                          dropdownColor: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          onChanged: (val) =>
                              setState(() => _moveToFolderId = val),
                          items: (emailPro.emailData?.mailFolders ?? [])
                              .map(
                                (f) => DropdownMenuItem<int>(
                                  value: f.id,
                                  child: Text(f.name),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Move button
                  GestureDetector(
                    onTap: () {
                      if (_moveToFolderId == null) {
                        showToast(message: 'Select a destination folder');
                        return;
                      }
                      emailPro
                          .moveMessages(
                            context,
                            _moveToFolderId!,
                            _selectedIds.toList(),
                          )
                          .then((_) {
                            setState(() {
                              _selectedIds.clear();
                              _moveToFolderId = null;
                            });
                          });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: AppColors.amber,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.drive_file_move_outline,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Cancel selection
                  GestureDetector(
                    onTap: () => setState(() {
                      _selectedIds.clear();
                      _moveToFolderId = null;
                    }),
                    child: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 18,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildConnectView(BuildContext context, EmailPro emailPro) {
    final services =
        emailPro.emailData?.connectContext?.services ??
        [
          EmailService(service: 'Google', title: 'Google', enabled: true),
          EmailService(
            service: 'Office365',
            title: 'Office 365',
            enabled: true,
          ),
          EmailService(service: 'iCloud', title: 'iCloud', enabled: true),
          EmailService(service: 'imap', title: 'IMAP', enabled: true),
        ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      child: Column(
        children: [
          // Back button — only when adding a new account (existing accounts present)
          if (emailPro.isAddingAccount)
            Align(
              alignment: Alignment.centerLeft,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  emailPro.isAddingAccount = false;
                  emailPro.connectionError = null;
                  emailPro.refresh();
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.back, color: AppColors.amber, size: 20),
                    SizedBox(width: 4),
                    Text(
                      'Cancel',
                      style: TextStyle(
                        color: AppColors.amber,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (emailPro.isAddingAccount) const SizedBox(height: 8),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.amber,
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(10),
            child: Image.asset(Paths.logoWhite, fit: BoxFit.contain),
          ),
          const SizedBox(height: 12),
          const Text(
            'Connect your mailbox',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Read and send email directly in Print Helpers.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF6B7280), height: 1.45),
          ),
          if (emailPro.connectionError != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Text(
                emailPro.connectionError!,
                style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12),
              ),
            ),
          ],
          const SizedBox(height: 18),
          ...services.map(
            (service) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _serviceTile(
                title: service.title,
                service: service.service,
                enabled: service.enabled,
                onTap: () => emailPro.connectService(context, service.service),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _serviceTile({
    required String title,
    required String service,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFF3F4F6),
                child: Icon(_serviceIcon(service), size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _connectTitle(title),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14),
            ],
          ),
        ),
      ),
    );
  }

  IconData _serviceIcon(String service) {
    final type = service.toLowerCase();
    if (type.contains('google')) return Icons.mark_email_unread_outlined;
    if (type.contains('office') || type.contains('outlook')) {
      return Icons.alternate_email_rounded;
    }
    if (type.contains('icloud')) return Icons.cloud_outlined;
    return Icons.storage_outlined;
  }

  String _connectTitle(String title) {
    final t = title.toLowerCase();
    if (t.contains('google')) return 'Connect Gmail / Google Workspace';
    if (t.contains('office') || t.contains('outlook')) {
      return 'Connect Outlook / Office 365';
    }
    if (t.contains('icloud')) return 'Connect iCloud Mail';
    if (t.contains('imap')) return 'Connect via IMAP';
    return 'Connect $title';
  }

  String _initial(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed[0].toUpperCase();
  }

  String _stripHtml(String html) {
    final noTags = html.replaceAll(RegExp(r'<[^>]*>'), ' ');
    return _decodeHtmlEntities(noTags).replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _normalizeSnippet(String value) {
    final stripped = _stripHtml(value);
    if (stripped.isEmpty) return 'No preview available';
    return stripped;
  }

  String _decodeHtmlEntities(String input) {
    var output = input
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");

    output = output.replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
      final code = int.tryParse(m.group(1) ?? '');
      if (code == null) return m.group(0) ?? '';
      return String.fromCharCode(code);
    });

    return output;
  }

  Color _avatarColor(String from) {
    const palette = <Color>[
      Color(0xFFFCE8B2),
      Color(0xFFD7E3FC),
      Color(0xFFD2F4EA),
      Color(0xFFFAD2CF),
      Color(0xFFE6DCF6),
      Color(0xFFC2E7FF),
    ];
    final idx = from.isEmpty ? 0 : from.codeUnitAt(0) % palette.length;
    return palette[idx];
  }

  String _formatDate(String raw, {bool long = false}) {
    if (raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      if (long) {
        final month = _monthShort(dt.month);
        final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
        final minute = dt.minute.toString().padLeft(2, '0');
        final amPm = dt.hour >= 12 ? 'PM' : 'AM';
        return '$month ${dt.day}, ${dt.year}, $hour12:$minute $amPm';
      }

      final now = DateTime.now();
      if (_isSameDay(dt, now)) {
        final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
        final minute = dt.minute.toString().padLeft(2, '0');
        final amPm = dt.hour >= 12 ? 'PM' : 'AM';
        return '$hour12:$minute $amPm';
      }

      if (dt.year == now.year) {
        return '${_monthShort(dt.month)} ${dt.day}';
      }

      final yy = (dt.year % 100).toString().padLeft(2, '0');
      return '${dt.month}/${dt.day}/$yy';
    } catch (_) {
      return raw;
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _monthShort(int month) {
    const months = <String>[
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
    return months[(month - 1).clamp(0, 11)];
  }
}

// class _FolderOption {
//   final String name;
//   final String label;
//   final int? folderId;

//   const _FolderOption({required this.name, required this.label, this.folderId});
// }
