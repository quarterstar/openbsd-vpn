#!/usr/bin/env python3

import sys
import time
import random
import requests
import sys
from parse import *

if len(sys.argv) != 5:
    print("Usage: python3 create.py <api_key> <plan> <label>")
    sys.exit(1)

API_KEY = sys.argv[1]
PLAN = sys.argv[2]
LABEL = sys.argv[3]
LOCATIONS = sys.argv[4]

if LOCATIONS != "":
    REGIONS = parse_comma_arg(LOCATIONS)
else:
    REGIONS = [ "ewr", "lax", "ord", "ams", "syd", "sgp" ]

selected_region = random.choice(REGIONS)
print(f"Selected region: {selected_region}")

INSTANCE_PARAMS = {
    "region": selected_region,
    "plan": PLAN,               
    "os_id": 2464, # OpenBSD 7.6
    "label": LABEL,
    "user_data": "",
}

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

def find_instance_by_label(label):
    instances = list_instances()
    for inst in instances:
        if inst.get("label") == label:
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

def get_instance_password(instance_id):
    url = f"{BASE_URL}/instances/{instance_id}"
    response = requests.get(url, headers=HEADERS)
    if response.status_code == 200:
        instance_details = response.json()["instance"]
        return instance_details.get("default_password")
    else:
        print(f"Error retrieving instance {instance_id} details: {response.status_code} {response.text}")
        return None

def create_instance(params):
    url = f"{BASE_URL}/instances"
    response = requests.post(url, json=params, headers=HEADERS)
    if response.status_code == 202:
        new_instance = response.json()["instance"]
        print(f"New instance created: {new_instance['id']}")
        return new_instance
    else:
        print(f"Error creating instance: {response.status_code} {response.text}")
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

def wait_for_initialization(instance_id, timeout=600, interval=15):
    start_time = time.time()
    while True:
        instance = get_instance(instance_id)
        if instance and instance.get("default_password"):
            print(f"Instance {instance_id} is fully initialized.")
            return instance
        elapsed = time.time() - start_time
        if elapsed > timeout:
            print(f"Timeout waiting for instance {instance_id} to initialize.")
            sys.exit(1)
        print(f"Waiting for instance {instance_id} to initialize...")
        time.sleep(interval)

def main():
    with open('instance.txt', 'w') as output:

        current_instance = find_instance_by_label(LABEL)
        if current_instance:
            current_id = current_instance["id"]
            current_ip = current_instance.get("main_ip", "N/A")

            output.write(f'OLD_ID={current_id}\n')

            print(f"Found current instance with label '{LABEL}': ID {current_id}, public IP: {current_ip}")
            
        new_instance = create_instance(INSTANCE_PARAMS)
        new_instance_id = new_instance["id"]
        
        # Wait for the new instance to become active.
        active_instance = wait_for_instance(new_instance_id)
        new_ip = active_instance.get("main_ip")
        if new_ip:
            print(f"New VPN server instance {new_instance_id} is active with public IP: {new_ip}")
        else:
            print(f"New instance {new_instance_id} is active but no public IP was found. Exiting.")
            return
    
        new_instance_password = new_instance.get('default_password')
        if new_instance_password:
            print(f"Obtained password successfully")
        else:
            print(f"Failed to retrieve password for instance {new_instance_id}. Exiting.")
            return

        output.write(f'IP={new_ip}\n')
        output.write(f'PASSWORD="{new_instance_password}"\n')

if __name__ == "__main__":
    main()
