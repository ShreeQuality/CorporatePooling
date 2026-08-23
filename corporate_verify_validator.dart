/// Corporate Verification Validation Engine & Domain Resolver
/// Handles Public Domain Blacklisting, Corporate Auto-Resolution,
/// Clipboard OTP Extraction, Invite Code Validation, and Lockout Matrix.
class CorporateEmailValidationResult {
  final bool isValid;
  final bool isPublicDomain;
  final String? errorMessage;
  final String? domain;
  final String? companyName;
  final bool isAutoWhitelisted;

  const CorporateEmailValidationResult({
    required this.isValid,
    this.isPublicDomain = false,
    this.errorMessage,
    this.domain,
    this.companyName,
    this.isAutoWhitelisted = false,
  });

  @override
  String toString() {
    return 'CorporateEmailValidationResult(isValid: $isValid, isPublicDomain: $isPublicDomain, domain: $domain, company: $companyName)';
  }
}

class CorporateVerifyValidator {
  /// Blacklist of consumer/public email domains
  static const Set<String> publicDomains = {
    'gmail.com',
    'yahoo.com',
    'yahoo.co.in',
    'yahoo.co.uk',
    'outlook.com',
    'hotmail.com',
    'live.com',
    'msn.com',
    'icloud.com',
    'me.com',
    'mac.com',
    'aol.com',
    'rediffmail.com',
    'zoho.com',
    'proton.me',
    'protonmail.com',
    'mail.com',
    'gmx.com',
    'yandex.com',
  };

  /// Well-known enterprise domain mapping to company names
  static const Map<String, String> knownCompanies = {
    'tcs.com': 'Tata Consultancy Services',
    'infosys.com': 'Infosys Technologies',
    'wipro.com': 'Wipro Limited',
    'accenture.com': 'Accenture',
    'cognizant.com': 'Cognizant',
    'capgemini.com': 'Capgemini',
    'hcltech.com': 'HCLTech',
    'hcl.com': 'HCLTech',
    'techmahindra.com': 'Tech Mahindra',
    'ibm.com': 'IBM',
    'microsoft.com': 'Microsoft',
    'google.com': 'Google',
    'amazon.com': 'Amazon',
    'oracle.com': 'Oracle',
    'cisco.com': 'Cisco',
    'deloitte.com': 'Deloitte',
    'ey.com': 'Ernst & Young (EY)',
    'pwc.com': 'PricewaterhouseCoopers (PwC)',
    'kpmg.com': 'KPMG',
    'intel.com': 'Intel',
    'qualcomm.com': 'Qualcomm',
    'samsung.com': 'Samsung',
    'meta.com': 'Meta',
    'apple.com': 'Apple',
    'uber.com': 'Uber',
    'ola.com': 'Ola Cabs',
    'flipkart.com': 'Flipkart',
    'swiggy.in': 'Swiggy',
    'zomato.com': 'Zomato',
  };

  /// Validates a work email against format & public blacklist rules
  static CorporateEmailValidationResult validateEmail(String rawEmail) {
    final email = rawEmail.trim().toLowerCase();

    if (email.isEmpty) {
      return const CorporateEmailValidationResult(
        isValid: false,
        errorMessage: null,
      );
    }

    // Standard email pattern
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!email.contains('@')) {
      return const CorporateEmailValidationResult(
        isValid: false,
        errorMessage: null,
      );
    }

    final parts = email.split('@');
    if (parts.length != 2 || parts[0].isEmpty || parts[1].isEmpty) {
      return const CorporateEmailValidationResult(
        isValid: false,
        errorMessage: 'Please enter a complete email address.',
      );
    }

    final domain = parts[1];

    // Check against public blacklist
    if (publicDomains.contains(domain)) {
      return CorporateEmailValidationResult(
        isValid: false,
        isPublicDomain: true,
        domain: domain,
        errorMessage: 'Public domains not allowed. Please enter your work email.',
      );
    }

    if (!emailRegex.hasMatch(email)) {
      return CorporateEmailValidationResult(
        isValid: false,
        domain: domain,
        errorMessage: 'Invalid corporate email format.',
      );
    }

    // Resolve company name
    final companyName = resolveCompanyName(domain);

    return CorporateEmailValidationResult(
      isValid: true,
      domain: domain,
      companyName: companyName,
      isAutoWhitelisted: knownCompanies.containsKey(domain),
    );
  }

  /// Formats or resolves company name from domain stem
  static String resolveCompanyName(String domain) {
    final lowerDomain = domain.toLowerCase();
    if (knownCompanies.containsKey(lowerDomain)) {
      return knownCompanies[lowerDomain]!;
    }

    // Fallback: capitalize domain name (e.g. 'nvidia.com' -> 'Nvidia')
    final stem = lowerDomain.split('.').first;
    if (stem.isEmpty) return domain;
    return stem[0].toUpperCase() + stem.substring(1);
  }

  /// Extracts 6-digit OTP from clipboard string
  /// Handles raw OTPs ('123456'), longer strings ('12345678' -> '123456'),
  /// and conversational strings ('Your OTP is 556677' -> '556677')
  static String? extractOtpFromClipboard(String rawText) {
    final cleaned = rawText.trim();
    if (cleaned.isEmpty) return null;

    final regex = RegExp(r'\d{6}');
    final match = regex.firstMatch(cleaned);
    return match?.group(0);
  }

  /// Validates 6-character uppercase alphanumeric Invite Code (e.g. 'INFY26')
  static bool isValidInviteCode(String rawCode) {
    final code = rawCode.trim().toUpperCase();
    if (code.length != 6) return false;
    final regex = RegExp(r'^[A-Z0-9]{6}$');
    return regex.hasMatch(code);
  }

  /// Resolves company name from invite code prefix
  static String resolveInviteCodeCompany(String rawCode) {
    final code = rawCode.trim().toUpperCase();
    if (code.startsWith('INFY')) return 'Infosys Technologies';
    if (code.startsWith('TCS')) return 'Tata Consultancy Services';
    if (code.startsWith('WIPR')) return 'Wipro Limited';
    if (code.startsWith('GOOG')) return 'Google';
    if (code.startsWith('MSFT')) return 'Microsoft';
    if (code.startsWith('AMZN')) return 'Amazon';
    return 'Enterprise Partner';
  }

  /// Max allowable failed attempts before lockout
  static const int maxFailedAttempts = 3;

  /// Lockout duration on 3 failed attempts
  static const Duration lockoutDuration = Duration(minutes: 5);
}
