#!/bin/bash
# Script to validate CentOS 10 Stream host using OpenSCAP and generate compliance reports
# Usage: ./validate-openscap.sh [host] [--remote]
#
# Options:
#   host        - Target hostname or IP (optional, defaults to localhost)
#   --remote    - Run validation remotely via SSH (requires host parameter)
#   --html      - Generate HTML report only (default: both HTML and XML)
#   --xml       - Generate XML report only
#   --profile   - STIG profile to use (default: stig)
#   --help      - Show this help message

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
TARGET_HOST=""
REMOTE_MODE=false
REPORT_FORMAT="both"  # both, html, xml
STIG_PROFILE="stig"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
REPORT_DIR="${PWD}/oscap-reports"
HTML_REPORT="${REPORT_DIR}/stig-compliance-${TIMESTAMP}.html"
XML_REPORT="${REPORT_DIR}/stig-compliance-${TIMESTAMP}.xml"

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
Usage: $0 [host] [options]

Validate CentOS 10 Stream host using OpenSCAP and generate compliance reports.

Arguments:
  host              Target hostname or IP address (optional, defaults to localhost)

Options:
  --remote         Run validation remotely via SSH (requires host parameter)
  --html           Generate HTML report only
  --xml            Generate XML report only
  --profile PROFILE STIG profile to use (default: stig)
  --help, -h       Show this help message

Examples:
  $0                                    # Validate localhost
  $0 192.168.1.100                      # Validate remote host via SSH
  $0 192.168.1.100 --remote             # Explicitly use remote mode
  $0 --html                              # Generate HTML report only
  $0 --profile stig_gui                  # Use stig_gui profile

Reports will be saved to: ${REPORT_DIR}/
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --remote)
            REMOTE_MODE=true
            shift
            ;;
        --html)
            REPORT_FORMAT="html"
            shift
            ;;
        --xml)
            REPORT_FORMAT="xml"
            shift
            ;;
        --profile)
            STIG_PROFILE="$2"
            shift 2
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        -*)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
        *)
            if [ -z "$TARGET_HOST" ]; then
                TARGET_HOST="$1"
            else
                print_error "Unexpected argument: $1"
                show_help
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate remote mode requirements
if [ "$REMOTE_MODE" = true ] && [ -z "$TARGET_HOST" ]; then
    print_error "Remote mode requires a host parameter"
    show_help
    exit 1
fi

# Create report directory
mkdir -p "$REPORT_DIR"

print_section "OpenSCAP STIG Compliance Validation"
print_info "Target: ${TARGET_HOST:-localhost}"
print_info "Mode: ${REMOTE_MODE:-false}"
print_info "Profile: $STIG_PROFILE"
print_info "Report format: $REPORT_FORMAT"
print_info "Report directory: $REPORT_DIR"

# Function to adapt RHEL 10 data stream to CentOS 10
adapt_rhel10_to_centos10() {
    local rhel10_ds="$1"
    local centos10_ds="$2"
    
    print_info "Adapting RHEL 10 data stream to CentOS 10..."
    
    # Check if Python is available for XML processing
    if command -v python3 &> /dev/null; then
        # Use Python for more reliable XML processing
        python3 << PYTHON_EOF
import sys
import xml.etree.ElementTree as ET
import re

try:
    # Parse the RHEL 10 data stream
    tree = ET.parse("$rhel10_ds")
    root = tree.getroot()
    
    # Define namespaces
    namespaces = {
        'ds': 'http://scap.nist.gov/schema/scap/source/1.2',
        'xccdf': 'http://checklists.nist.gov/xccdf/1.2',
        'xlink': 'http://www.w3.org/1999/xlink'
    }
    
    # Function to replace rhel10 with centos10 in text
    def replace_rhel10(text):
        if text is None:
            return text
        return text.replace('rhel10', 'centos10').replace('RHEL 10', 'CentOS 10').replace('Red Hat Enterprise Linux 10', 'CentOS Stream 10')
    
    # Update root element attributes
    for attr in root.attrib:
        root.attrib[attr] = replace_rhel10(root.attrib[attr])
    
    # Update all elements recursively
    for elem in root.iter():
        # Update attributes
        for attr in elem.attrib:
            elem.attrib[attr] = replace_rhel10(elem.attrib[attr])
        
        # Update text content
        if elem.text:
            elem.text = replace_rhel10(elem.text)
        
        # Update tail content
        if elem.tail:
            elem.tail = replace_rhel10(elem.tail)
    
    # Write the adapted XML
    import os
    os.makedirs(os.path.dirname("$centos10_ds"), exist_ok=True)
    tree.write("$centos10_ds", encoding='utf-8', xml_declaration=True)
    print("Successfully adapted data stream")
    sys.exit(0)
    
except Exception as e:
    print(f"Error adapting XML: {e}", file=sys.stderr)
    sys.exit(1)
PYTHON_EOF
        
        if [ $? -eq 0 ] && [ -f "$centos10_ds" ]; then
            print_info "Successfully created: $centos10_ds"
            return 0
        fi
    fi
    
    # Fallback: Use sed for simple replacements (less reliable but works without Python)
    print_warning "Python not available, using sed for adaptation..."
    mkdir -p "$(dirname "$centos10_ds")"
    
    if sed 's/rhel10/centos10/g; s/RHEL 10/CentOS 10/g; s/Red Hat Enterprise Linux 10/CentOS Stream 10/g' "$rhel10_ds" > "$centos10_ds" 2>/dev/null; then
        print_info "Created adapted data stream: $centos10_ds"
        return 0
    else
        print_error "Failed to adapt data stream"
        return 1
    fi
}

