import 'dart:convert';

class EncryptionHelper {
  static const String _key = 'RadnarSecretKey123!'; // Clave de cifrado local

  /// Cifra una cadena de texto en plano a una representación cifrada en Base64
  static String encrypt(String plainText) {
    if (plainText.isEmpty) return '';
    List<int> plainBytes = utf8.encode(plainText);
    List<int> keyBytes = utf8.encode(_key);
    List<int> encryptedBytes = [];

    for (int i = 0; i < plainBytes.length; i++) {
      encryptedBytes.add(plainBytes[i] ^ keyBytes[i % keyBytes.length]);
    }

    return base64.encode(encryptedBytes);
  }

  /// Descifra una cadena cifrada en Base64 a su valor original en texto plano
  static String decrypt(String encryptedBase64) {
    if (encryptedBase64.isEmpty) return '';
    try {
      List<int> encryptedBytes = base64.decode(encryptedBase64);
      List<int> keyBytes = utf8.encode(_key);
      List<int> decryptedBytes = [];

      for (int i = 0; i < encryptedBytes.length; i++) {
        decryptedBytes.add(encryptedBytes[i] ^ keyBytes[i % keyBytes.length]);
      }

      return utf8.decode(decryptedBytes);
    } catch (e) {
      // Retorna vacío si falla la decodificación
      return '';
    }
  }
}
