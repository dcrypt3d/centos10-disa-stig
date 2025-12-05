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

# Function to find STIG data stream
find_stig_ds() {
    local ds_paths=(
        "/usr/share/xml/scap/ssg/content/ssg-centos10-ds.xml"
        "/usr/share/xml/scap/ssg/content/ssg-rhel10-ds.xml"
        "/usr/share/xml/scap/ssg/content/ssg-rhel9-ds.xml"
        "${PWD}/roles/rhel9STIG/files/ssg-centos10-ds.xml"
    )
    
    for path in "${ds_paths[@]}"; do
        if [ -f "$path" ]; then
            echo "$path"
            return 0
        fi
    done
    
    return 1
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

# Find STIG data stream
find_stig_ds() {
    local paths=(
        \"/usr/share/xml/scap/ssg/content/ssg-rhel10-ds.xml\"
        \"/usr/share/xml/scap/ssg/content/ssg-rhel9-ds.xml\"
        \"/usr/share/xml/scap/ssg/content/ssg-centos10-ds.xml\"
    )
    
    for path in \"\${paths[@]}\"; do
        if [ -f \"\$path\" ]; then
            echo \"\$path\"
            return 0
        fi
    done
    return 1
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

