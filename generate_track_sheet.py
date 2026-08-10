import csv
import os

data = [
    ["Phase", "Step ID", "Component / Module", "Description / Detail", "Technology", "Status", "Target Layer"],
    
    # --- COMPLETED BACKEND & SUPABASE (STEPS 1 - 20) ---
    ["Backend Completed", "BE-01", "Project Scaffolding", "Node.js Express API server with CORS, Helmet, Rate Limiting", "Node.js / Express", "100% Completed", "Backend API"],
    ["Backend Completed", "BE-02", "Dual Supabase Client", "Configured Anon client (RLS) + Service Role admin client", "@supabase/supabase-js", "100% Completed", "Backend API"],
    ["Backend Completed", "BE-03", "Database Migration 001", "companies table for corporate accounts and subscription trials", "PostgreSQL / Supabase", "100% Completed", "Database"],
    ["Backend Completed", "BE-04", "Database Migration 002", "users table & otp_verifications for corporate + public accounts", "PostgreSQL / Supabase", "100% Completed", "Database"],
    ["Backend Completed", "BE-05", "Database Migration 003", "vehicles table for driver registered vehicles (Bike/Car/Auto)", "PostgreSQL / Supabase", "100% Completed", "Database"],
    ["Backend Completed", "BE-06", "Database Migration 004", "rides table with route_points, seats, time_type, departs", "PostgreSQL / Supabase", "100% Completed", "Database"],
    ["Backend Completed", "BE-07", "Database Migration 005", "ride_requests table with pickup/drop points, OTP, arrival flags", "PostgreSQL / Supabase", "100% Completed", "Database"],
    ["Backend Completed", "BE-08", "Database Migration 006", "coin_transactions append-only ledger & admin_users table", "PostgreSQL / Supabase", "100% Completed", "Database"],
    ["Backend Completed", "BE-09", "Database Migration 007", "subscriptions table for 90-day corporate free trial", "PostgreSQL / Supabase", "100% Completed", "Database"],
    ["Backend Completed", "BE-10", "Database Migration 008", "driver_locations table enabled for Supabase Realtime GPS", "PostgreSQL / Supabase", "100% Completed", "Database"],
    ["Backend Completed", "BE-11", "Database Migration 009", "document_verifications table for Aadhaar, DL, Photo uploads", "PostgreSQL / Supabase", "100% Completed", "Database"],
    ["Backend Completed", "BE-12", "Database Migration 010", "Row-Level Security (RLS) policies applied across all 11 tables", "PostgreSQL RLS", "100% Completed", "Database"],
    ["Backend Completed", "BE-13", "Database Migration 011", "Atomic RPC stored procedures (accept, complete, refund, credit)", "PL/pgSQL", "100% Completed", "Database"],
    ["Backend Completed", "BE-14", "Database Migration 012", "Edge case tables (domains, ratings, notifications, SOS, coin packs)", "PostgreSQL / Supabase", "100% Completed", "Database"],
    ["Backend Completed", "BE-15", "Auth Controller & Service", "Corporate domain OTP, public reg, doc upload, login, JWT", "Node.js / Express", "100% Completed", "Backend API"],
    ["Backend Completed", "BE-16", "Matching Engine Service", "Ported KarmaRide 2-Phase route algorithm + day/time flexibility", "Node.js / Express", "100% Completed", "Backend API"],
    ["Backend Completed", "BE-17", "Ride Lifecycle Controller", "Post ride, search rides, start ride, cancel, seat updates", "Node.js / Express", "100% Completed", "Backend API"],
    ["Backend Completed", "BE-18", "Request Lifecycle Controller", "Create request, lock coins, OTP scan, mutual arrival confirm", "Node.js / Express", "100% Completed", "Backend API"],
    ["Backend Completed", "BE-19", "Wallet & Admin Controller", "Balance fetch, ledger, admin document review queue, analytics", "Node.js / Express", "100% Completed", "Backend API"],
    ["Backend Completed", "BE-20", "Supabase Storage Bucket", "Created public 'documents' storage bucket for Aadhaar/DL uploads", "Supabase Storage", "100% Completed", "Storage"],

    # --- FLUTTER MOBILE APP ROADMAP (STEPS 21 - 35) ---
    ["Flutter App", "MOB-01", "Flutter Project Scaffolding", "Initialize Flutter app with package dependencies & folder structure", "Flutter / Dart", "100% Completed", "Mobile App"],
    ["Flutter App", "MOB-02", "Core Design System & Theme", "Setup color tokens, typography, dark/light theme, custom buttons", "Flutter / Material 3", "100% Completed", "Mobile App"],
    ["Flutter App", "MOB-03", "Supabase SDK & API Client", "Initialize Supabase client & REST API service layer", "supabase_flutter / http", "100% Completed", "Mobile App Services"],
    ["Flutter App", "MOB-04", "Auth & Onboarding Screens", "Login, Corporate Domain Check, Email OTP Verification UI", "Flutter / Provider", "100% Completed", "Mobile App Feature"],
    ["Flutter App", "MOB-05", "Document & Vehicle Upload UI", "Aadhaar/DL camera upload & vehicle reg (MH-12-AB-1234)", "image_picker / Flutter", "100% Completed", "Mobile App Feature"],
    ["Flutter App", "MOB-06", "Role Switching Navigation", "Dynamic in-app toggle bar (Driver Mode <-> Rider Mode)", "Flutter / State", "100% Completed", "Mobile App Navigation"],
    ["Flutter App", "MOB-07", "Driver: Post Ride & Route Pick", "Google Maps location picker, polyline route preview, seat & coin price", "google_maps_flutter", "100% Completed", "Mobile App Feature"],
    ["Flutter App", "MOB-08", "Rider: Find & Match Rides UI", "Search origin/destination, match score cards (100%), route overlap map", "google_maps_flutter", "100% Completed", "Mobile App Feature"],
    ["Flutter App", "MOB-09", "Ride Booking Request Flow", "Rider request card, driver accept/reject dialog, coin locking status", "Flutter / WebSockets", "100% Completed", "Mobile App Feature"],
    ["Flutter App", "MOB-10", "Live GPS & Realtime Map Screen", "Supabase Realtime driver location stream, moving marker, ETA text", "google_maps_flutter / Realtime", "100% Completed", "Mobile App Feature"],
    ["Flutter App", "MOB-11", "Pickup 4-Digit OTP Verification", "Driver OTP entry modal, scanner, onboard status update", "Flutter / Custom Modal", "100% Completed", "Mobile App Feature"],
    ["Flutter App", "MOB-12", "Mutual Arrival & Coin Settlement", "Driver/Rider Arrived buttons, mutual confirm alert, coin animation", "Flutter / Animations", "100% Completed", "Mobile App Feature"],
    ["Flutter App", "MOB-13", "Coin Wallet & Transaction History", "Coin balance card, earn/spend history list, buy coin packages shop", "Flutter / Wallet UI", "100% Completed", "Mobile App Feature"],
    ["Flutter App", "MOB-14", "Ratings, Reviews & SOS Button", "5-star rating modal, emergency SOS floating button with location payload", "Flutter / Safety", "100% Completed", "Mobile App Feature"],
    ["Flutter App", "MOB-15", "Testing & APK / Bundle Build", "Unit tests, API integration tests, Android APK & iOS build setup", "Flutter / Dart Test", "100% Completed", "Release"]
]

file_path = "Corporate_Pooling_Build_Track_Sheet.csv"
with open(file_path, mode="w", newline="", encoding="utf-8") as f:
    writer = csv.writer(f)
    writer.writerows(data)

print(f"Excel CSV Track Sheet successfully updated at: {os.path.abspath(file_path)}")
