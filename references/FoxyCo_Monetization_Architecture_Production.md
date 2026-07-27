# FoxyCo Entitlement & Monetization Architecture (Production Edition)

This document adds production-ready sections:

- Entitlement state machine
- Priority rules
- Subscription edge cases
- Firestore security rules
- Cloud Function responsibilities
- API contracts
- Failure handling
- Sequence flow
- Cost planning
- Feature flags
- Analytics
- Admin roles
- Backup strategy
- Privacy & compliance
- Normalized entitlement schema
- Audit history
- Development roadmap

## Entitlement State Machine
```
NEW_USER -> ANONYMOUS -> GOOGLE_SIGN_IN -> TRIAL_ACTIVE
TRIAL_ACTIVE -> PURCHASE_ACTIVE
TRIAL_ACTIVE -> REDEEM_ACTIVE
TRIAL_ACTIVE -> TRIAL_EXPIRED -> LOCKED
```

## Priority
1. Admin
2. Lifetime
3. Subscription
4. Redeem
5. Trial
6. Locked

## Cloud Functions
createTrial(), verifyPurchase(), redeemCode(), refreshEntitlement(), generateCampaign(), grantAdminAccess(), revokeAccess(), cleanupExpiredTrials()

## Firestore Security
- users: owner read/write
- entitlements: owner read, Cloud Functions write
- redeemCodes: Cloud Functions only

## Failure Handling
- Cached signed token when offline
- Retry Firestore
- Disable purchases if Billing unavailable
- RTDN + periodic reconciliation

## Analytics
Trial Started, Converted, Renewed, Cancelled, Refund, Redeem, Restore, Locked Feature Clicked.

## Admin Roles
Owner, Support, Marketing, Developer.

## Backup
Daily Firestore export with 30-day retention.

## Development Roadmap
Anonymous Auth -> Google Sign-In -> Trial -> Billing -> Redeem -> RTDN -> Admin Dashboard -> Analytics -> Security -> Launch.
