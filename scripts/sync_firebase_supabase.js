/**
 * Direct Terminal Sync CLI for Firebase Firestore -> Supabase PostgreSQL
 * Project: Game Tracker / Ludo Realm
 * 
 * Usage:
 *   Batch One-Time Sync: node scripts/sync_firebase_supabase.js --batch
 *   Realtime Continuous Watch Sync: node scripts/sync_firebase_supabase.js --watch
 */

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');
const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

// Configuration
const SUPABASE_URL = process.env.SUPABASE_URL || 'https://qnxmdslhixdmzujdjaoj.supabase.co';
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || 'sb_publishable_SeX9TxJqbgdAjG6sin70Uw_DsnpFHNR';
const SERVICE_ACCOUNT_PATH = process.env.FIREBASE_SERVICE_ACCOUNT_PATH || path.join(__dirname, '../serviceAccountKey.json');

// Initialize Firebase Admin
if (!fs.existsSync(SERVICE_ACCOUNT_PATH)) {
  console.error(`\n❌ ERROR: Firebase Service Account Key not found at:\n   ${SERVICE_ACCOUNT_PATH}`);
  console.error(`\n📋 HOW TO FIX:`);
  console.error(`  1. Go to Firebase Console -> Project Settings -> Service accounts.`);
  console.error(`  2. Click "Generate new private key".`);
  console.error(`  3. Save the downloaded JSON file as 'serviceAccountKey.json' in your root project directory.\n`);
  process.exit(1);
}

const serviceAccount = require(SERVICE_ACCOUNT_PATH);
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});
const db = admin.firestore();

// Initialize Supabase Client
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

/**
 * 1. Sync App Users
 */
async function syncUsers() {
  console.log('🔄 Fetching users from Firestore...');
  const snapshot = await db.collection('users').get();
  if (snapshot.empty) {
    console.log('  └─ No users found in Firestore.');
    return;
  }

  const rows = snapshot.docs.map(doc => {
    const d = doc.data();
    return {
      uid: doc.id,
      email: d.email || null,
      display_name: d.displayName || d.display_name || null,
      is_admin: d.isAdmin ?? d.is_admin ?? false,
      updated_at: new Date().toISOString()
    };
  });

  const { error } = await supabase.from('app_users').upsert(rows, { onConflict: 'uid' });
  if (error) console.error('  ❌ app_users sync error:', error.message);
  else console.log(`  ✅ Synced ${rows.length} users into Supabase app_users table.`);
}

/**
 * 2. Sync Devices
 */
async function syncDevices() {
  console.log('🔄 Fetching devices from Firestore...');
  const snapshot = await db.collection('devices').get();
  if (snapshot.empty) {
    console.log('  └─ No devices found in Firestore.');
    return;
  }

  const rows = snapshot.docs.map(doc => {
    const d = doc.data();
    return {
      device_id: doc.id,
      platform: d.platform || 'android',
      display_name: d.displayName || d.display_name || null,
      email: d.email || null,
      native_capture_enabled: d.nativeCaptureEnabled ?? d.native_capture_enabled ?? false,
      latitude: d.latitude || null,
      longitude: d.longitude || null,
      accuracy: d.accuracy || null,
      last_location_time: d.lastLocationTime || null,
      last_seen_at: new Date().toISOString()
    };
  });

  const { error } = await supabase.from('devices').upsert(rows, { onConflict: 'device_id' });
  if (error) console.error('  ❌ devices sync error:', error.message);
  else console.log(`  ✅ Synced ${rows.length} devices into Supabase devices table.`);
}

/**
 * 3. Sync Screenshot Requests
 */
async function syncScreenshotRequests() {
  console.log('🔄 Fetching screenshot requests from Firestore...');
  const snapshot = await db.collection('screenshot_requests').get();
  if (snapshot.empty) {
    console.log('  └─ No screenshot requests found in Firestore.');
    return;
  }

  const rows = snapshot.docs.map(doc => {
    const d = doc.data();
    return {
      id: doc.id,
      target_device_id: d.targetDeviceId || d.target_device_id || '',
      requested_by_device_id: d.requestedByDeviceId || d.requested_by_device_id || null,
      request_type: d.requestType || d.request_type || 'screenshot',
      camera_facing: d.cameraFacing || d.camera_facing || 'front',
      status: d.status || 'pending',
      screenshot_url: d.screenshotUrl || d.screenshot_url || null,
      error: d.error || null,
      failure_reason: d.failureReason || d.failure_reason || null
    };
  });

  const { error } = await supabase.from('screenshot_requests').upsert(rows, { onConflict: 'id' });
  if (error) console.error('  ❌ screenshot_requests sync error:', error.message);
  else console.log(`  ✅ Synced ${rows.length} requests into Supabase screenshot_requests table.`);
}

/**
 * 4. Sync Ludo Rooms
 */
