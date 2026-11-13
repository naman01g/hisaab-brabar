import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class UpiPaymentService {
  UpiPaymentService._();

  // Keep @ unencoded in the UPI ID.
  // Some UPI apps have inconsistent URL decoding.
  static String _encodeQuery(Map<String, String> parameters) {
    return parameters.entries
        .map((entry) {
          final key = Uri.encodeComponent(entry.key);
          final encodedValue = Uri.encodeComponent(entry.value);

          final value = entry.key == 'pa'
              ? encodedValue.replaceAll('%40', '@')
              : encodedValue;

          return '$key=$value';
        })
        .join('&');
  }

  static String formatPaise(int amountPaise) {
    final rupees = amountPaise ~/ 100;
    final paise = (amountPaise % 100).toString().padLeft(2, '0');

    return '$rupees.$paise';
  }

  static Future<bool> launchPayment({
    required String upiId,
    required String payeeName,
    required int amountPaise,
    required String note,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      throw UnsupportedError(
        'UPI Intent payments are currently supported on Android only.',
      );
    }

    final cleanUpiId = upiId.trim();
    final cleanName = payeeName.trim();
    final cleanNote = note.trim();

    if (cleanUpiId.isEmpty || !cleanUpiId.contains('@')) {
      throw ArgumentError('Please provide a valid recipient UPI ID.');
    }

    if (cleanName.isEmpty) {
      throw ArgumentError('Recipient name is missing.');
    }

    if (amountPaise <= 0) {
      throw ArgumentError('Payment amount must be greater than zero.');
    }

    final query = _encodeQuery({
      'pa': cleanUpiId,
      'pn': cleanName,
      'am': formatPaise(amountPaise),
      'cu': 'INR',
      'tn': cleanNote.length > 50 ? cleanNote.substring(0, 50) : cleanNote,
    });

    final uri = Uri.parse('upi://pay?$query');

    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
