const fs = require('fs');

let content = fs.readFileSync('lib/tablet_view/lib/tab_widgets/tab_email_share_sheet.dart', 'utf-8');

// Normalize to LF for easier processing
content = content.replace(/\r\n/g, '\n');

// 1. Replace showModalBottomSheet opening + loading state
content = content.replace(
  /await showModalBottomSheet\(\s*context: context,\s*isScrollControlled: true,\s*backgroundColor: Colors\.transparent,\s*barrierColor: Colors\.black\.withValues\(alpha: 0\.45\),\s*builder: \(ctx\) \{/,
`await showGeneralDialog(
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
      pageBuilder: (ctx, _, _) {`
);

// 2. Replace loading state SafeArea container
content = content.replace(
  /return SafeArea\(\s*child: Container\(\s*height: MediaQuery\.of\(context\)\.size\.height \* 0\.90,\s*decoration: BoxDecoration\(\s*color: Colors\.white,\s*borderRadius: BorderRadius\.vertical\(\s*top: Radius\.circular\(24\),\s*\),\s*\),\s*child: const Center\(child: CircularProgressIndicator\(\)\),\s*\),\s*\);\s*\}/,
`return Align(
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
                }`
);

// 3. Replace main return SafeArea container + Column opening
content = content.replace(
  /return SafeArea\(\s*child: Container\(\s*height: MediaQuery\.of\(context\)\.size\.height \* 0\.90,\s*decoration: BoxDecoration\(\s*color: Colors\.white,\s*borderRadius: BorderRadius\.vertical\(\s*top: Radius\.circular\(24\),\s*\),\s*\),\s*child: Column\(/,
`return Align(
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
                      child: Column(`
);

// Convert back to CRLF
content = content.replace(/\n/g, '\r\n');
fs.writeFileSync('lib/tablet_view/lib/tab_widgets/tab_email_share_sheet.dart', content, 'utf-8');

console.log('Done');