# Function to find or create STIG data stream
find_stig_ds() {
    local ssg_dir="/usr/share/xml/scap/ssg/content"
    local project_ds="${PWD}/roles/rhel9STIG/files/ssg-centos10-ds.xml"
    
    # First, check for existing CentOS 10 data stream
    local centos10_paths=(
        "${ssg_dir}/ssg-centos10-ds.xml"
        "$project_ds"
    )
    
    for path in "${centos10_paths[@]}"; do
        if [ -f "$path" ]; then
            echo "$path"
            return 0
        fi
    done
    
    # If CentOS 10 not found, try to create it from RHEL 10
    local rhel10_ds="${ssg_dir}/ssg-rhel10-ds.xml"
    
    if [ -f "$rhel10_ds" ]; then
        print_info "CentOS 10 data stream not found, adapting from RHEL 10..."
        
        # Try to create in project directory first
        if adapt_rhel10_to_centos10 "$rhel10_ds" "$project_ds"; then
            echo "$project_ds"
            return 0
        fi
        
        # If project directory fails, try system directory (requires permissions)
        if [ -w "$ssg_dir" ] || sudo -n true 2>/dev/null; then
            local system_centos10="${ssg_dir}/ssg-centos10-ds.xml"
            if adapt_rhel10_to_centos10 "$rhel10_ds" "$system_centos10"; then
                echo "$system_centos10"
                return 0
            fi
        fi
        
        # If adaptation failed, show error
        print_error "Failed to create CentOS 10 data stream from RHEL 10"
        print_error "Please ensure RHEL 10 data stream is available and adaptation is possible"
        return 1
    else
        print_error "RHEL 10 data stream not found: $rhel10_ds"
        print_error "Cannot create CentOS 10 data stream without RHEL 10 source"
        print_error "Please install: dnf install -y scap-security-guide"
        return 1
    fi
}

# Function to check if OpenSCAP is installed
check_openscap() {
    if ! command -v oscap &> /dev/null; then
        return 1
    fi
    return 0
}

# Function to install OpenSCAP
install_openscap() {
    print_info "Installing OpenSCAP and SCAP Security Guide..."
    if command -v dnf &> /dev/null; then
        dnf install -y openscap-scanner scap-security-guide
    elif command -v yum &> /dev/null; then
        yum install -y openscap-scanner scap-security-guide
    else
        print_error "Cannot determine package manager (dnf/yum not found)"
        return 1
    fi
}

