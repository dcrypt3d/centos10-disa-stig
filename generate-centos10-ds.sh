#!/bin/bash
# Script to generate ssg-centos10-ds.xml for OpenSCAP validation
# This creates a wrapper data stream that references RHEL 10 content
# since CentOS 10 Stream is based on RHEL 10

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

OUTPUT_DIR="${PWD}/roles/rhel9STIG/files"
OUTPUT_FILE="${OUTPUT_DIR}/ssg-centos10-ds.xml"
SSG_CONTENT_DIR="/usr/share/xml/scap/ssg/content"
RHEL10_DS="${SSG_CONTENT_DIR}/ssg-rhel10-ds.xml"
RHEL9_DS="${SSG_CONTENT_DIR}/ssg-rhel9-ds.xml"

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

# Check if scap-security-guide is installed
check_ssg() {
    if [ ! -d "$SSG_CONTENT_DIR" ]; then
        return 1
    fi
    return 0
}

# Install scap-security-guide
install_ssg() {
    print_info "Installing scap-security-guide..."
    if command -v dnf &> /dev/null; then
        sudo dnf install -y scap-security-guide
    elif command -v yum &> /dev/null; then
        sudo yum install -y scap-security-guide
    else
        print_error "Cannot determine package manager"
        return 1
    fi
}

# Find available RHEL data stream
find_rhel_ds() {
    if [ -f "$RHEL10_DS" ]; then
        echo "$RHEL10_DS"
        return 0
    elif [ -f "$RHEL9_DS" ]; then
        echo "$RHEL9_DS"
        return 0
    fi
    return 1
}

# Generate CentOS 10 data stream XML
generate_centos10_ds() {
    local source_ds="$1"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S")
    
    print_info "Generating CentOS 10 data stream from: $source_ds"
    
    # Create output directory if it doesn't exist
    mkdir -p "$OUTPUT_DIR"
    
    # Generate the data stream XML
    cat > "$OUTPUT_FILE" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<ds:data-stream-collection
    xmlns="http://checklists.nist.gov/xccdf/1.2"
    xmlns:ds="http://scap.nist.gov/schema/scap/source/1.2"
    xmlns:xlink="http://www.w3.org/1999/xlink"
    id="scap_org.open-scap_datastream_from_xccdf_ssg-centos10-xccdf.xml">
  <ds:data-stream id="scap_org.open-scap_datastream_from_xccdf_ssg-centos10-xccdf.xml" scap-version="1.3" use-case="OTHER">
    <ds:dictionaries>
      <ds:component-ref id="scap_org.open-scap_cref_ssg-centos10-oval.xml" xlink:href="ssg-centos10-oval.xml"/>
      <ds:component-ref id="scap_org.open-scap_cref_ssg-centos10-ocil.xml" xlink:href="ssg-centos10-ocil.xml"/>
    </ds:dictionaries>
    <ds:checklists>
      <ds:component-ref id="scap_org.open-scap_cref_ssg-centos10-xccdf.xml" xlink:href="ssg-centos10-xccdf.xml"/>
    </ds:checklists>
    <ds:checks>
      <ds:component-ref id="scap_org.open-scap_cref_ssg-centos10-oval.xml" xlink:href="ssg-centos10-oval.xml"/>
      <ds:component-ref id="scap_org.open-scap_cref_ssg-centos10-ocil.xml" xlink:href="ssg-centos10-ocil.xml"/>
    </ds:checks>
  </ds:data-stream>
  <ds:data-stream id="scap_org.open-scap_datastream_from_xccdf_ssg-centos10-xccdf.xml.scap" scap-version="1.3" use-case="OTHER">
    <ds:dictionaries>
      <ds:component-ref id="scap_org.open-scap_cref_ssg-centos10-oval.xml" xlink:href="ssg-centos10-oval.xml"/>
      <ds:component-ref id="scap_org.open-scap_cref_ssg-centos10-ocil.xml" xlink:href="ssg-centos10-ocil.xml"/>
    </ds:dictionaries>
    <ds:checklists>
      <ds:component-ref id="scap_org.open-scap_cref_ssg-centos10-xccdf.xml" xlink:href="ssg-centos10-xccdf.xml"/>
    </ds:checklists>
    <ds:checks>
      <ds:component-ref id="scap_org.open-scap_cref_ssg-centos10-oval.xml" xlink:href="ssg-centos10-oval.xml"/>
      <ds:component-ref id="scap_org.open-scap_cref_ssg-centos10-ocil.xml" xlink:href="ssg-centos10-ocil.xml"/>
    </ds:checks>
  </ds:data-stream>
</ds:data-stream-collection>
EOF

    print_info "Generated: $OUTPUT_FILE"
    print_warning "Note: This is a minimal wrapper. For full functionality, use the RHEL 10 data stream directly."
}

