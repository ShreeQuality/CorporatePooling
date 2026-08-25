# Corporate Pooling App: Third-Party API Requirements & Cost Analysis

This document outlines all external API dependencies required for the entire Corporate Pooling platform, their purpose according to the SRS, and estimated industry-standard costs.

## 1. KYC & Verification APIs (One-Time Costs)
These APIs are hit only once during user onboarding or when adding a new vehicle.

| Service Needed | Purpose in SRS | Recommended Provider(s) | Estimated Cost |
| :--- | :--- | :--- | :--- |
| **Aadhaar Verification** | Fetch verified Name, DOB, Gender, and City from DigiLocker. | Setu, SurePass, Digio | ~₹1.50 - ₹2.50 per success |
| **Liveness / Face Match** | Compare user selfie with Aadhaar photo to prevent fraud. | HyperVerge, IDfy, Karza | ~₹1.50 - ₹2.50 per match |
| **Vahan (Vehicle RC)** | Verify Vehicle Number, fetch Fuel Type (Petrol/EV), capacity, insurance/PUC expiry. | SurePass, Karza | ~₹1.50 - ₹2.50 per vehicle |
| **Sarathi (Driving License)** | Verify Driver's License validity and details. | SurePass, Karza | ~₹1.50 - ₹2.50 per driver |

> **Business Impact:** The total KYC cost is approx. **₹3-₹4 for a pure rider** and **₹6-₹10 for a driver**. This is a one-time Customer Acquisition Cost (CAC). Once verified, the data is saved in our Supabase Database. Subsequent rides cost ₹0 in KYC fees.

---

## 2. Location & Routing APIs (Recurring Usage)
These APIs are used daily for booking rides, calculating distances, and fetching addresses.

| Service Needed | Purpose in SRS | Recommended Provider(s) | Estimated Cost |
| :--- | :--- | :--- | :--- |
| **Maps & Routing** | Places Autocomplete, Geocoding (Lat/Lng to Address), Directions Polyline, Distance Matrix. | **Ola Maps** (Krutrim) | **Free tier (Up to 5M hits/mo)**, then ~₹50-₹100 per 1,000 hits. |

> **Business Impact:** We explicitly chose Ola Maps over Google Maps to significantly cut operational costs, as Google Maps charges ~$5 USD per 1,000 hits which destroys ride-sharing margins.

---

## 3. Communications (Recurring Usage)
Used for OTPs, transactional updates, and push notifications.

| Service Needed | Purpose in SRS | Recommended Provider(s) | Estimated Cost |
| :--- | :--- | :--- | :--- |
| **SMS Gateway** | Phone number verification (OTP). | MSG91, Fast2SMS, Twilio | ~₹0.15 - ₹0.20 per SMS |
| **Email Gateway** | Corporate Domain OTPs, B2B HR Invites, Invoices. | AWS SES, SendGrid, Resend | Practically Free (Free tiers cover startup volume) |
| **Push Notifications** | Real-time alerts for ride matched, driver arrived, chat messages. | Firebase Cloud Messaging (FCM) | **100% Free** |

---

## 4. Payment Gateway
Used for purchasing Karma Coin subscriptions or funding corporate wallets.

| Service Needed | Purpose in SRS | Recommended Provider(s) | Estimated Cost |
| :--- | :--- | :--- | :--- |
| **Payment Gateway** | Processing UPI, Cards, NetBanking. | Razorpay, Cashfree, PhonePe PG | **Zero upfront.** ~1.8% to 2.0% per successful transaction. |

---

## 5. Cloud Infrastructure
Backend servers, database, and object storage.

| Service Needed | Purpose in SRS | Recommended Provider(s) | Estimated Cost |
| :--- | :--- | :--- | :--- |
| **Backend & DB** | PostgreSQL Database, Edge Functions, Row-Level Security, Auth, S3 Bucket for Selfies/RC photos. | Supabase | **$25/month** (Pro Plan). Scales predictably. |

---

## Conclusion
During the development phase, the backend utilizes **Mock APIs** for KYC (Vahan/Aadhaar) to ensure zero testing costs. 

Prior to production launch, you will need to register with a KYC aggregator (e.g., SurePass), Ola Maps, and MSG91, and swap their Production API Keys into the `.env` file of this backend repository.
