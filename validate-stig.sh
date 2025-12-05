#!/bin/bash
# Script to validate DISA STIG compliance on CentOS 10 Stream systems
# Usage: ./validate-stig.sh [host]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

HOST="${1:-all}"

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_section() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

# Check if Ansible is installed
if ! command -v ansible-playbook &> /dev/null; then
    echo -e "${RED}[ERROR]${NC} Ansible is not installed"
    exit 1
fi

print_section "DISA STIG Compliance Validation"
print_info "Validating STIG compliance for: $HOST"

# Run playbook in check mode
ansible-playbook playbook.yml \
    --limit "$HOST" \
    --check \
    --ask-become-pass \
    --tags "stig,compliance"

print_info "Validation completed. Review the output above for compliance status."

