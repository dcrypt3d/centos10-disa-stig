#!/bin/bash
# Script to generate ssg-centos10-ds.xml from ssg-rhel10-ds.xml
# Since CentOS 10 Stream is based on RHEL 10, we use the RHEL 10 data stream

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SSG_CONTENT_DIR="/usr/share/xml/scap/ssg/content"
RHEL10_DS="${SSG_CONTENT_DIR}/ssg-rhel10-ds.xml"
OUTPUT_FILE="${PWD}/roles/rhel9STIG/files/ssg-centos10-ds.xml"

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

show_help() {
    cat << EOF
Usage: $0 [options] [source_file]

Generate ssg-centos10-ds.xml from ssg-rhel10-ds.xml

Options:
  --help, -h          Show this help message
  --adapt             Adapt XML content (replace rhel10 with centos10 in IDs)
  source_file         Path to ssg-rhel10-ds.xml (optional, defaults to system location)

Examples:
  $0                                    # Use system RHEL 10 data stream
  $0 /path/to/ssg-rhel10-ds.xml         # Use custom source file
  $0 --adapt                             # Adapt XML content for CentOS 10
EOF
}

ADAPT_MODE=false
SOURCE_FILE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            show_help
            exit 0
            ;;
        --adapt)
            ADAPT_MODE=true
            shift
            ;;
        -*)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
        *)
            SOURCE_FILE="$1"
            shift
            ;;
    esac
done

print_section "Generating ssg-centos10-ds.xml from RHEL 10 Data Stream"

# Determine source file
if [ -n "$SOURCE_FILE" ]; then
    RHEL10_DS="$SOURCE_FILE"
    print_info "Using provided source file: $RHEL10_DS"
elif [ ! -f "$RHEL10_DS" ]; then
    print_error "RHEL 10 data stream not found: $RHEL10_DS"
    print_info "Attempting to install scap-security-guide..."
    
    if [ "$EUID" -eq 0 ] || sudo -n true 2>/dev/null; then
        if command -v dnf &> /dev/null; then
            sudo dnf install -y scap-security-guide
        elif command -v yum &> /dev/null; then
            sudo yum install -y scap-security-guide
        else
            print_error "Cannot determine package manager"
            exit 1
        fi
    else
        print_error "scap-security-guide not installed and sudo access required"
        print_error "Please install manually: dnf install -y scap-security-guide"
        print_error "Or provide the source file: $0 /path/to/ssg-rhel10-ds.xml"
        exit 1
    fi
fi

if [ ! -f "$RHEL10_DS" ]; then
    print_error "RHEL 10 data stream not found: $RHEL10_DS"
    print_error "Please provide the source file or ensure scap-security-guide is installed"
    exit 1
fi

print_info "Found RHEL 10 data stream: $RHEL10_DS"

# Create output directory
mkdir -p "$(dirname "$OUTPUT_FILE")"

# If adapt mode, use Python script if available
if [ "$ADAPT_MODE" = true ] && command -v python3 &> /dev/null; then
    print_info "Using Python script to adapt XML content..."
    if [ -f "${PWD}/generate-centos10-ds.py" ]; then
        python3 "${PWD}/generate-centos10-ds.py" "$RHEL10_DS" --adapt
        exit $?
    else
        print_warning "Python script not found, using direct copy"
    fi
fi

# Method 1: Try to create a symlink (most efficient)
if ln -s "$RHEL10_DS" "$OUTPUT_FILE" 2>/dev/null; then
    print_info "Created symlink: $OUTPUT_FILE -> $RHEL10_DS"
    print_info "Success! CentOS 10 data stream is now available."
    print_warning "Note: This is a symlink to RHEL 10. For adapted content, use --adapt flag."
    exit 0
fi

# Method 2: Copy the file (if symlink fails, e.g., on Windows)
print_warning "Symlink not possible, copying file..."
if cp "$RHEL10_DS" "$OUTPUT_FILE"; then
    print_info "Created copy: $OUTPUT_FILE"
    print_info "Success! CentOS 10 data stream is now available."
    print_warning "Note: This is a direct copy of RHEL 10. For adapted content, use --adapt flag."
    exit 0
else
    print_error "Failed to copy file"
    exit 1
fi
