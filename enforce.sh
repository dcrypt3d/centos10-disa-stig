#!/bin/bash
# Script to enforce DISA STIGs on CentOS 10 Stream
# Based on the official DISA STIG Ansible implementation

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Ansible is installed
if ! command -v ansible-playbook &> /dev/null; then
    print_error "Ansible is not installed. Please install it first."
    exit 1
fi

print_info "Enforcing DISA STIG V2R6 compliance on CentOS 10 Stream systems..."
print_warning "This will make significant security changes to your systems!"
print_warning "Ensure you have backups and have tested in a non-production environment."

# Set XML report path (relative to current directory)
XML_REPORT_PATH="${PWD}/stig-compliance-report.xml"
export XML_PATH="${XML_REPORT_PATH}"

print_info "XML compliance report will be saved to: ${XML_REPORT_PATH}"

# Run the playbook
ansible-playbook -v -b -i inventory.yml playbook.yml --ask-become-pass

print_info "STIG enforcement completed!"
print_info "XML compliance report saved to: ${XML_REPORT_PATH}"
print_warning "Reboot may be required. Review changes before rebooting."

