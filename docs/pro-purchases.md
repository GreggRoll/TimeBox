# Time Boxed Pro

Both the monthly subscription and lifetime purchase unlock saved-day history and individual time-box exports to Apple Calendar and Reminders. Today's planner stays free. Saved days remain in local storage when access ends.

## App Store Connect setup

Existing app: [6762071236 — Time Boxed](https://appstoreconnect.apple.com/apps/6762071236).

Draft products and English localizations were created under that app on September 15, 2026. Their identifiers match `ProStore` and the StoreKit test configuration.

| Product ID | App Store Connect ID | Type | US price status |
| --- | --- | --- | --- |
| `com.GregAdams.TimeBoxed.pro.monthly` | `6812531377` | Auto-renewable, one month | Requested $0.99/month; starting price still needs saving |
| `com.GregAdams.TimeBoxed.pro.lifetime` | `6812531093` | Non-consumable | $9.99 starting price saved and verified |

Subscription group: **Time Boxed Pro**, ID `22388123`.

Apple's API returns the $0.99 US subscription price point but rejects saving the initial price with a pricing-information error. Attempts with a future date confirm that a starting price is required first. Finish the initial monthly price in the App Store Connect web UI, which currently requires user sign-in in the in-app browser. No monthly price has been saved.

Both products remain in `MISSING_METADATA`; neither has been submitted for review. Finish availability/territory choices and review screenshots, confirm account agreements and tax/banking status, and submit them with the app when ready. Live localized prices come from StoreKit.

The app's English App Store Connect localization currently has no Privacy Policy URL, Privacy Choices URL, or privacy-policy text. A public policy is still needed.

Set the app target's `INFOPLIST_KEY_ProPrivacyPolicyURL` build setting to the real public HTTPS privacy policy URL for both Debug and Release. Until configured, the Pro page explains that the policy is unavailable and disables new purchases; restore purchases remains available. The page uses Apple's standard EULA. Also provide the policy and terms links in App Store metadata. See [Apple's subscription guidance](https://developer.apple.com/app-store/subscriptions/).

The product drafts, localizations, and lifetime price are saved in App Store Connect. No app or product review submission, build upload, or release was performed.

## Implementation

- `ProStore` verifies StoreKit 2 current entitlements at launch, when returning to the foreground, while active, after purchases/restores, and when transactions change. Refunds and expired subscriptions lose access. StoreKit billing grace period entitlements retain access.
- A disabled, accessibility-hidden calendar sits beneath the blurred history overlay. The unlock button, sidebar Pro entry, and export actions open the same Pro sheet.
- Access enforcement returns the planner to today when necessary, preserving the old day's autosave. ExportManager also checks entitlements before requesting EventKit access.
- Purchase cancellation, pending approval, verification failure, unavailable products, and restore errors have separate outcomes. A pending payment never unlocks access early.
- Active subscribers see their access state and subscription management. Lifetime owners are not offered another purchase.

## Local testing

`TimeBoxedTests/Pro.storekit` contains the requested test prices. It is included only in the test bundle and does not replace the production App Store catalog. `ProPurchaseTests` starts an isolated StoreKit test session to verify free export denial, monthly purchase, expiration, lifetime purchase, restore, and refund. It also covers history access around a local midnight boundary.

For interactive purchase testing in Xcode, select `TimeBoxedTests/Pro.storekit` in Edit Scheme → Run → Options → StoreKit Configuration. Use Xcode's transaction manager for pending approval, refund, and renewal scenarios. Return the scheme to None before testing with an App Store sandbox account or TestFlight. Use a real published policy URL to enable the purchase buttons.

Before release, check the purchase sheet on small iPhones, iPad, larger text sizes, and VoiceOver; verify sandbox purchases, restore on a second device, pending approval, canceled payment, offline launch, expiration, and refunds. No live charge should be needed during this testing.

## Verification completed

- Simulator build succeeds.
- All 9 XCTest tests passed on iOS 17.5, including both prices/products, purchase, expiration, lifetime, restore, refund, and denied free exports.
- Visually checked the blurred calendar and centered Unlock History button, and opened the Pro sheet on iPhone 15 Pro in dark mode. The sheet displayed the local StoreKit $0.99/month and $9.99 lifetime options.
- iOS 26.3 StoreKit tests could not load their configuration; this matches the issue described in [Apple's StoreKit Test forum](https://developer.apple.com/forums/tags/storekittest?page=2). Use iOS 17.5 for the bundled test suite on this machine until its newer simulator runtime is updated.
- Live App Store sandbox purchases and the public Privacy Policy link remain release setup work.

## Suggested future Pro features

1. Reusable day templates and recurring routines: the most useful next addition for daily use.
2. Weekly reviews: planned focus hours, category totals, and trends derived from saved days.
3. Batch export: send an entire day to Calendar or Reminders, with duplicate prevention.
4. Searchable history and tags: find past projects or tasks quickly.
5. iCloud sync and backup: useful across devices, but requires additional storage and conflict handling.

These are ideas, not promises on the current paywall. At $9.99, lifetime costs approximately ten monthly payments, so it is a generous early-supporter price; reconsider it as recurring service costs grow.
