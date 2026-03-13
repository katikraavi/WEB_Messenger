# User Search Feature (Spec 006) - Testing Guide

## Implementation Status: ✅ COMPLETE

All components have been implemented and integrated for the User Search feature.

### Backend Implementation
- ✅ Database migration (013_add_search_indexes.dart)
- ✅ SearchService with username and email search methods
- ✅ UserSearchResult model with JSON serialization
- ✅ SearchQuery validation model
- ✅ Mock search endpoints with 6 test users
- ✅ Authentication checking on search endpoints
- ✅ Query validation and error handling
- ✅ Result pagination with configurable limits

### Frontend Implementation
- ✅ SearchScreen with UI layout
- ✅ SearchBarWidget with 500ms debounce
- ✅ SearchResultListWidget with result display
- ✅ search_form_provider (Riverpod StateNotifier)
- ✅ search_results_provider (Riverpod FutureProvider)
- ✅ SearchService HTTP wrapper for API calls
- ✅ Navigation integration in app.dart

## Testing Instructions

### 1. Manual Backend Testing

Start the backend and test search endpoints with curl:

```bash
# Start backend
cd backend
dart run lib/server.dart

# In another terminal, test search by username
curl -X GET "http://localhost:8081/search/username?q=alice&limit=10" \
  -H "Authorization: Bearer test-token" \
  -H "Content-Type: application/json"

# Test search by email
curl -X GET "http://localhost:8081/search/email?q=alice@&limit=10" \
  -H "Authorization: Bearer test-token" \
  -H "Content-Type: application/json"

# Test with missing auth (should return 401)
curl -X GET "http://localhost:8081/search/username?q=alice&limit=10"

# Test with invalid query (should return 400)
curl -X GET "http://localhost:8081/search/username?q=&limit=10" \
  -H "Authorization: Bearer test-token"
```

### 2. Frontend Manual Testing

1. Start the backend server
2. Run the Flutter frontend:
   ```bash
   cd frontend
   flutter pub get
   flutter run
   ```
3. Click "Search Users" button in the app
4. Try these search scenarios:

   **Username Search:**
   - Search "alice" → should find "alice" and "alice_smith"
   - Search "ALI" → should find results (case-insensitive)
   - Search "bob" → should find "bob" and "bob_jones"
   - Search "xyz" → should show empty results

   **Email Search:**
   - Switch to "Email" tab
   - Search "alice@" → should find alice@example.com and alice.smith@example.com
   - Search "test.org" → should find diane@test.org
   - Search "invalid@" → should show empty results

   **Error Cases:**
   - Search with empty query → error message
   - Search with 1 character → error message
   - Tap on result → should navigate to profile (placeholder for now)

### 3. Mock Test Users

The backend provides 6 mock users for testing:

| User ID | Username | Email | Private Profile |
|---------|----------|-------|-----------------|
| user-001 | alice | alice@example.com | false |
| user-002 | bob | bob@example.com | false |
| user-003 | charlie | charlie@example.com | false |
| user-004 | alice_smith | alice.smith@example.com | false |
| user-005 | bob_jones | bob.jones@example.com | false |
| user-006 | diane | diane@test.org | false |

### 4. API Endpoints

**Search by Username:**
- Endpoint: `GET /search/username`
- Query Parameters: `q` (required), `limit` (optional, default: 10)
- Auth: Required (Bearer token)
- Response: `{ "data": [...], "count": n, "query": "...", "type": "username" }`

**Search by Email:**
- Endpoint: `GET /search/email`
- Query Parameters: `q` (required), `limit` (optional, default: 10)
- Auth: Required (Bearer token)
- Response: `{ "data": [...], "count": n, "query": "...", "type": "email" }`

### 5. Feature Verification Checklist

- [ ] Backend search by username works with mock data
- [ ] Backend search by email works with mock data
- [ ] Search endpoints require authentication
- [ ] Search results are case-insensitive
- [ ] Search results are limited by `limit` parameter
- [ ] Empty results show "No results found" message
- [ ] Invalid queries show appropriate error messages
- [ ] Search bar has 500ms debounce
- [ ] Search type toggle (Username ↔ Email) works
- [ ] Results list displays username, email, and avatar
- [ ] Tapping a result provides user interaction feedback

## Known Limitations

1. **Database**: Currently using mock in-memory data. Real database integration deferred.
2. **Authentication**: Backend accepts any Bearer token for testing. Real JWT validation deferred.
3. **Profile Navigation**: Currently shows placeholder. Real profile view integration deferred.
4. **Privacy**: All mock users have is_private_profile=false. Privacy filtering implementation deferred.

## Next Steps for Production

1. Integrate real PostgreSQL database connection pool
2. Implement JWT token validation
3. Add database population with real users
4. Implement rate limiting for search queries
5. Add profile image retrieval from database
6. Implement privacy profile filtering
7. Add search result analytics/logging
8. Performance optimization for large user databases
