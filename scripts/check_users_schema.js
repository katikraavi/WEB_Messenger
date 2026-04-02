#!/usr/bin/env node

const { Client } = require('pg');

const client = new Client({
  connectionString: process.env.DATABASE_URL,
  connectionTimeoutMillis: 10000,
});

(async () => {
  try {
    await client.connect();
    const result = await client.query(`
      SELECT column_name, data_type, is_nullable FROM information_schema.columns 
      WHERE table_name = 'users' ORDER BY ordinal_position;
    `);
    console.log('Users table columns:');
    result.rows.forEach(r => console.log(`  - ${r.column_name}: ${r.data_type} ${r.is_nullable === 'NO' ? '(NOT NULL)' : '(nullable)'}`));
  } catch (err) {
    console.error('Error:', err.message);
  } finally {
    await client.end();
  }
})();
