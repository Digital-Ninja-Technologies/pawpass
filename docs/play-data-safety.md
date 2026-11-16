# Google Play Data safety answers

Written from what the app does today (Android permissions: internet, approximate location, notifications; no
advertising or crash reporting SDKs). Enter these in Play Console, App content, Data safety. If the app changes
what it collects, update this file and the form together.

## Section 1: overview

| Question | Answer |
| --- | --- |
| Does your app collect or share any of the required user data types? | Yes |
| Is all of the user data collected by your app encrypted in transit? | Yes |
| Do you provide a way for users to request that their data is deleted? | Yes. In the app: Me, Privacy and sharing, Delete my account. A web page for the same request is also needed (see "Gaps" below). |

## Section 2: data types

"Shared" below means sent to a third party for its own use. Our service providers (Supabase for hosting and sign in,
Firebase for push notifications, Resend for email) only process data for us, which Google does not count as sharing.
Showing a name to the business a person chooses to book, or a post to other people, is something the person starts and
expects, so it is not sharing either. Paystack is declared as shared (see Financial info) to be safe.

| Category | Data type | Collected | Shared | Optional | Why (purposes) |
| --- | --- | --- | --- | --- | --- |
| Personal info | Name | Yes | No | Required | App functionality, Account management |
| Personal info | Email address | Yes | No | Required | App functionality, Account management, Developer communications (reminder emails) |
| Personal info | Phone number | Yes | No | Optional | App functionality, Account management, Developer communications |
| Personal info | User IDs (account ID) | Yes | No | Required | App functionality, Account management, Analytics |
| Personal info | Address (area, and delivery address for a QR tag) | Yes | No | Optional | App functionality |
| Financial info | User payment info (a partner's bank account for payouts) | Yes | Yes, with Paystack, our payment processor | Optional (partners only) | App functionality, Fraud prevention, security and compliance |
| Financial info | Purchase history (bookings, orders, course purchases) | Yes | Yes, with Paystack | Required to buy | App functionality, Account management, Fraud prevention, security and compliance |
| Location | Approximate location | Yes | No | Optional (permission) | App functionality (nearest emergency vet, lost pet alerts near you) |
| Messages | Other in-app messages (chat) | Yes | No | Optional | App functionality |
| Photos and videos | Photos | Yes | No | Optional | App functionality |
| Files and docs | Files and docs (partner identity documents) | Yes | No | Optional (partners only) | App functionality, Fraud prevention, security and compliance |
| App activity | App interactions (six event names) | Yes | No | Required | Analytics |
| App activity | Other user-generated content (posts, comments, pet profiles and health records) | Yes | No | Optional | App functionality |
| Device or other IDs | Device or other IDs (push notification token) | Yes | No | Optional (permission) | App functionality |

Not collected: precise location, health and fitness (pet records are about pets, not the person), contacts, calendar,
web browsing, audio, crash logs, diagnostics, search history, advertising ID.

## Gaps to close before relying on these answers

1. **The privacy policy on ourpawpass.com says location is "not stored". That is not true.** The app saves a person's
   last approximate location (used for 30 days to find lost pet alerts near them), the place a lost pet was last seen, and
   sighting locations. The policy must say so, or Play will see a mismatch.
2. **The policy calls the six app events "anonymous".** They are tied to the signed in person's account. Say "no
   personal details", not "anonymous".
3. **The policy does not mention the push notification token** (Firebase) or reminder emails.
4. **Play needs a web page where people can ask for their account and data to be deleted**, as well as the in-app option.
   There is none yet. Add one (for example ourpawpass.com/delete-account) and enter it in Play Console.
5. **Target audience:** the policy says the app is for adults. Choose 18 and over in the target audience questions.
   The age rating is separate and must be Teen (12+), not Everyone, because people can post and message each other.
