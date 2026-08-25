import 'package:envied/envied.dart';

part 'envied_vault.g.dart';

@Envied(path: '.env', obfuscate: true)
abstract class EnviedVault {
  @EnviedField(varName: 'ENVIED_API_KEY')
  static final String apiKey = _EnviedVault.apiKey;
}
