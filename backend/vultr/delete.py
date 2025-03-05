#!/usr/bin/env python3

import sys
import time
import requests
import sys

if len(sys.argv) != 2:
    print("Usage: python3 delete.py <api_key> <id>")
    sys.exit(1)

API_KEY = sys.argv[1]
OLD_ID = sys.argv[2]

BASE_URL = "https://api.vultr.com/v2"
HEADERS = {
    "Authorization": f"Bearer {API_KEY}",
    "Content-Type": "application/json",
}

def list_instances():
    url = f"{BASE_URL}/instances"
    response = requests.get(url, headers=HEADERS)
    if response.status_code == 200:
        return response.json()["instances"]
    else:
        print(f"Error listing instances: {response.status_code} {response.text}")
        sys.exit(1)

def find_instance_by_id(id):
    instances = list_instances()
    for inst in instances:
        if inst.get("id") == id:
            return inst
    return None

def get_instance(instance_id):
    url = f"{BASE_URL}/instances/{instance_id}"
    response = requests.get(url, headers=HEADERS)
    if response.status_code == 200:
        return response.json()["instance"]
    else:
        print(f"Error retrieving instance {instance_id}: {response.status_code} {response.text}")
        return None

def delete_instance(instance_id):
    url = f"{BASE_URL}/instances/{instance_id}"
    response = requests.delete(url, headers=HEADERS)
    if response.status_code == 204:
        print(f"Instance {instance_id} deleted successfully.")
    else:
        print(f"Error deleting instance {instance_id}: {response.status_code} {response.text}")
        sys.exit(1)

def wait_for_instance(instance_id, timeout=600, interval=15):
    start_time = time.time()
    while True:
        instance = get_instance(instance_id)
        if instance and instance["status"] == "active":
            print(f"Instance {instance_id} is active.")
            return instance
        elapsed = time.time() - start_time
        if elapsed > timeout:
            print(f"Timeout waiting for instance {instance_id} to become active.")
            sys.exit(1)
        current_status = instance["status"] if instance else "unknown"
        print(f"Waiting for instance {instance_id} to be active... (current status: {current_status})")
        time.sleep(interval)

def main():
    current_instance = find_instance_by_id(OLD_ID)
    if not current_instance:
        print('Instance requested for deletion not found. Exiting.')
        return

    print(f'Instance with id "{OLD_ID}" found. Deleting...')
    
    current_instance_id = current_instance["id"]
    
    delete_instance(current_instance_id)

if __name__ == "__main__":
    main()
