#!/usr/bin/env node

const { Client } = require('pg');

const client = new Client({
  connectionString: process.env.DATABASE_URL,
  connectionTimeoutMillis: 10000,
});

(async () => {
  try {
    await client.connect();
    
    console.log('\n📋 SCHEMA_MIGRATIONS structure:');
    const columns = await client.query(`
      SELECT column_name, data_type FROM information_schema.columns 
      WHERE table_name = 'schema_migrations' ORDER BY ordinal_position;
    `);
    console.log('Columns:');
    columns.rows.forEach(r => console.log(`  - ${r.column_name}: ${r.data_type}`));
    
    console.log('\nData in schema_migrations:');
    const data = await client.query('SELECT * FROM schema_migrations LIMIT 5;');
    if (data.rows.length === 0) {
      console.log('  ✅ Empty');
    } else {
      console.log(`  Found ${data.rows.length} records (sample)`);
      data.rows.forEach((r, i) => console.log(`    ${i+1}. ${JSON.stringify(r)}`));
    }
    
    console.log('\n🔍 POLL-related tables:');
    const pollTables = ['polls', 'poll_options', 'poll_votes'];
    for (const table of pollTables) {
      const result = await client.query(`SELECT COUNT(*) as count FROM ${table};`);
      console.log(`  - ${table}: ${result.rows[0].count} rows`);
    }
    
  } catch (err) {
    console.error('Error:', err.message);
  } finally {
    await client.end();
  }
})();
