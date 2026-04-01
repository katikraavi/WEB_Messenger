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
      SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename;
    `);
    console.log('Tables in database:');
    result.rows.forEach(r => console.log('  -', r.tablename));
  } catch (err) {
    console.error('Error:', err.message);
  } finally {
    await client.end();
  }
})();