# Function to run local validation
run_local_validation() {
    local stig_ds="$1"
    
    print_section "Running Local OpenSCAP Validation"
    
    # Check if OpenSCAP is installed
    if ! check_openscap; then
        print_warning "OpenSCAP not found. Attempting to install..."
        if ! install_openscap; then
            print_error "Failed to install OpenSCAP. Please install manually:"
            print_error "  dnf install -y openscap-scanner scap-security-guide"
            exit 1
        fi
    fi
    
    # Find STIG data stream
    if [ -z "$stig_ds" ]; then
        stig_ds=$(find_stig_ds)
    fi
    
    if [ -z "$stig_ds" ] || [ ! -f "$stig_ds" ]; then
        print_error "STIG data stream not found. Installing scap-security-guide..."
        if ! install_openscap; then
            print_error "Failed to install required packages"
            exit 1
        fi
        stig_ds=$(find_stig_ds)
    fi
    
    if [ -z "$stig_ds" ] || [ ! -f "$stig_ds" ]; then
        print_error "STIG data stream file not found: $stig_ds"
        print_error "Please install: dnf install -y scap-security-guide"
        exit 1
    fi
    
    print_info "Using STIG data stream: $stig_ds"
    
    # Build oscap command
    local oscap_cmd="oscap xccdf eval --profile $STIG_PROFILE"
    
    # Add report options based on format
    if [ "$REPORT_FORMAT" = "html" ] || [ "$REPORT_FORMAT" = "both" ]; then
        oscap_cmd="$oscap_cmd --report $HTML_REPORT"
        print_info "HTML report will be saved to: $HTML_REPORT"
    fi
    
    if [ "$REPORT_FORMAT" = "xml" ] || [ "$REPORT_FORMAT" = "both" ]; then
        oscap_cmd="$oscap_cmd --results $XML_REPORT"
        print_info "XML report will be saved to: $XML_REPORT"
    fi
    
    oscap_cmd="$oscap_cmd \"$stig_ds\""
    
    print_info "Running OpenSCAP evaluation..."
    print_info "Command: $oscap_cmd"
    
    # Run the evaluation
    if eval "$oscap_cmd"; then
        print_info "Validation completed successfully!"
    else
        print_error "Validation completed with errors (exit code: $?)"
        print_warning "Check the reports for details"
    fi
}

