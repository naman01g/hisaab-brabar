# Hisaab Brabar — Settle Now + UPI Intent patch

This is a patch overlay for the existing Hisaab Brabar Flutter project, not a complete Flutter project.

## What this adds

- Profile fields for a UPI ID and an optional phone number.
- A private canonical payment profile at `privatePaymentProfiles/{uid}`.
- A group-scoped copy at `groups/{groupId}/memberPaymentDetails/{uid}`:
  - only group members can read a specific member's payment details;
  - only that member can create/update their own group copy;
  - the collection cannot be enumerated with a list query.
- A **Settle Now** action for suggested payments where the signed-in user is the payer.
- A full or partial amount field, capped in the UI at the current suggested amount.
- Android UPI Intent launch using `upi://pay` and the recipient's UPI ID.
- A payer confirmation request using the app's existing `NotificationRepository`.
- Balance recalculation from `confirmed` settlement records only.
- Existing public `profiles/{uid}` documents remain free of UPI IDs and phone numbers.

## Important: verify the notification repository integration

This patch calls `NotificationRepository.sendPaymentConfirmationRequest(...)`, which must create the settlement and its notification in the **same atomic batch** and use the **same document ID** for both records. See `NOTIFICATION_REPOSITORY_REQUIRED_METHOD.md` and verify that your existing `lib/features/notifications/data/repositories/notification_repository.dart` has that implementation. If it does not, merge the method there before testing.

The required ID convention is:

- Settlement: `groups/{groupId}/settlements/{settlementId}`
- Recipient notification: `users/{toUid}/notifications/{settlementId}`

Both IDs must be identical because the Firestore rules pair the writes with `getAfter()`.

## Install

1. Back up your current Firestore rules and source files.
2. Merge the `lib/` directory from this patch into the root of your Flutter project. Replace the existing files with matching paths.
3. Add the URL launcher dependency:

   ```bash
   flutter pub add url_launcher
   ```

4. Review the included `firestore.rules` against the exact rules currently published in Firebase Console. The supplied file is based on the rules uploaded for this patch and adds private/group-scoped payment-detail rules. It also aligns the profile avatar allow-list with the Profile screen.
5. **Do not publish the rules yet.** First test them in the Firestore Emulator with the current app code. The patch contains a test checklist in `INTEGRATION_CHECKS.md`, but does not include an automated emulator test harness.
6. Only after emulator tests pass, deploy the rules to project `hisaab-brabar`, for example:

   ```bash
   firebase deploy --only firestore:rules --project hisaab-brabar
   ```

7. Run:

   ```bash
   dart format lib/
   flutter analyze
   flutter run
   ```

## Files in this patch

### Replacements

- `lib/features/profile/presentation/screens/profile_screen.dart`
- `lib/features/groups/presentation/screens/group_details_screen.dart`
- `lib/features/expenses/domain/services/balance_calculator.dart`

### New files

- `lib/features/profile/domain/models/payment_details.dart`
- `lib/features/profile/data/repositories/payment_details_repository.dart`
- `lib/features/expenses/domain/models/group_settlement.dart`
- `lib/features/expenses/data/repositories/group_settlement_repository.dart`
- `lib/features/expenses/domain/services/upi_payment_service.dart`
- `lib/features/expenses/presentation/screens/settle_now_screen.dart`

### Additional integration notes

- `NOTIFICATION_REPOSITORY_REQUIRED_METHOD.md` shows the required shared-ID settlement request method for your existing notification repository.
- `INTEGRATION_CHECKS.md` lists the emulator and two-account regression tests.
- `firestore.rules` is a complete updated rules file based on the rules supplied for this patch. Do not publish without comparing and emulator testing it.

## Important behavior and limitations

- UPI Intent is currently implemented for Android. Android resolves the `upi://pay` URI to a compatible installed UPI app.
- A UPI ID (VPA) is required for the generic prefilled UPI payment. The optional phone number is stored for group contact purposes; this implementation does not use a phone number as a substitute for the recipient's VPA.
- Opening a UPI app is not proof that a payment succeeded. Returning to Hisaab Brabar and tapping **I've Paid** sends a request; the recipient must confirm receipt.
- The app cannot independently verify bank/UPI settlement. Confirmation is an agreement between the two group members.
- Firestore Rules cannot calculate the true debt from the expense and settlement subcollections. The client caps the UI amount at the suggested balance, but a malicious client could submit a different positive amount. The recipient must check the amount before confirming. A trusted server-side settlement function would be needed for stronger enforcement.
- Payment details are readable by members of each group where the member-specific copy exists. They are not included in the discoverable public profile.
- `saveMyPaymentDetails` synchronizes across group copies in chunks of 6 writes per batch to stay below Firestore's 20 security-rule access-call budget for atomic operations, assuming at most three rule document-access calls per group-copy write.
- The Flutter/Dart CLI is not available in the artifact-generation environment, so this patch has not been run through `dart format`, `flutter analyze`, the Firestore Emulator, or a device test. Run those checks in your project after applying it.
