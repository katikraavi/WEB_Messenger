#!/usr/bin/env python3
"""
Test script to verify message sync and real-time delivery fixes
"""
import requests
import json
import time
import sys
from datetime import datetime

BASE_URL = 'http://localhost:8081'

def log(msg):
    print(f"[{datetime.now().strftime('%H:%M:%S')}] {msg}")

def test_message_sync():
    """Test message synchronization"""
    log("🧪 Testing Message Sync Fix")
    log("=" * 60)
    
    # 1. Register two users
    log("\n📝 Step 1: Registering users...")
    users = {}
    
    for username, email in [("testuser1", "test1@example.com"), ("testuser2", "test2@example.com")]:
        try:
            response = requests.post(
                f'{BASE_URL}/api/auth/register',
                json={
                    'username': username,
                    'email': email,
                    'password': 'password123',
                },
                timeout=10
            )
            
            if response.status_code == 200:
                data = response.json()
                users[username] = {
                    'userId': data.get('userId'),
                    'token': data.get('token'),
                    'username': username,
                }
                log(f"✅ Registered {username}: {data.get('userId')}")
            else:
                log(f"⚠️  {username} registration: {response.status_code}")
                if response.status_code == 409:  # Already exists
                    # Try to login instead
                    response = requests.post(
                        f'{BASE_URL}/api/auth/login',
                        json={
                            'email': email,
                            'password': 'password123',
                        },
                        timeout=10
                    )
                    if response.status_code == 200:
                        data = response.json()
                        users[username] = {
                            'userId': data.get('userId'),
                            'token': data.get('token'),
                            'username': username,
                        }
                        log(f"✅ Logged in {username}")
        except Exception as e:
            log(f"❌ Error registering {username}: {e}")
            return False
    
    if len(users) != 2:
        log("❌ Failed to register/login both users")
        return False
    
    # 2. Create chat via invitation
    log("\n💬 Step 2: Creating chat via invitation...")
    user1 = users['testuser1']
    user2 = users['testuser2']
    
    try:
        # Send invitation from user1 to user2
        response = requests.post(
            f'{BASE_URL}/api/users/{user1["userId"]}/invites',
            json={
                'recipientId': user2['userId'],
            },
            headers={'Authorization': f'Bearer {user1["token"]}'},
            timeout=10
        )
        
        if response.status_code == 201:
            invite_data = response.json()
            chat_id = invite_data.get('chatId')
            log(f"✅ Invitation sent, Chat ID: {chat_id}")
        else:
            log(f"❌ Invitation failed: {response.status_code}")
            return False
            
        # Accept invitation from user2
        response = requests.post(
            f'{BASE_URL}/api/users/{user2["userId"]}/invites/{invite_data.get("id")}/accept',
            headers={'Authorization': f'Bearer {user2["token"]}'},
            timeout=10
        )
        
        if response.status_code == 200:
            log(f"✅ Invitation accepted")
        else:
            log(f"❌ Acceptance failed: {response.status_code}")
            return False
            
    except Exception as e:
        log(f"❌ Error with invitations: {e}")
        return False
    
    # 3. Send messages and check synchronization
    log("\n📤 Step 3: Sending messages and checking sync...")
    
    try:
        # Send message from user1
        message_text = f"Test message at {datetime.now().isoformat()}"
        response = requests.post(
            f'{BASE_URL}/api/chats/{chat_id}/messages',
            json={'content': message_text},
            headers={'Authorization': f'Bearer {user1["token"]}'},
            timeout=10
        )
        
        if response.status_code == 201:
            msg_data = response.json()
            message_id = msg_data.get('id')
            log(f"✅ Message sent: {message_id}")
        else:
            log(f"❌ Message send failed: {response.status_code}")
            return False
        
        # Wait a moment for sync
        log("⏳ Waiting for message sync...")
        time.sleep(1)
        
        # Fetch messages for user2 to verify sync
        response = requests.get(
            f'{BASE_URL}/api/chats/{chat_id}/messages?limit=10',
            headers={'Authorization': f'Bearer {user2["token"]}'},
            timeout=10
        )
        
        if response.status_code == 200:
            messages = response.json()
            if messages and any(m.get('id') == message_id for m in messages):
                log(f"✅ Message synchronized to other user - count: {len(messages)}")
            else:
                log(f"⚠️  Message not found in recipient's list - {len(messages)} messages fetched")
                log(f"   Message IDs received: {[m.get('id') for m in messages[:3]]}")
                log(f"   Expected: {message_id}")
        else:
            log(f"❌ Failed to fetch messages: {response.status_code}")
            return False
            
    except Exception as e:
        log(f"❌ Error sending/receiving messages: {e}")
        return False
    
    # 4. Send multiple messages to test real-time delivery
    log("\n📬 Step 4: Testing multiple message delivery...")
    
    try:
        message_ids = []
        for i in range(3):
            message_text = f"Message #{i+1} at {datetime.now().isoformat()}"
            response = requests.post(
                f'{BASE_URL}/api/chats/{chat_id}/messages',
                json={'content': message_text},
                headers={'Authorization': f'Bearer {user1["token"]}'},
                timeout=10
            )
            
            if response.status_code == 201:
                msg_id = response.json().get('id')
                message_ids.append(msg_id)
                log(f"   ✅ Sent message #{i+1}: {msg_id}")
                time.sleep(0.5)
            else:
                log(f"   ❌ Failed to send message #{i+1}")
        
        # Wait for sync
        time.sleep(2)
        
        # Check all messages received
        response = requests.get(
            f'{BASE_URL}/api/chats/{chat_id}/messages?limit=50',
            headers={'Authorization': f'Bearer {user2["token"]}'},
            timeout=10
        )
        
        if response.status_code == 200:
            messages = response.json()
            received_ids = [m.get('id') for m in messages]
            found_count = sum(1 for mid in message_ids if mid in received_ids)
            
            log(f"\n📊 Summary:")
            log(f"   - Sent: {len(message_ids)} messages")
            log(f"   - Received by other user: {found_count} messages")
            log(f"   - Total messages in chat: {len(messages)}")
            
            if found_count == len(message_ids):
                log(f"\n✅ All messages synchronized successfully!")
                return True
            else:
                log(f"\n⚠️  Some messages are missing ({len(message_ids) - found_count} missing)")
                return False
        else:
            log(f"❌ Failed to fetch messages: {response.status_code}")
            return False
            
    except Exception as e:
        log(f"❌ Error with multiple messages: {e}")
        return False

if __name__ == '__main__':
    try:
        success = test_message_sync()
        sys.exit(0 if success else 1)
    except Exception as e:
        log(f"❌ Test failed with exception: {e}")
        sys.exit(1)
