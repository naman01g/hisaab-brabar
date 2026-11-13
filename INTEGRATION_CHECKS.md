# Settle Now + UPI integration checks

**Run these against the Firestore Emulator before publishing rules.** This patch does not include an automated test harness.

## Payment-detail privacy and synchronization

1. Account A saves a valid UPI ID and phone number. Its `privatePaymentProfiles/{uidA}` record is created/updated.
2. A user other than A cannot read A's `privatePaymentProfiles/{uidA}` document.
3. A group member can read A's specific `groups/{groupId}/memberPaymentDetails/{uidA}` document.
4. A non-member cannot read that document.
5. A member cannot list/enumerate `memberPaymentDetails`.
6. Another group member cannot create or update `memberPaymentDetails/{uidA}`.
7. A can update only `memberPaymentDetails/{uidA}`.
8. Create more than 6 test groups for Account A, save payment details, and verify every group copy is synchronized. Verify batches are chunked at 6 group writes.
9. Simulate a failure in a later chunk. Check for partial synchronization: the private canonical document and earlier chunks may already have committed. Retry save and verify the operation converges.

## Settlement + notification pairing

Use two group members, Account A (payer) and Account B (recipient).

1. As A, create a payment confirmation request. Expect both:
   - `groups/{groupId}/settlements/{id}`
   - `users/{uidB}/notifications/{id}`
   with the exact same `{id}`.
2. Creating only the settlement document must be denied.
3. Creating only the notification must be denied.
4. Writing the notification under a different ID must be denied.
5. As B, confirm the payment in one batch updating settlement to `confirmed` and notification to `settled`. Expect allowed.
6. As B, reject a separate pending request in one batch updating settlement to `rejected` and notification to `dismissed`. Expect allowed.
7. As A, attempt to confirm/reject. Expect denied.
8. As another group member, attempt to resolve B's request. Expect denied.
9. Attempt to update only one of the paired documents. Expect denied.
10. Attempt to change amount, group, payer, or recipient during resolution. Expect denied.

## Regression checks

1. Create a regular `settle_up` reminder using a random notification ID. Expect allowed.
2. Verify ordinary reminders can be marked read/dismissed as allowed by the existing rules.
3. Create and read an expense as a group member. Expect allowed.
4. Verify non-members cannot read group expenses or private group payment details.
5. Accept a group invitation using the existing atomic invitation/join-claim/group update flow. Expect allowed.

## Device checks after emulator passes

1. Save a UPI ID and optional phone number for both test accounts.
2. Open the same group with both accounts so group copies exist.
3. On the payer account, open **Settle Now**, choose a full or partial amount, and launch an installed UPI app.
4. Cancel the UPI flow and return. Confirm the app does not claim payment success or update balances.
5. On a separate test run, complete a small test payment, return, and tap **I've Paid**.
6. On the recipient account, confirm or reject the request. Only confirmation should alter balances.

A UPI app launch result is not bank payment verification. The recipient's confirmation remains the ledger's trust boundary.