# Function to run remote validation via SSH
run_remote_validation() {
    local host="$1"
    
    print_section "Running Remote OpenSCAP Validation via SSH"
    print_info "Connecting to: $host"
    
    # Check SSH connectivity
    if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "$host" "echo 'Connection test'" &> /dev/null; then
        print_error "Cannot connect to $host via SSH"
        print_error "Please ensure:"
        print_error "  1. SSH key-based authentication is configured"
        print_error "  2. Host is reachable"
        print_error "  3. User has sudo privileges on remote host"
        exit 1
    fi
    
    # Create remote script
    local remote_script="/tmp/oscap-validate-$$.sh"
    
    # Generate remote script content
    ssh "$host" "cat > $remote_script << 'REMOTE_SCRIPT_EOF'
#!/bin/bash
set -e

    # Function to adapt RHEL 10 data stream to CentOS 10
adapt_rhel10_to_centos10() {
    local rhel10_ds=\"\$1\"
    local centos10_ds=\"\$2\"
    
    echo \"Adapting RHEL 10 data stream to CentOS 10...\"
    
    # Use sed for adaptation (works reliably in remote scripts)
    mkdir -p \"\$(dirname \"\$centos10_ds\")\"
    if sed 's/rhel10/centos10/g; s/RHEL 10/CentOS 10/g; s/Red Hat Enterprise Linux 10/CentOS Stream 10/g' \"\$rhel10_ds\" > \"\$centos10_ds\" 2>/dev/null; then
        echo \"Created adapted data stream: \$centos10_ds\"
        return 0
    fi
    return 1
}

# Find or create STIG data stream
find_stig_ds() {
    local ssg_dir=\"/usr/share/xml/scap/ssg/content\"
    
    # Check for existing CentOS 10 data stream
    if [ -f \"\${ssg_dir}/ssg-centos10-ds.xml\" ]; then
        echo \"\${ssg_dir}/ssg-centos10-ds.xml\"
        return 0
    fi
    
    # Try to create from RHEL 10
    local rhel10_ds=\"\${ssg_dir}/ssg-rhel10-ds.xml\"
    if [ -f \"\$rhel10_ds\" ]; then
        local centos10_ds=\"\${ssg_dir}/ssg-centos10-ds.xml\"
        if adapt_rhel10_to_centos10 \"\$rhel10_ds\" \"\$centos10_ds\"; then
            echo \"\$centos10_ds\"
            return 0
        fi
        echo \"ERROR: Failed to create CentOS 10 data stream from RHEL 10\" >&2
        return 1
    else
        echo \"ERROR: RHEL 10 data stream not found: \$rhel10_ds\" >&2
        echo \"ERROR: Cannot create CentOS 10 data stream without RHEL 10 source\" >&2
        return 1
    fi
}

# Check/install OpenSCAP
if ! command -v oscap &> /dev/null; then
    echo \"Installing OpenSCAP...\"
    if command -v dnf &> /dev/null; then
        sudo dnf install -y openscap-scanner scap-security-guide
    elif command -v yum &> /dev/null; then
        sudo yum install -y openscap-scanner scap-security-guide
    fi
fi

# Find STIG data stream
STIG_DS=\$(find_stig_ds)
if [ -z \"\$STIG_DS\" ] || [ ! -f \"\$STIG_DS\" ]; then
    echo \"Installing scap-security-guide...\"
    if command -v dnf &> /dev/null; then
        sudo dnf install -y scap-security-guide
    elif command -v yum &> /dev/null; then
        sudo yum install -y scap-security-guide
    fi
    STIG_DS=\$(find_stig_ds)
fi

if [ -z \"\$STIG_DS\" ] || [ ! -f \"\$STIG_DS\" ]; then
    echo \"ERROR: STIG data stream not found\" >&2
    exit 1
fi

# Create temporary directory for reports
TMP_DIR=\$(mktemp -d)
HTML_REPORT=\"\$TMP_DIR/stig-compliance.html\"
XML_REPORT=\"\$TMP_DIR/stig-compliance.xml\"

# Run oscap
echo \"Running OpenSCAP evaluation...\"
if [ \"$REPORT_FORMAT\" = \"html\" ] || [ \"$REPORT_FORMAT\" = \"both\" ]; then
    oscap xccdf eval --profile $STIG_PROFILE --report \"\$HTML_REPORT\" \"\$STIG_DS\"
fi

if [ \"$REPORT_FORMAT\" = \"xml\" ] || [ \"$REPORT_FORMAT\" = \"both\" ]; then
    oscap xccdf eval --profile $STIG_PROFILE --results \"\$XML_REPORT\" \"\$STIG_DS\"
fi

# Output report paths
echo \"REPORTS_DIR=\$TMP_DIR\"
echo \"HTML_REPORT=\$HTML_REPORT\"
echo \"XML_REPORT=\$XML_REPORT\"
REMOTE_SCRIPT_EOF
chmod +x $remote_script"
    
    # Execute remote script and capture output
    print_info "Executing validation on remote host..."
    local remote_output
    remote_output=$(ssh "$host" "bash $remote_script")
    
    # Parse output to get report paths
    local remote_reports_dir
    remote_reports_dir=$(echo "$remote_output" | grep "REPORTS_DIR=" | cut -d'=' -f2)
    local remote_html_report
    remote_html_report=$(echo "$remote_output" | grep "HTML_REPORT=" | cut -d'=' -f2)
    local remote_xml_report
    remote_xml_report=$(echo "$remote_output" | grep "XML_REPORT=" | cut -d'=' -f2)
    
    # Download reports
    if [ -n "$remote_reports_dir" ]; then
        print_info "Downloading reports from remote host..."
        
        if [ "$REPORT_FORMAT" = "html" ] || [ "$REPORT_FORMAT" = "both" ]; then
            if [ -n "$remote_html_report" ]; then
                scp "$host:$remote_html_report" "$HTML_REPORT"
                print_info "Downloaded HTML report: $HTML_REPORT"
            fi
        fi
        
        if [ "$REPORT_FORMAT" = "xml" ] || [ "$REPORT_FORMAT" = "both" ]; then
            if [ -n "$remote_xml_report" ]; then
                scp "$host:$remote_xml_report" "$XML_REPORT"
                print_info "Downloaded XML report: $XML_REPORT"
            fi
        fi
        
        # Cleanup remote files
        ssh "$host" "rm -rf $remote_reports_dir $remote_script" 2>/dev/null || true
    else
        print_error "Failed to retrieve report paths from remote host"
        print_error "Remote output: $remote_output"
        exit 1
    fi
}

# Main execution
if [ -n "$TARGET_HOST" ] && [ "$REMOTE_MODE" = true ]; then
    # Remote validation
    run_remote_validation "$TARGET_HOST"
elif [ -n "$TARGET_HOST" ]; then
    # Remote validation (implicit)
    print_warning "Host specified but --remote not set. Assuming remote mode."
    run_remote_validation "$TARGET_HOST"
else
    # Local validation
    run_local_validation
fi

# Summary
print_section "Validation Summary"
print_info "Validation completed!"

if [ "$REPORT_FORMAT" = "html" ] || [ "$REPORT_FORMAT" = "both" ]; then
    if [ -f "$HTML_REPORT" ]; then
        print_info "HTML Report: $HTML_REPORT"
        print_info "  Open in browser: file://$(realpath "$HTML_REPORT")"
    else
        print_warning "HTML report not found: $HTML_REPORT"
    fi
fi

if [ "$REPORT_FORMAT" = "xml" ] || [ "$REPORT_FORMAT" = "both" ]; then
    if [ -f "$XML_REPORT" ]; then
        print_info "XML Report: $XML_REPORT"
    else
        print_warning "XML report not found: $XML_REPORT"
    fi
fi

print_info "All reports saved to: $REPORT_DIR/"

