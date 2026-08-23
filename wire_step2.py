path = r'c:\Users\shiva\CorporatePoolingApp\lib\screens\auth\onboarding_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

import_line = "import 'phone_login_screen.dart';"
if import_line not in content:
    content = import_line + "\n" + content

old_target = """  Future<void> _completeOnboarding() async {
    HapticFeedback.mediumImpact();
    await SecureStorageService.setOnboardingSeen(true);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Welcome to KarmaRide! Routing to Authentication...'),
        backgroundColor: Color(0xFF0F172A),
        duration: Duration(seconds: 1),
      ),
    );
  }"""

new_target = """  Future<void> _completeOnboarding() async {
    HapticFeedback.mediumImpact();
    await SecureStorageService.setOnboardingSeen(true);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const PhoneLoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }"""

if old_target in content:
    content = content.replace(old_target, new_target)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("SUCCESS: Wired Get Started button to PhoneLoginScreen (Step 2 Complete)")
else:
    print("Target not found directly in content")
