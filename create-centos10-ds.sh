#!/bin/bash
# Script to create a working ssg-centos10-ds.xml from RHEL 10 data stream
# Since CentOS 10 Stream is based on RHEL 10, we adapt the RHEL 10 data stream

set -e

SSG_CONTENT_DIR="/usr/share/xml/scap/ssg/content"
RHEL10_DS="${SSG_CONTENT_DIR}/ssg-rhel10-ds.xml"
OUTPUT_FILE="${SSG_CONTENT_DIR}/ssg-centos10-ds.xml"
PROJECT_FILE="roles/rhel9STIG/files/ssg-centos10-ds.xml"

print_info() {
    echo -e "\033[0;32m[INFO]\033[0m $1"
}

print_warning() {
    echo -e "\033[1;33m[WARNING]\033[0m $1"
}

print_error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1"
}

# Check if RHEL 10 data stream exists
if [ ! -f "$RHEL10_DS" ]; then
    print_error "RHEL 10 data stream not found: $RHEL10_DS"
    print_info "Installing scap-security-guide..."
    if command -v dnf &> /dev/null; then
        sudo dnf install -y scap-security-guide
    elif command -v yum &> /dev/null; then
        sudo yum install -y scap-security-guide
    else
        print_error "Cannot install packages. Please install manually:"
        print_error "  dnf install -y scap-security-guide"
        exit 1
    fi
fi

if [ ! -f "$RHEL10_DS" ]; then
    print_error "RHEL 10 data stream still not found after installation"
    exit 1
fi

print_info "Found RHEL 10 data stream: $RHEL10_DS"
print_info "Creating CentOS 10 data stream..."

# Method 1: Create symlink (simplest and most reliable)
if [ -w "$SSG_CONTENT_DIR" ] || sudo -n true 2>/dev/null; then
    if [ -f "$OUTPUT_FILE" ]; then
        print_warning "File exists: $OUTPUT_FILE"
        if [ -w "$SSG_CONTENT_DIR" ]; then
            rm -f "$OUTPUT_FILE"
        else
            sudo rm -f "$OUTPUT_FILE"
        fi
    fi
    
    if [ -w "$SSG_CONTENT_DIR" ]; then
        ln -s "$(basename "$RHEL10_DS")" "$OUTPUT_FILE"
    else
        sudo ln -s "$(basename "$RHEL10_DS")" "$OUTPUT_FILE"
    fi
    
    print_info "Created symlink: $OUTPUT_FILE -> $(basename "$RHEL10_DS")"
    print_info "CentOS 10 data stream is now available at: $OUTPUT_FILE"
    
    # Also create in project directory
    mkdir -p "$(dirname "$PROJECT_FILE")"
    if [ -f "$PROJECT_FILE" ]; then
        rm -f "$PROJECT_FILE"
    fi
    ln -s "$RHEL10_DS" "$PROJECT_FILE" 2>/dev/null || cp "$RHEL10_DS" "$PROJECT_FILE"
    print_info "Also created reference in project: $PROJECT_FILE"
    
    exit 0
fi

# Method 2: Copy the file (if symlink not possible)
print_warning "Cannot create symlink (permissions). Copying file..."
if [ -w "$SSG_CONTENT_DIR" ]; then
    cp "$RHEL10_DS" "$OUTPUT_FILE"
else
    sudo cp "$RHEL10_DS" "$OUTPUT_FILE"
    sudo chmod 644 "$OUTPUT_FILE"
fi

print_info "Created copy: $OUTPUT_FILE"
print_info "CentOS 10 data stream is now available at: $OUTPUT_FILE"

# Also create in project directory
mkdir -p "$(dirname "$PROJECT_FILE")"
cp "$RHEL10_DS" "$PROJECT_FILE"
print_info "Also created reference in project: $PROJECT_FILE"

print_info ""
print_info "Success! CentOS 10 data stream created."
print_info "You can now use it with OpenSCAP:"
print_info "  oscap xccdf eval --profile stig --report report.html $OUTPUT_FILE"

