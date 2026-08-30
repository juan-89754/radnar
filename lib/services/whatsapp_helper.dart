import 'package:url_launcher/url_launcher.dart';

class WhatsAppHelper {
  /// Sends a WhatsApp text message to the specified phone number.
  /// Formats the phone number to be compatible with wa.me (removing '+' and symbols).
  static Future<void> sendWhatsAppMessage(String phone, String message) async {
    String cleanPhone = phone.replaceAll('+', '').replaceAll(' ', '').replaceAll('-', '').trim();
    
    // Default country prefix if missing and is 10 digits
    if (cleanPhone.length == 10 && cleanPhone.startsWith('3')) {
      cleanPhone = '57$cleanPhone';
    }

    final encodedMessage = Uri.encodeComponent(message);
    final urlString = 'https://wa.me/$cleanPhone?text=$encodedMessage';
    final url = Uri.parse(urlString);

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('No se pudo abrir WhatsApp. Verifique que la aplicación esté instalada.');
    }
  }
}
