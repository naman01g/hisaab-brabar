import 'package:flutter/cupertino.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../groups/domain/models/group.dart';
import '../../../groups/domain/models/group_member.dart';
import '../../data/repositories/notification_repository.dart';

class SettleUpRequestScreen extends StatefulWidget {
  final Group group;
  final GroupMember recipient;

  const SettleUpRequestScreen({
    super.key,
    required this.group,
    required this.recipient,
  });

  @override
  State<SettleUpRequestScreen> createState() => _SettleUpRequestScreenState();
}

class _SettleUpRequestScreenState extends State<SettleUpRequestScreen> {
  final TextEditingController _messageController = TextEditingController();

  final NotificationRepository _repository = NotificationRepository();

  bool _sending = false;
  String? _error;

  Future<void> _sendRequest() async {
    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      await _repository.sendSettleUpRequest(
        group: widget.group,
        recipient: widget.recipient,
        message: _messageController.text,
      );

      if (!mounted) return;

      await showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Request sent'),
          content: Text(
            '${widget.recipient.displayName} will see your request in their inbox.',
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('Done'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );

      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Request Settlement'),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Request from ${widget.recipient.displayName}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Group: ${widget.group.name}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              const Text(
                'Add a message (optional)',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              CupertinoTextField(
                controller: _messageController,
                placeholder: 'Hey, please settle up when convenient.',
                maxLines: 4,
                maxLength: 200,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  onPressed: _sending ? null : _sendRequest,
                  child: _sending
                      ? const CupertinoActivityIndicator(
                          color: CupertinoColors.white,
                        )
                      : const Text('Send Settlement Request'),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(_error!, style: const TextStyle(color: AppColors.error)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
