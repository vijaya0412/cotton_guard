"""
Cotton Guard - Administrator Account Provisioning Tool.
Provisions or promotes the designated administrator in the SQLite database.
Usage:
    python -m backend.provision_admin --email admin@example.com --password YourSecurePassword
    python -m backend.provision_admin  (interactive prompt)
"""

import sys
import os
import argparse
import getpass

# Add workspace to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from backend.database import init_database, provision_initial_admin, get_user_by_email

def main():
    parser = argparse.ArgumentParser(description="Provision first administrator account for Cotton Guard.")
    parser.add_argument("--email", help="Administrator email address")
    parser.add_argument("--password", help="Administrator password (min 8 chars)")
    parser.add_argument("--name", default="System Administrator", help="Administrator display name")

    args = parser.parse_args()

    init_database()

    email = args.email or os.environ.get("ADMIN_EMAIL")
    if not email:
        email = input("Enter Administrator Email: ").strip()

    if not email or "@" not in email:
        print("[Error] A valid email address is required.", file=sys.stderr)
        sys.exit(1)

    existing = get_user_by_email(email)
    password = args.password or os.environ.get("ADMIN_INITIAL_PASSWORD")

    if not existing and not password:
        password = getpass.getpass("Enter Administrator Password (min 8 chars): ")
        confirm = getpass.getpass("Confirm Administrator Password: ")
        if password != confirm:
            print("[Error] Passwords do not match.", file=sys.stderr)
            sys.exit(1)

    if not existing and len(password) < 8:
        print("[Error] Password must be at least 8 characters.", file=sys.stderr)
        sys.exit(1)

    user = provision_initial_admin(
        admin_email=email,
        admin_password=password,
        full_name=args.name
    )

    if user:
        print(f"[Success] Administrator provisioned successfully.")
        print(f"  User ID : {user['id']}")
        print(f"  Email   : {user['email']}")
        print(f"  Role    : {user['role']}")
        sys.exit(0)
    else:
        print("[Error] Failed to provision administrator.", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
