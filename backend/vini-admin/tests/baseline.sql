-- Synthetic local staging baseline built only from audited column metadata.
-- Contains no production rows, defaults, secrets or account identifiers.
CREATE TABLE "activity_log" ("id" INTEGER PRIMARY KEY, "action" TEXT NOT NULL, "details" TEXT, "created_at" TEXT NOT NULL);
CREATE TABLE "blocked_devices" ("device_id" TEXT PRIMARY KEY, "reason" TEXT, "created_at" TEXT NOT NULL);
CREATE TABLE "config" ("key" TEXT PRIMARY KEY, "value" TEXT NOT NULL, "updated_at" TEXT NOT NULL);
CREATE TABLE "daily_status" ("id" TEXT PRIMARY KEY, "user_id" TEXT NOT NULL, "patch_id" TEXT NOT NULL, "status" TEXT NOT NULL, "report_date" TEXT NOT NULL, "created_at" TEXT NOT NULL);
CREATE TABLE "device_activations" ("id" TEXT PRIMARY KEY, "license_key" TEXT NOT NULL, "user_id" TEXT NOT NULL, "public_key" TEXT NOT NULL, "kid" TEXT NOT NULL, "status" TEXT, "created_at" TEXT NOT NULL, "last_seen_at" TEXT, "last_lease_at" TEXT);
CREATE TABLE "device_challenges" ("id" TEXT PRIMARY KEY, "activation_id" TEXT NOT NULL, "nonce" TEXT NOT NULL, "created_at" TEXT NOT NULL, "expires_at" TEXT NOT NULL, "used" INTEGER);
CREATE TABLE "device_seen" ("device_id" TEXT PRIMARY KEY, "first_seen" TEXT NOT NULL, "last_seen" TEXT NOT NULL);
CREATE TABLE "downloads" ("id" TEXT PRIMARY KEY, "user_id" TEXT NOT NULL, "patch_id" TEXT NOT NULL, "created_at" TEXT NOT NULL);
CREATE TABLE "license_attempts" ("id" INTEGER PRIMARY KEY, "scope" TEXT NOT NULL, "subject" TEXT NOT NULL, "created_at" INTEGER NOT NULL);
CREATE TABLE "messages" ("id" TEXT PRIMARY KEY, "title" TEXT NOT NULL, "content" TEXT NOT NULL, "type" TEXT, "target_hwid" TEXT, "active" INTEGER, "created_at" TEXT NOT NULL, "updated_at" TEXT NOT NULL);
CREATE TABLE "patches" ("id" TEXT PRIMARY KEY, "name" TEXT NOT NULL, "description" TEXT, "version" TEXT, "type" TEXT, "file_key" TEXT, "active" INTEGER, "created_at" TEXT NOT NULL, "updated_at" TEXT NOT NULL, "content_key" TEXT, "password" TEXT);
CREATE TABLE "permanence_rewards" ("id" TEXT PRIMARY KEY, "user_id" TEXT NOT NULL, "milestone_months" INTEGER NOT NULL, "reward_granted" INTEGER, "created_at" TEXT NOT NULL);
CREATE TABLE "rate_limits" ("key" TEXT PRIMARY KEY, "count" INTEGER NOT NULL, "window_start" INTEGER NOT NULL);
CREATE TABLE "referrals" ("id" TEXT PRIMARY KEY, "referrer_id" TEXT NOT NULL, "referred_id" TEXT NOT NULL, "confirmed" INTEGER, "reward_granted" INTEGER, "created_at" TEXT NOT NULL, "confirmed_at" TEXT);
CREATE TABLE "rewards_points" ("id" INTEGER PRIMARY KEY, "user_id" TEXT NOT NULL, "points" INTEGER NOT NULL, "created_at" TEXT NOT NULL);
CREATE TABLE "rewards_transactions" ("id" TEXT PRIMARY KEY, "user_id" TEXT NOT NULL, "type" TEXT NOT NULL, "points" INTEGER, "days_added" INTEGER, "description" TEXT, "created_at" TEXT NOT NULL);
CREATE TABLE "trust_reports" ("id" TEXT PRIMARY KEY, "user_id" TEXT NOT NULL, "patch_id" TEXT NOT NULL, "status" TEXT NOT NULL, "created_at" TEXT NOT NULL);
CREATE TABLE "user_patches" ("user_id" TEXT NOT NULL, "patch_id" TEXT NOT NULL, "created_at" TEXT NOT NULL, PRIMARY KEY("user_id","patch_id"));
CREATE TABLE "users" ("id" TEXT PRIMARY KEY, "username" TEXT NOT NULL, "hwid" TEXT, "license_key" TEXT, "is_premium" INTEGER, "is_active" INTEGER, "is_paused" INTEGER, "is_blocked" INTEGER, "permissions" TEXT, "created_at" TEXT NOT NULL, "updated_at" TEXT NOT NULL, "license_expires_at" TEXT, "platform" TEXT, "points" INTEGER, "referral_code" TEXT, "referred_by" TEXT, "paused_at" TEXT);
