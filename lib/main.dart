import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'envied_vault.dart';
import 'armor_vault.g.dart';
import 'signature_vault.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KeySecurityDemoApp());
}

class KeySecurityDemoApp extends StatelessWidget {
  const KeySecurityDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Secret Protection Showcase',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6366F1),
          secondary: Color(0xFF10B981),
          surface: Color(0xFF1E293B),
        ),
      ),
      home: const VaultDashboardPage(),
    );
  }
}

class VaultDashboardPage extends StatefulWidget {
  const VaultDashboardPage({super.key});

  @override
  State<VaultDashboardPage> createState() => _VaultDashboardPageState();
}

class _VaultDashboardPageState extends State<VaultDashboardPage> {
  String _enviedKey = 'Loading...';
  String _armorKey = 'Loading...';
  String _sigVaultKey = 'Loading...';
  String _activeSha = 'Querying...';
  String _diagnostics = 'Querying...';
  bool _isLoading = true;

  static const _channel = MethodChannel('com.example.security/signature');

  @override
  void initState() {
    super.initState();
    _loadAllSecrets();
  }

  Future<void> _loadAllSecrets() async {
    setState(() => _isLoading = true);

    // 0. Query active signing certificate SHA from OS — for Play Store SHA verification
    String activeSha = 'N/A (not on Android)';
    String diagnostics = 'N/A (not on Android)';
    try {
      activeSha = await _channel.invokeMethod<String>('getCertFingerprint') ?? 'null returned';
      diagnostics = await _channel.invokeMethod<String>('getDiagnostics') ?? 'null returned';
    } catch (e) {
      activeSha = 'Error: $e';
      diagnostics = 'Error: $e';
    }

    // 1. Envied (XOR Obfuscation in Dart class)
    String enviedResult;
    try {
      enviedResult = EnviedVault.apiKey;
    } catch (e) {
      enviedResult = 'Error: $e';
    }

    // 2. Native Armor Vault (C++ / FFI Obfuscation)
    String armorResult;
    try {
      armorResult = ArmorVault.armor_api_key;
    } catch (e) {
      armorResult = 'Error: $e';
    }

    // 3. Signature-Bound AES-256 Vault (AES-256-GCM + PBKDF2 + Hardware Keystore)
    String sigVaultResult;
    try {
      sigVaultResult = await SignatureVault.sigvault_api_key;
    } catch (e) {
      sigVaultResult = 'Error: $e';
    }

    if (mounted) {
      setState(() {
        _activeSha = activeSha;
        _diagnostics = diagnostics;
        _enviedKey = enviedResult;
        _armorKey = armorResult;
        _sigVaultKey = sigVaultResult;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '1 Key Constant Per Technique',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllSecrets,
            tooltip: 'Reload Secrets',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAllSecrets,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeroBanner(),
                    const SizedBox(height: 16),
                    _buildShaDiagnosticCard(),
                    const SizedBox(height: 16),
                    _buildSecretCard(
                      title: '1. Envied: ENVIED_API_KEY',
                      badgeText: 'XOR Modifier Array',
                      badgeColor: Colors.amber,
                      description: 'Transformed into static int arrays in Dart bytecode and XOR-decoded at runtime.',
                      revealedValue: _enviedKey,
                      securityRating: 'Low-Medium (Reversible with Python/Ghidra)',
                      icon: Icons.code,
                    ),
                    const SizedBox(height: 16),
                    _buildSecretCard(
                      title: '2. Native Armor: ARMOR_API_KEY',
                      badgeText: 'C++ / Native FFI',
                      badgeColor: Colors.blueAccent,
                      description: 'Compiled into native libnative_armor_vault.so with rotating XOR & S-box, read via FFI.',
                      revealedValue: _armorKey,
                      securityRating: 'High (Requires C++ Disassembly)',
                      icon: Icons.shield,
                    ),
                    const SizedBox(height: 16),
                    _buildSecretCard(
                      title: '3. Signature Vault: SIGVAULT_API_KEY',
                      badgeText: 'AES-256-GCM + Hardware Keystore',
                      badgeColor: const Color(0xFF10B981),
                      description: 'AES-256-GCM encrypted. Master key derived in RAM with 10,000 PBKDF2 rounds + OS cert. Sealed in ARM TrustZone.',
                      revealedValue: _sigVaultKey,
                      securityRating: 'Military Grade (Zero Keys in Binary)',
                      icon: Icons.enhanced_encryption,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildShaDiagnosticCard() {
    final isPlayStore = !_activeSha.startsWith('f0143cea') &&
        !_activeSha.startsWith('Error') &&
        !_activeSha.startsWith('N/A') &&
        !_activeSha.startsWith('Query');
    final statusColor = _activeSha.startsWith('Error') || _activeSha.startsWith('N/A')
        ? Colors.grey
        : isPlayStore
            ? const Color(0xFF10B981)  // green = Play Store key
            : Colors.amber;            // amber = debug key
    final statusLabel = _activeSha.startsWith('Error') || _activeSha.startsWith('N/A')
        ? 'Not on Android'
        : isPlayStore
            ? '✅ Play App Signing Key'
            : '🔶 Debug Key';

    return Card(
      color: const Color(0xFF0F2035),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: statusColor, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.fingerprint, color: statusColor, size: 22),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Active Signing Certificate (Runtime)',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(40),
                    border: Border.all(color: statusColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'SHA-256 reported by Android PackageManager at runtime:',
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(10),
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF0B1120),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: SelectableText(
                _activeSha,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Full Diagnostics (paste RELEASE_CERT_SHA256 from line below into .env):',
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(10),
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF0B1120),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: SelectableText(
                _diagnostics,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  color: Color(0xFF94A3B8),
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroBanner() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Single Key Constant Comparison',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          SizedBox(height: 8),
          Text(
            'Each technique demonstrates one specific key constant: ENVIED_API_KEY, ARMOR_API_KEY, and SIGVAULT_API_KEY.',
            style: TextStyle(fontSize: 13, color: Colors.white70, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildSecretCard({
    required String title,
    required String badgeText,
    required Color badgeColor,
    required String description,
    required String revealedValue,
    required String securityRating,
    required IconData icon,
  }) {
    return Card(
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: badgeColor, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withAlpha(50),
                    border: Border.all(color: badgeColor, width: 1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              description,
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF0B1120),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: SelectableText(
                revealedValue,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: Color(0xFF38BDF8),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.security, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Security: $securityRating',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