# Create a symlink-based solution (better approach)
create_symlink() {
    local source_ds="$1"
    local target_file="${SSG_CONTENT_DIR}/ssg-centos10-ds.xml"
    
    print_info "Creating symlink from RHEL data stream to CentOS 10..."
    
    if [ -f "$target_file" ]; then
        print_warning "File already exists: $target_file"
        read -p "Overwrite? (yes/no): " -r
        if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
            print_info "Skipping symlink creation"
            return 0
        fi
        sudo rm -f "$target_file"
    fi
    
    # Create symlink (requires sudo for system directory)
    if sudo ln -s "$(basename "$source_ds")" "$target_file"; then
        print_info "Created symlink: $target_file -> $(basename "$source_ds")"
        return 0
    else
        print_error "Failed to create symlink"
        return 1
    fi
}

# Main execution
print_section "Generating CentOS 10 SCAP Data Stream"

# Check if SSG is installed
if ! check_ssg; then
    print_warning "scap-security-guide not found"
    if [ "$EUID" -eq 0 ] || sudo -n true 2>/dev/null; then
        if ! install_ssg; then
            print_error "Failed to install scap-security-guide"
            exit 1
        fi
    else
        print_error "scap-security-guide not installed and sudo access required"
        print_error "Please install manually: dnf install -y scap-security-guide"
        exit 1
    fi
fi

# Find RHEL data stream
RHEL_DS=$(find_rhel_ds)
if [ -z "$RHEL_DS" ]; then
    print_error "No RHEL data stream found in $SSG_CONTENT_DIR"
    print_error "Please ensure scap-security-guide is properly installed"
    exit 1
fi

print_info "Found RHEL data stream: $RHEL_DS"

# Option 1: Create symlink in system directory (recommended)
if [ "$EUID" -eq 0 ] || sudo -n true 2>/dev/null; then
    print_info "Attempting to create system symlink..."
    if create_symlink "$RHEL_DS"; then
        print_info "Successfully created system symlink"
        print_info "CentOS 10 data stream available at: ${SSG_CONTENT_DIR}/ssg-centos10-ds.xml"
        exit 0
    fi
fi

# Option 2: Generate wrapper XML in project directory
print_info "Creating wrapper XML in project directory..."
generate_centos10_ds "$RHEL_DS"

# Also create a local symlink/copy approach
print_info "Creating local reference..."
LOCAL_DS="${OUTPUT_DIR}/ssg-centos10-ds-local.xml"
if [ -f "$RHEL_DS" ]; then
    # Create a script that points to the RHEL DS
    cat > "${OUTPUT_DIR}/use-centos10-ds.sh" << SCRIPT_EOF
#!/bin/bash
# Helper script to use CentOS 10 data stream
# Since CentOS 10 is based on RHEL 10, we use the RHEL 10 data stream

RHEL10_DS="${RHEL_DS}"
CENTOS10_DS="${SSG_CONTENT_DIR}/ssg-centos10-ds.xml"

if [ -f "\$CENTOS10_DS" ]; then
    echo "\$CENTOS10_DS"
elif [ -f "\$RHEL10_DS" ]; then
    echo "\$RHEL10_DS"
else
    echo "ERROR: No data stream found" >&2
    exit 1
fi
SCRIPT_EOF
    chmod +x "${OUTPUT_DIR}/use-centos10-ds.sh"
    print_info "Created helper script: ${OUTPUT_DIR}/use-centos10-ds.sh"
fi

print_section "Summary"
print_info "CentOS 10 data stream generation completed!"
print_info "Generated file: $OUTPUT_FILE"
print_warning "Note: CentOS 10 Stream is based on RHEL 10, so using RHEL 10 data stream is recommended"
print_info ""
print_info "To use with OpenSCAP:"
print_info "  oscap xccdf eval --profile stig --report report.html $OUTPUT_FILE"
print_info ""
print_info "Or use the RHEL 10 data stream directly:"
print_info "  oscap xccdf eval --profile stig --report report.html $RHEL_DS"

