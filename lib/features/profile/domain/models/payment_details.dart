class PaymentDetails {
  final String upiId;
  final String phoneNumber;

  const PaymentDetails({required this.upiId, required this.phoneNumber});

  bool get hasUpiId => upiId.isNotEmpty;
  bool get hasPhoneNumber => phoneNumber.isNotEmpty;
}
