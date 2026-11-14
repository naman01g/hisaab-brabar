import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../groups/data/repositories/group_invitation_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../domain/models/app_notification.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationRepository _repository = NotificationRepository();
  final Set<String> _markingAsRead = <String>{};
  late final Stream<List<AppNotification>> _notificationsStream;

  @override
  void initState() {
    super.initState();
    _notificationsStream = _repository.watchMyNotifications();
  }

  void _markVisibleNotificationsAsRead(List<AppNotification> notifications) {
    for (final notification in notifications) {
      if (notification.status != AppNotificationStatus.unread ||
          !_markingAsRead.add(notification.id)) {
        continue;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          _markingAsRead.remove(notification.id);
          return;
        }
        unawaited(_markAsRead(notification.id));
      });
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await _repository.updateStatus(
        notificationId,
        AppNotificationStatus.read,
      );
    } catch (_) {
      // Leave the notification unread so the Home bell continues to show
      // the dot. A later visit can retry the status update.
      _markingAsRead.remove(notificationId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = _repository;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Notifications'),
      ),
      child: SafeArea(
        child: StreamBuilder<List<AppNotification>>(
          stream: _notificationsStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(child: Text('Unable to load notifications.'));
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CupertinoActivityIndicator());
            }

            final notifications = snapshot.data ?? <AppNotification>[];
            _markVisibleNotificationsAsRead(notifications);
            final unreadCount = notifications
                .where((item) => item.status == AppNotificationStatus.unread)
                .length;

            if (notifications.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.bell_slash,
                      size: 48,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(height: 14),
                    Text(
                      'You are all caught up.',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Your notifications will appear here.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Text(
                    unreadCount == 0
                        ? 'You have no unread notifications.'
                        : '$unreadCount unread notification(s)',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    itemCount: notifications.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      return _NotificationCard(
                        notification: notifications[index],
                        repository: repository,
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final NotificationRepository repository;

  const _NotificationCard({
    required this.notification,
    required this.repository,
  });

  bool get _unread => notification.status == AppNotificationStatus.unread;
  bool get _isPayment => notification.isPaymentConfirmation;
  bool get _isGroupInvitation => notification.isGroupInvitation;

  bool get _canRespondToPayment =>
      _isPayment &&
      (notification.status == AppNotificationStatus.unread ||
          notification.status == AppNotificationStatus.read);

  bool get _canRespondToInvitation =>
      _isGroupInvitation &&
      (notification.status == AppNotificationStatus.unread ||
          notification.status == AppNotificationStatus.read);

  String get _statusText {
    switch (notification.status) {
      case AppNotificationStatus.unread:
        if (_isGroupInvitation) return 'Group invitation';
        if (_isPayment) return 'Payment request';
        return 'New request';
      case AppNotificationStatus.read:
        if (_isGroupInvitation) return 'Awaiting response';
        if (_isPayment) return 'Awaiting confirmation';
        return 'Read';
      case AppNotificationStatus.dismissed:
        return 'Dismissed';
      case AppNotificationStatus.settled:
        return _isPayment ? 'Confirmed' : 'Marked as settled';
      case AppNotificationStatus.accepted:
        return 'Invitation accepted';
      case AppNotificationStatus.rejected:
        return 'Invitation rejected';
    }
  }

  String _formatPaise(int paise) {
    final rupees = paise ~/ 100;
    final remaining = (paise % 100).toString().padLeft(2, '0');
    return '₹$rupees.$remaining';
  }

  Future<void> _showError(BuildContext context, Object error) async {
    if (!context.mounted) return;
    await showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Something went wrong'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(error.toString()),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _respondToPayment(
    BuildContext context, {
    required bool confirm,
  }) async {
    try {
      await repository.respondToSettlement(
        notification: notification,
        confirm: confirm,
      );
    } catch (error) {
      if (!context.mounted) return;
      await _showError(context, error);
    }
  }

  Future<void> _respondToInvitation(
    BuildContext context, {
    required bool accept,
  }) async {
    try {
      await GroupInvitationRepository().respondToGroupInvitation(
        notification: notification,
        accept: accept,
      );
    } catch (error) {
      if (!context.mounted) return;
      await _showError(context, error);
    }
  }

  Future<void> _updateStatus(
    BuildContext context,
    AppNotificationStatus status,
  ) async {
    try {
      await repository.updateStatus(notification.id, status);
    } catch (error) {
      if (!context.mounted) return;
      await _showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = _unread;
    final icon = _isGroupInvitation
        ? CupertinoIcons.person_2
        : _isPayment
        ? CupertinoIcons.money_dollar_circle
        : CupertinoIcons.bell;
    final description = _isGroupInvitation
        ? 'Invited you to join ${notification.groupName}.'
        : _isPayment
        ? 'Payment reported in ${notification.groupName}.'
        : 'Requested settlement in ${notification.groupName}.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: unread ? AppColors.primaryLight : AppColors.border,
          width: unread ? 1.3 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  notification.fromName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                _statusText,
                style: TextStyle(
                  color: unread ? AppColors.primary : AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          ),
          if (_isPayment && notification.amountPaise != null) ...[
            const SizedBox(height: 10),
            Text(
              _formatPaise(notification.amountPaise!),
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          if (notification.message.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              notification.message,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 9),
          Text(
            notification.createdAt.toLocal().toString().substring(0, 16),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
          if (_canRespondToInvitation) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: AppColors.sage,
                  onPressed: () => _respondToInvitation(context, accept: true),
                  child: const Text(
                    'Accept',
                    style: TextStyle(
                      color: AppColors.sageDark,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: AppColors.secondary,
                  onPressed: () => _respondToInvitation(context, accept: false),
                  child: const Text(
                    'Reject',
                    style: TextStyle(color: AppColors.primary, fontSize: 13),
                  ),
                ),
              ],
            ),
          ] else if (_canRespondToPayment) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  color: AppColors.sage,
                  onPressed: () => _respondToPayment(context, confirm: true),
                  child: const Text(
                    'Confirm Received',
                    style: TextStyle(
                      color: AppColors.sageDark,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  color: AppColors.secondary,
                  onPressed: () => _respondToPayment(context, confirm: false),
                  child: const Text(
                    'Reject',
                    style: TextStyle(color: AppColors.primary, fontSize: 12),
                  ),
                ),
              ],
            ),
          ] else if (!_isPayment &&
              !_isGroupInvitation &&
              (notification.status == AppNotificationStatus.unread ||
                  notification.status == AppNotificationStatus.read)) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (unread)
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    color: AppColors.secondary,
                    onPressed: () =>
                        _updateStatus(context, AppNotificationStatus.read),
                    child: const Text(
                      'Mark read',
                      style: TextStyle(color: AppColors.primary, fontSize: 12),
                    ),
                  ),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  color: AppColors.sage,
                  onPressed: () =>
                      _updateStatus(context, AppNotificationStatus.settled),
                  child: const Text(
                    'Mark settled',
                    style: TextStyle(color: AppColors.sageDark, fontSize: 12),
                  ),
                ),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  color: AppColors.secondary,
                  onPressed: () =>
                      _updateStatus(context, AppNotificationStatus.dismissed),
                  child: const Text(
                    'Dismiss',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
