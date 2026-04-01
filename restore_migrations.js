#!/usr/bin/env node

const { Client } = require('pg');
const fs = require('fs');
const path = require('path');

const client = new Client({
  connectionString: process.env.DATABASE_URL,
  connectionTimeoutMillis: 10000,
});

// Get all migrations from backend/migrations directory
const migrationsDir = '/home/katikraavi/web-messenger/backend/migrations';
const files = fs.readdirSync(migrationsDir)
  .filter(f => f.endsWith('.dart'))
  .sort();

console.log('Found migration files:');
files.forEach((f, i) => console.log(`  ${i+1}. ${f}`));

const migrations = files.map((f, index) => {
  const match = f.match(/^(\d+)_(.+)\.dart$/);
  if (!match) return null;
  // Use index as version to ensure uniqueness
  const version = index + 1;
  const description = match[2].replace(/_/g, ' ');
  return { version, description };
}).filter(m => m !== null);

console.log(`Found ${migrations.length} migrations to restore`);

async function restoreMigrations() {
  try {
    await client.connect();
    
    // Check current state
    const check = await client.query('SELECT COUNT(*) as cnt FROM schema_migrations;');
    console.log(`Current migrations in DB: ${check.rows[0].cnt}`);
    
    if (check.rows[0].cnt > 0) {
      console.log('✅ Migrations already exist, skipping restore');
      return;
    }
    
    console.log('Restoring migrations...');
    for (const mig of migrations) {
      await client.query(
        'INSERT INTO schema_migrations (version, description, executed_at) VALUES ($1, $2, NOW())',
        [mig.version, mig.description]
      );
    }
    
    const result = await client.query('SELECT COUNT(*) as cnt FROM schema_migrations;');
    console.log(`✅ Migrations restored: ${result.rows[0].cnt} records`);
    
  } catch (err) {
    console.error('❌ Error:', err.message);
  } finally {
    await client.end();
  }
}

restoreMigrations();
