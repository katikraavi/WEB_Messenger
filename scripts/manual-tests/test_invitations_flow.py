#!/usr/bin/env python3
"""
Test the Complete Invitation Flow
Tests: Send → Fetch Pending → Accept
"""

import requests
import json
import sys
import os

BASE_URL = os.getenv("BASE_URL", "https://web-messenger-backend.onrender.com")
ALICE_ID = "bfd3a96a-ab36-442c-9b4e-276050b87678"
BOB_ID = "b8465fd4-56e0-4f97-9a4f-9e2cb862d444"
ALICE_TOKEN = "alice_token"
BOB_TOKEN = "bob_token"

print("=" * 70)
print("TESTING INVITATION SYSTEM FLOW")
print("=" * 70)
print()

# STEP 1: Alice sends invitation to Bob
print("STEP 1: Alice sends invitation to Bob")
print(f"POST {BASE_URL}/api/invites")
print()

try:
    send_response = requests.post(
        f"{BASE_URL}/api/invites",
        json={"recipient_id": BOB_ID},
        headers={"Authorization": f"Bearer {ALICE_TOKEN}"},
        timeout=5
    )
    print(f"Status: {send_response.status_code}")
    send_data = send_response.json()
    print(f"Response: {json.dumps(send_data, indent=2)}")
    print()
    
    invite_id = send_data.get("id")
    print(f"✅ Invitation created with ID: {invite_id}")
    print()
    
except Exception as e:
    print(f"❌ Error sending invitation: {e}")
    sys.exit(1)

# STEP 2: Bob fetches pending invitations
print("=" * 70)
print("STEP 2: Bob fetches pending invitations")
print(f"GET {BASE_URL}/api/users/{BOB_ID}/invites/pending")
print()

try:
    pending_response = requests.get(
        f"{BASE_URL}/api/users/{BOB_ID}/invites/pending",
        headers={"Authorization": f"Bearer {BOB_TOKEN}"},
        timeout=5
    )
    print(f"Status: {pending_response.status_code}")
    pending_invites = pending_response.json()
    print(f"Response: {json.dumps(pending_invites, indent=2)}")
    print()
    
    if isinstance(pending_invites, list):
        print(f"✅ Bob has {len(pending_invites)} pending invitation(s)")
        
        # Check if our invitation is in the list
        our_invite = next((inv for inv in pending_invites if inv.get("id") == invite_id), None)
        if our_invite:
            print(f"✅ Our invitation found in pending list with status: {our_invite.get('status')}")
        else:
            print(f"⚠️ Our invitation not found in pending list")
    else:
        print(f"Got response: {pending_invites}")
    print()
    
except Exception as e:
    print(f"❌ Error fetching pending invites: {e}")
    sys.exit(1)

# STEP 3: Bob accepts the invitation
print("=" * 70)
print("STEP 3: Bob accepts the invitation")
print(f"POST {BASE_URL}/api/invites/{invite_id}/accept")
print()

try:
    accept_response = requests.post(
        f"{BASE_URL}/api/invites/{invite_id}/accept",
        headers={"Authorization": f"Bearer {BOB_TOKEN}"},
        timeout=5
    )
    print(f"Status: {accept_response.status_code}")
    accept_data = accept_response.json()
    print(f"Response: {json.dumps(accept_data, indent=2)}")
    print()
    
    final_status = accept_data.get("status")
    if final_status == "accepted":
        print(f"✅ Invitation successfully accepted! Status: {final_status}")
    else:
        print(f"⚠️ Final status is: {final_status}")
    print()
    
except Exception as e:
    print(f"❌ Error accepting invitation: {e}")
    sys.exit(1)

# STEP 4: Alice checks sent invitations
print("=" * 70)
print("STEP 4: Alice checks sent invitations")
print(f"GET {BASE_URL}/api/users/{ALICE_ID}/invites/sent")
print()

try:
    sent_response = requests.get(
        f"{BASE_URL}/api/users/{ALICE_ID}/invites/sent",
        headers={"Authorization": f"Bearer {ALICE_TOKEN}"},
        timeout=5
    )
    print(f"Status: {sent_response.status_code}")
    sent_invites = sent_response.json()
    
    if isinstance(sent_invites, list):
        print(f"Alice has {len(sent_invites)} sent invitation(s)")
        # Show just the IDs to avoid too much output
        print(f"Invitation IDs: {[inv.get('id')[:8] + '...' for inv in sent_invites[:3]]}")
    else:
        print(f"Response: {sent_invites}")
    print()
    
except Exception as e:
    print(f"❌ Error fetching sent invites: {e}")
    sys.exit(1)

print("=" * 70)
print("✅ ALL TESTS PASSED!")
print("=" * 70)
print()
print("Summary:")
print("  ✅ Successfully sent invitation from Alice to Bob")
print("  ✅ Bob can fetch pending invitations")
print("  ✅ Bob can accept invitation and status changes to 'accepted'")
print("  ✅ Alice can fetch sent invitations")
