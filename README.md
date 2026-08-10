# Corporate Pooling Application — Backend

A ride-pooling backend for corporate employees and public users.

## Tech Stack
- **Runtime**: Node.js v24+
- **Framework**: Express.js
- **Database**: Supabase (PostgreSQL)
- **Auth**: Supabase Auth + JWT
- **Real-time**: Supabase Realtime (driver GPS)
- **File Storage**: Supabase Storage (documents)

## Project Structure
```
CorporatePooling/
├── src/
│   ├── server.js              # Express app entry point
│   ├── config/
│   │   └── supabase.js        # Supabase client
│   ├── middleware/
│   │   ├── auth.js            # JWT verification
│   │   ├── subscriptionGuard.js # 90-day trial check
│   │   └── upload.js          # Multer file upload
│   ├── routes/
│   │   ├── auth.js            # /auth/*
│   │   ├── rides.js           # /rides/*
│   │   ├── requests.js        # /requests/*
│   │   ├── wallet.js          # /wallet/*
│   │   └── admin.js           # /admin/*
│   ├── controllers/
│   │   ├── authController.js
│   │   ├── rideController.js
│   │   ├── requestController.js
│   │   ├── walletController.js
│   │   └── adminController.js
│   ├── services/
│   │   ├── matchingService.js  # Ported from KarmaRide matchingAlgorithm.js
│   │   ├── otpService.js       # OTP generation + email
│   │   ├── gpsService.js       # Supabase Realtime GPS
│   │   └── subscriptionService.js
│   └── utils/
│       ├── response.js         # Standard API response helpers
│       └── haversine.js        # Distance calculations
├── supabase/
│   └── migrations/
│       ├── 001_create_companies.sql
│       ├── 002_create_users.sql
│       ├── 003_create_vehicles.sql
│       ├── 004_create_rides.sql
│       ├── 005_create_ride_requests.sql
│       ├── 006_create_coin_transactions.sql
│       ├── 007_create_subscriptions.sql
│       ├── 008_create_driver_locations.sql
│       ├── 009_create_document_verifications.sql
│       ├── 010_rls_policies.sql
│       └── 011_stored_procedures.sql
├── .env.example
└── package.json
```

## Setup
1. Copy `.env.example` → `.env` and fill in values
2. Run SQL migrations in Supabase SQL Editor (in order)
3. `npm run dev`

## API Base URL
`http://localhost:3000/api/v1`
