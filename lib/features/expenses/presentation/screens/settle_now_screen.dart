import 'package:flutter/cupertino.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../groups/domain/models/group.dart';
import '../../../groups/domain/models/group_member.dart';
import '../../../notifications/data/repositories/notification_repository.dart';
import '../../../profile/data/repositories/payment_details_repository.dart';
import '../../../profile/domain/models/payment_details.dart';
import '../../domain/services/upi_payment_service.dart';
import '../../domain/services/balance_calculator.dart';

class SettleNowScreen extends StatefulWidget {
  final Group group;
  final GroupMember recipient;
  final SettlementSuggestion settlement;

  const SettleNowScreen({
    super.key,
    required this.group,
    required this.recipient,
    required this.settlement,
  });

  @override
  State<SettleNowScreen> createState() => _SettleNowScreenState();
}

class _SettleNowScreenState extends State<SettleNowScreen> {
  final _amountController = TextEditingController();
  final _paymentDetailsRepository = PaymentDetailsRepository();
  final _notificationRepository = NotificationRepository();

  late final Future<PaymentDetails?> _paymentDetailsFuture;

  bool _isOpeningUpi = false;
  bool _isSendingRequest = false;
  bool _upiAppOpened = false;
  bool _requestSent = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _amountController.text = UpiPaymentService.formatPaise(
      widget.settlement.amountPaise,
    );
    _paymentDetailsFuture = _paymentDetailsRepository
        .getGroupMemberPaymentDetails(
          groupId: widget.group.id,
          memberUid: widget.recipient.userId,
        );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  int? _amountPaise() {
    final value = _amountController.text.trim();
    if (!RegExp(r'^\d{1,9}(\.\d{1,2})?$').hasMatch(value)) return null;

    final parts = value.split('.');
    final rupees = int.tryParse(parts[0]);
    if (rupees == null) return null;

    final paise = parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0;

    final amount = rupees * 100 + paise;
    if (amount <= 0 || amount > widget.settlement.amountPaise) return null;

    return amount;
  }

  String _formatPaise(int amountPaise) {
    return '₹${UpiPaymentService.formatPaise(amountPaise)}';
  }

  Future<void> _showMessage(String title, String message) async {
    if (!mounted) return;

    await showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _openUpiApp(PaymentDetails details) async {
    final amount = _amountPaise();
    if (amount == null) {
      setState(() {
        _errorMessage =
            'Enter an amount greater than zero and no more than ${_formatPaise(widget.settlement.amountPaise)}.';
      });
      return;
    }

    if (details.upiId.isEmpty) {
      await _showMessage(
        'UPI ID not available',
        '${widget.recipient.displayName} has not added a UPI ID for this group yet.',
      );
      return;
    }

    setState(() {
      _isOpeningUpi = true;
      _errorMessage = null;
      _upiAppOpened = false;
    });

    try {
      final launched = await UpiPaymentService.launchPayment(
        upiId: details.upiId,
        payeeName: widget.recipient.displayName,
        amountPaise: amount,
        note: 'Hisaab Brabar - ${widget.group.name}',
      );

      if (!mounted) return;

      if (launched) {
        setState(() => _upiAppOpened = true);
      } else {
        setState(() {
          _errorMessage = 'No compatible UPI app could open this payment. Install or update a UPI app and try again.';
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isOpeningUpi = false);
    }
  }

  Future<void> _sendPaymentRequest() async {
    final amount = _amountPaise();
    if (amount == null || !_upiAppOpened || _requestSent) return;

    setState(() {
      _isSendingRequest = true;
      _errorMessage = null;
    });

    try {
      await _notificationRepository.sendPaymentConfirmationRequest(
        group: widget.group,
        recipient: widget.recipient,
        amountPaise: amount,
        message:
            'I have sent ${_formatPaise(amount)} to you via UPI. Please confirm once received.',
      );

      if (!mounted) return;
      setState(() {
        _requestSent = true;
        _upiAppOpened = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isSendingRequest = false);
    }
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'Not added' : value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentDetailsCard(PaymentDetails? details) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                CupertinoIcons.person_crop_circle,
                size: 18,
                color: AppColors.primary,
              ),
              SizedBox(width: 8),
              Text(
                'Recipient payment details',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _infoRow('Name', widget.recipient.displayName),
          _infoRow('UPI ID', details?.upiId ?? ''),
          _infoRow('Phone', details?.phoneNumber ?? ''),
          if (details == null || details.upiId.isEmpty)
            const Text(
              'The recipient needs to add a UPI ID in Profile and open this group once before UPI payments can be initiated.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.error,
                height: 1.4,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maximumAmount = _formatPaise(widget.settlement.amountPaise);

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Settle Now'),
        previousPageTitle: 'Group',
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PAYMENT TO',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.7,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.recipient.displayName,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.group.name,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'OUTSTANDING AMOUNT',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    maximumAmount,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            FutureBuilder<PaymentDetails?>(
              future: _paymentDetailsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CupertinoActivityIndicator());
                }

                if (snapshot.hasError) {
                  return Text(
                    'Unable to load recipient payment details: ${snapshot.error}',
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 12,
                    ),
                  );
                }

                final details = snapshot.data;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _paymentDetailsCard(details),
                    const SizedBox(height: 20),
                    const Text(
                      'Payment amount',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    CupertinoTextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      prefix: const Padding(
                        padding: EdgeInsets.only(left: 14),
                        child: Text(
                          '₹',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      onChanged: (_) {
                        setState(() {
                          _upiAppOpened = false;
                          _errorMessage = null;
                        });
                      },
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Pay the full amount or enter a smaller partial payment. Maximum: $maximumAmount',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (_errorMessage != null) ...[
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.error,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_requestSent)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.sage,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              CupertinoIcons.checkmark_circle_fill,
                              color: AppColors.sageDark,
                            ),
                            SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                'Payment confirmation request sent. Your balance will update after the recipient confirms it.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.sageDark,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      CupertinoButton.filled(
                        borderRadius: BorderRadius.circular(14),
                        onPressed:
                            details == null ||
                                details.upiId.isEmpty ||
                                _isOpeningUpi ||
                                _isSendingRequest
                            ? null
                            : () => _openUpiApp(details),
                        child: _isOpeningUpi
                            ? const CupertinoActivityIndicator(
                                color: CupertinoColors.white,
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(CupertinoIcons.arrow_up_right, size: 17),
                                  SizedBox(width: 8),
                                  Text('Open UPI App'),
                                ],
                              ),
                      ),
                      if (_upiAppOpened) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Complete the payment in your UPI app, then return here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        CupertinoButton(
                          color: AppColors.sage,
                          borderRadius: BorderRadius.circular(14),
                          onPressed: _isSendingRequest
                              ? null
                              : _sendPaymentRequest,
                          child: _isSendingRequest
                              ? const CupertinoActivityIndicator()
                              : const Text(
                                  "I've Paid",
                                  style: TextStyle(
                                    color: AppColors.sageDark,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ],
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            const Text(
              'Safety note: Hisaab Brabar only opens your UPI app. It cannot verify the bank transfer. The recipient must confirm receipt before this payment changes group balances.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
