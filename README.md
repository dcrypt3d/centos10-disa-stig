# DISA STIG Compliance for CentOS 10 Stream

This repository contains Ansible playbooks and configurations to apply DISA STIG V2R6 (Security Technical Implementation Guides) compliance to CentOS 10 Stream systems.

## Overview

DISA STIGs provide security configuration standards for Department of Defense systems. This project uses the **official DISA RHEL 9 STIG Ansible role** to automate the application of these security controls to CentOS 10 Stream systems.

**Note**: CentOS Stream 10 is based on RHEL 10. While RHEL 10 STIG may not be available yet, the RHEL 9 STIG role provides compatible security controls. When RHEL 10 STIG becomes available, you may need to update the role directory from `rhel9STIG` to `rhel10STIG`.

**Note**: This project includes the official DISA STIG Ansible role from the DISA STIG distribution package. All STIG controls are configured via variables in the role's defaults.

## Prerequisites

- Ansible 2.9 or higher
- Python 3.6 or higher
- SSH access to target CentOS 10 Stream systems
- Sudo/root privileges on target systems

## Installation

1. **Install Ansible** (if not already installed):
   ```bash
   # On RHEL/CentOS
   sudo yum install ansible
   ```

2. **No additional roles needed**: The DISA STIG role is included locally in the `roles/rhel9STIG/` directory.

## Configuration

1. **Update inventory file** (`inventory.yml`):
   Edit the file and add your CentOS 10 Stream hosts:
   ```yaml
   centos10_hosts:
     hosts:
       server1:
         ansible_host: 192.168.1.100
         ansible_user: your_user
   ```

2. **Configure SSH access**:
   Ensure you can SSH into the target systems without password prompts (or configure SSH keys).

3. **Review playbook variables** (`playbook.yml`):
   Customize STIG settings according to your security requirements.

## Usage

### Apply all STIG controls:
```bash
ansible-playbook -i inventory.yml playbook.yml --ask-become-pass
```

Or use the provided script:
```bash
# Linux/Mac
./enforce.sh
```

### Dry run (check mode):
```bash
ansible-playbook -i inventory.yml playbook.yml --check --ask-become-pass
```

### Limit to specific hosts:
```bash
ansible-playbook -i inventory.yml playbook.yml --limit server1 --ask-become-pass
```

### Customize STIG controls:
Edit `roles/rhel9STIG/defaults/main.yml` to enable/disable specific STIG rules. Each rule has a `rhel9STIG_stigrule_XXXXX_Manage` variable that can be set to `True` or `False`.

## Alternative: Using OpenSCAP

If you prefer using OpenSCAP (SCAP Security Guide) instead of Ansible:

1. **Install OpenSCAP on CentOS 10 Stream**:
   ```bash
   sudo dnf install openscap-scanner scap-security-guide
   ```

2. **Scan for compliance**:
   ```bash
   sudo oscap xccdf eval --profile stig --report report.html \
     /usr/share/xml/scap/ssg/content/ssg-rhel10-ds.xml
   ```
   **Note**: If `ssg-rhel10-ds.xml` is not available, use `ssg-rhel9-ds.xml` as a fallback.

3. **Remediate automatically**:
   ```bash
   sudo oscap xccdf eval --remediate --profile stig \
     /usr/share/xml/scap/ssg/content/ssg-rhel10-ds.xml
   ```
   **Note**: If `ssg-rhel10-ds.xml` is not available, use `ssg-rhel9-ds.xml` as a fallback.

## Important Notes

⚠️ **WARNING**: Applying STIGs will make significant security changes to your system:
- May disable services and features
- Will enforce strict password policies
- Will configure firewall rules
- May require system reboot
- Could break existing applications

**Recommendations**:
1. Test in a non-production environment first
2. Review all changes before applying
3. Take system backups before running
4. Document any custom exceptions needed
5. Reboot after applying STIGs

## Post-Deployment

After applying STIGs:

1. **Check the XML compliance report**: The STIG XML callback plugin generates a compliance report automatically. Check the output path shown during execution (defaults to a temp directory).
2. **Reboot the system** (if prompted or required)
3. **Verify services** are running correctly
4. **Test application functionality**
5. **Review any failed STIG rules** in the XML report

## STIG Rule Customization

The DISA STIG role includes hundreds of individual STIG rules. Each rule can be enabled or disabled by modifying variables in `roles/rhel9STIG/defaults/main.yml`.

Example: To disable a specific STIG rule (e.g., R-257779), set:
```yaml
rhel9STIG_stigrule_257779_Manage: False
```

**Warning**: Disabling STIG rules may reduce security compliance. Only disable rules if you have a documented exception or alternative control.

## Troubleshooting

### Common Issues

1. **Role not found**:
   - The role should be in `roles/rhel9STIG/` directory
   - Verify the role was copied correctly from the DISA STIG distribution

2. **Permission denied**:
   - Verify SSH access and sudo privileges
   - Use `--ask-become-pass` flag

3. **Service failures**:
   - Some STIGs disable services that may be needed
   - Review which services are being disabled in the role's tasks
   - You can disable specific STIG rules in `roles/rhel9STIG/defaults/main.yml`

4. **Callback plugin not found**:
   - Ensure `callback_plugins/stig_xml.py` exists
   - Check `ansible.cfg` has `callback_plugins = ./callback_plugins` configured

5. **XML report not generated**:
   - Check that the callback plugin is enabled in `ansible.cfg`
   - Verify the STIG XML file exists in `roles/rhel9STIG/files/`

## Resources

- [DISA STIGs](https://public.cyber.mil/stigs/)
- [Ansible Lockdown RHEL9-STIG](https://github.com/ansible-lockdown/RHEL9-STIG)
- [SCAP Security Guide](https://www.open-scap.org/)
- [CentOS Stream 10 Documentation](https://www.centos.org/documentation/)

## License

This project is provided as-is for security compliance purposes.

