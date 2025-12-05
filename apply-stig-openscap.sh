#!/bin/bash
# Script to apply DISA STIGs using OpenSCAP on CentOS 10 Stream
# Usage: ./apply-stig-openscap.sh [--remediate]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

REMEDIATE=false
REPORT_FILE="stig-report-$(date +%Y%m%d-%H%M%S).html"

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_section() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    print_error "Please run as root or with sudo"
    exit 1
fi

# Check if OpenSCAP is installed
if ! command -v oscap &> /dev/null; then
    print_info "Installing OpenSCAP..."
    dnf install -y openscap-scanner scap-security-guide
fi

# Find STIG data stream (try RHEL 10 first, fallback to RHEL 9)
STIG_DS="/usr/share/xml/scap/ssg/content/ssg-rhel10-ds.xml"

if [ ! -f "$STIG_DS" ]; then
    print_warning "RHEL 10 STIG data stream not found, trying RHEL 9..."
    STIG_DS="/usr/share/xml/scap/ssg/content/ssg-rhel9-ds.xml"
fi

if [ ! -f "$STIG_DS" ]; then
    print_error "STIG data stream not found at $STIG_DS"
    print_info "Installing scap-security-guide..."
    dnf install -y scap-security-guide
    # Try again after installation
    if [ -f "/usr/share/xml/scap/ssg/content/ssg-rhel10-ds.xml" ]; then
        STIG_DS="/usr/share/xml/scap/ssg/content/ssg-rhel10-ds.xml"
    elif [ -f "/usr/share/xml/scap/ssg/content/ssg-rhel9-ds.xml" ]; then
        STIG_DS="/usr/share/xml/scap/ssg/content/ssg-rhel9-ds.xml"
    fi
fi

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --remediate)
            REMEDIATE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--remediate]"
            echo "Options:"
            echo "  --remediate    Automatically remediate non-compliant items"
            echo "  --help, -h     Show this help"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Final check that STIG data stream exists
if [ ! -f "$STIG_DS" ]; then
    print_error "STIG data stream file not found: $STIG_DS"
    print_error "Please install scap-security-guide package: dnf install -y scap-security-guide"
    exit 1
fi

print_section "DISA STIG Compliance Check"
print_info "Using STIG profile: stig"
print_info "Using STIG data stream: $STIG_DS"
print_info "Report will be saved to: $REPORT_FILE"

if [ "$REMEDIATE" = true ]; then
    print_warning "Running in REMEDIATION mode - this will make changes to your system!"
    read -p "Continue? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        print_info "Aborted by user"
        exit 0
    fi
    
    print_info "Evaluating and remediating STIG compliance..."
    oscap xccdf eval \
        --profile stig \
        --remediate \
        --report "$REPORT_FILE" \
        "$STIG_DS"
else
    print_info "Running compliance check (no changes will be made)..."
    oscap xccdf eval \
        --profile stig \
        --report "$REPORT_FILE" \
        "$STIG_DS"
fi

print_info "Compliance check completed!"
print_info "Report saved to: $REPORT_FILE"
print_warning "If remediation was performed, please review changes and reboot if necessary."

