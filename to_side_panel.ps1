$file = 'lib\tablet_view\lib\tab_widgets\tab_email_share_sheet.dart'
$content = Get-Content -Raw $file

# Replace showModalBottomSheet opening with showGeneralDialog
$old1 = "    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Consumer<FilesPro>(
              builder: (context, pro, child) {
                if (pro.emailOptionsLoading) {
                  return SafeArea(
                    child: Container(
                      height: MediaQuery.of(context).size.height * 0.90,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                  );
                }"

$new1 = "    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'EmailSharePanel',
      barrierColor: Colors.black.withValues(alpha: 0.25),
      transitionDuration: const Duration(milliseconds: 350),
      transitionBuilder: (_, anim, _, child) {
        return SlideTransition(
          position: Tween(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
      pageBuilder: (ctx, _, _) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Consumer<FilesPro>(
              builder: (context, pro, child) {
                if (pro.emailOptionsLoading) {
                  return Align(
                    alignment: Alignment.centerRight,
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        width: 420,
                        height: double.infinity,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(30),
                            bottomLeft: Radius.circular(30),
                          ),
                        ),
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                    ),
                  );
                }"

$content = $content.Replace($old1, $new1)

# Replace the main SafeArea(Container) return with right-panel Align(Material(Container))
$old2 = "                return SafeArea(
                  child: Container(
                    height: MediaQuery.of(context).size.height * 0.90,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    child: Column("

$new2 = "                return Align(
                  alignment: Alignment.centerRight,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      width: 420,
                      height: double.infinity,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(30),
                          bottomLeft: Radius.circular(30),
                        ),
                      ),
                      child: Column("

$content = $content.Replace($old2, $new2)

# Close the extra Material( wrapping — find the last closing of the main container and add extra )
# The original closing sequence was:
#   );       <- closes child:Column
#   ),       <- closes Container
# ),         <- closes child: SafeArea (was child: Container)
# );         <- closes Consumer builder return
# We need an extra ), for Material and ), for Align
# The pattern to find (after the bottom buttons Row+close):
$old3 = "                  ),
                );
              },
            );
          },
        );
      },
    );"

$new3 = "                    ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );"

$content = $content.Replace($old3, $new3)

Set-Content -NoNewline -Encoding UTF8 -Path $file -Value $content
Write-Output "Done"
