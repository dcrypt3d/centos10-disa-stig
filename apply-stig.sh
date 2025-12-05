#!/bin/bash
# Script to apply DISA STIGs to CentOS 10 Stream systems
# Usage: ./apply-stig.sh [options]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
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
check_ansible() {
    if ! command -v ansible-playbook &> /dev/null; then
        print_error "Ansible is not installed. Please install it first."
        exit 1
    fi
    print_info "Ansible found: $(ansible-playbook --version | head -n 1)"
}

# Check if role is present
check_roles() {
    if [ ! -d "roles/rhel9STIG" ]; then
        print_error "DISA STIG role not found in roles/rhel9STIG/"
        print_error "Please ensure the role directory exists"
        exit 1
    else
        print_info "DISA STIG role found"
    fi
}

# Main execution
main() {
    print_info "Starting DISA STIG application process..."
    
    check_ansible
    check_roles
    
    # Parse arguments
    DRY_RUN=false
    TAGS=""
    LIMIT=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --check|--dry-run)
                DRY_RUN=true
                shift
                ;;
            --tags)
                TAGS="$2"
                shift 2
                ;;
            --limit)
                LIMIT="$2"
                shift 2
                ;;
            --help|-h)
                echo "Usage: $0 [options]"
                echo "Options:"
                echo "  --check, --dry-run    Run in check mode (no changes)"
                echo "  --tags TAG            Apply specific tags"
                echo "  --limit HOST          Limit to specific host"
                echo "  --help, -h            Show this help"
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Build ansible-playbook command
    CMD="ansible-playbook playbook.yml --ask-become-pass"
    
    if [ "$DRY_RUN" = true ]; then
        CMD="$CMD --check"
        print_info "Running in check mode (dry-run)"
    fi
    
    if [ -n "$TAGS" ]; then
        CMD="$CMD --tags $TAGS"
        print_info "Applying tags: $TAGS"
    fi
    
    if [ -n "$LIMIT" ]; then
        CMD="$CMD --limit $LIMIT"
        print_info "Limiting to host: $LIMIT"
    fi
    
    print_warning "This will apply DISA STIG security controls to your CentOS 10 Stream systems."
    print_warning "Make sure you have backups and have tested in a non-production environment."
    read -p "Continue? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        print_info "Aborted by user"
        exit 0
    fi
    
    print_info "Executing: $CMD"
    eval $CMD
    
    print_info "STIG application completed!"
    print_warning "Please review the changes and reboot if necessary."
}

main "$@"