async function syncLudoRooms() {
  console.log('🔄 Fetching ludo rooms from Firestore...');
  const snapshot = await db.collection('ludo_rooms').get();
  if (snapshot.empty) {
    console.log('  └─ No ludo rooms found in Firestore.');
    return;
  }

  const rows = snapshot.docs.map(doc => {
    const d = doc.data();
    const roomCode = doc.id || d.roomCode || d.room_code || '';
    return {
      id: roomCode,
      room_code: roomCode,
      host_uid: d.hostUid || d.host_uid || '',
      status: d.status || 'waiting',
      current_turn_index: d.currentTurnIndex ?? d.current_turn_index ?? 0,
      dice_value: d.diceValue ?? d.dice_value ?? 1,
      is_dice_rolled: d.isDiceRolled ?? d.is_dice_rolled ?? false,
      is_moving: d.isMoving ?? d.is_moving ?? false,
      consecutive_sixes: d.consecutiveSixes ?? d.consecutive_sixes ?? 0,
      players_json: d.players || d.players_json || [],
      game_state_json: d.gameStateData || d.game_state_json || {},
      updated_at: new Date().toISOString()
    };
  });

  const { error } = await supabase.from('ludo_rooms').upsert(rows, { onConflict: 'id' });
  if (error) console.error('  ❌ ludo_rooms sync error:', error.message);
  else console.log(`  ✅ Synced ${rows.length} ludo rooms into Supabase ludo_rooms table.`);
}

/**
 * Main Execution Batch Mode
 */
async function runBatchSync() {
  console.log('=====================================================');
  console.log('🚀 FIREBASE -> SUPABASE TERMINAL BATCH SYNC');
  console.log('=====================================================\n');

  try {
    await syncUsers();
    await syncDevices();
    await syncScreenshotRequests();
    await syncLudoRooms();
    console.log('\n✨ Batch sync completed successfully!');
  } catch (err) {
    console.error('\n❌ Error during sync execution:', err);
  } finally {
    process.exit(0);
  }
}

/**
 * Realtime Continuous Watch Sync Mode
 */
function runRealtimeWatchSync() {
  console.log('=====================================================');
  console.log('⚡ FIREBASE -> SUPABASE REALTIME WATCH SYNC DAEMON');
  console.log('=====================================================\n');
  console.log('Listening for live Firestore updates in terminal background...\n');

  const collections = ['users', 'devices', 'screenshot_requests', 'ludo_rooms'];

  collections.forEach(colName => {
    db.collection(colName).onSnapshot(snapshot => {
      snapshot.docChanges().forEach(async change => {
        const docId = change.doc.id;
        const d = change.doc.data();

        if (change.type === 'removed') {
          console.log(`[LISTEN] 🗑️ Document removed in ${colName}: ${docId}`);
          return;
        }

        console.log(`[LISTEN] ⚡ Change detected in ${colName} (${change.type}): ${docId}`);

        if (colName === 'users') {
          await supabase.from('app_users').upsert({
            uid: docId,
            email: d.email || null,
            display_name: d.displayName || d.display_name || null,
            is_admin: d.isAdmin ?? d.is_admin ?? false,
            updated_at: new Date().toISOString()
          }, { onConflict: 'uid' });
        } else if (colName === 'devices') {
          await supabase.from('devices').upsert({
            device_id: docId,
            platform: d.platform || 'android',
            display_name: d.displayName || d.display_name || null,
            email: d.email || null,
            native_capture_enabled: d.nativeCaptureEnabled ?? d.native_capture_enabled ?? false,
            latitude: d.latitude || null,
            longitude: d.longitude || null,
            accuracy: d.accuracy || null,
            last_location_time: d.lastLocationTime || null,
            last_seen_at: new Date().toISOString()
          }, { onConflict: 'device_id' });
        } else if (colName === 'screenshot_requests') {
          await supabase.from('screenshot_requests').upsert({
            id: docId,
            target_device_id: d.targetDeviceId || d.target_device_id || '',
            requested_by_device_id: d.requestedByDeviceId || d.requested_by_device_id || null,
            request_type: d.requestType || d.request_type || 'screenshot',
            camera_facing: d.cameraFacing || d.camera_facing || 'front',
            status: d.status || 'pending',
            screenshot_url: d.screenshotUrl || d.screenshot_url || null,
            error: d.error || null,
            failure_reason: d.failureReason || d.failure_reason || null
          }, { onConflict: 'id' });
        } else if (colName === 'ludo_rooms') {
          await supabase.from('ludo_rooms').upsert({
            id: docId,
            room_code: docId,
            host_uid: d.hostUid || d.host_uid || '',
            status: d.status || 'waiting',
            current_turn_index: d.currentTurnIndex ?? d.current_turn_index ?? 0,
            dice_value: d.diceValue ?? d.dice_value ?? 1,
            is_dice_rolled: d.isDiceRolled ?? d.is_dice_rolled ?? false,
            is_moving: d.isMoving ?? d.is_moving ?? false,
            consecutive_sixes: d.consecutiveSixes ?? d.consecutive_sixes ?? 0,
            players_json: d.players || d.players_json || [],
            game_state_json: d.gameStateData || d.game_state_json || {},
            updated_at: new Date().toISOString()
          }, { onConflict: 'id' });
        }
      });
    });
  });
}

// Mode Selection
const isWatchMode = process.argv.includes('--watch');
if (isWatchMode) {
  runRealtimeWatchSync();
} else {
  runBatchSync();
}
