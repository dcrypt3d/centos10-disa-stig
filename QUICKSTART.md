# Quick Start Guide - DISA STIG for CentOS 10 Stream

## Method 1: Using Ansible (Recommended)

### Step 1: Install Ansible
```bash
# On your control machine (not CentOS 10 Stream)
pip install ansible
# OR
sudo dnf install ansible
```

### Step 2: Verify Role is Present
The DISA STIG role is included locally. Verify it exists:
```bash
ls -la roles/rhel9STIG/
```

**Note**: The role comes from the official DISA STIG distribution package. Currently using RHEL 9 STIG role for CentOS 10 Stream compatibility. When RHEL 10 STIG becomes available, you may need to update to `rhel10STIG` role.

### Step 3: Configure Inventory
Edit `inventory.yml` and add your CentOS 10 Stream hosts:
```yaml
centos10_hosts:
  hosts:
    server1:
      ansible_host: 192.168.1.100
      ansible_user: your_ssh_user
```

### Step 4: Apply STIGs
```bash
# Using the script (Linux/Mac)
./enforce.sh

# Or directly with Ansible
ansible-playbook -i inventory.yml playbook.yml --ask-become-pass
```

## Method 2: Using OpenSCAP (Direct on CentOS 10 Stream)

### Step 1: Install OpenSCAP on CentOS 10 Stream
```bash
sudo dnf install -y openscap-scanner scap-security-guide
```

### Step 2: Run Compliance Check
```bash
# Check compliance (no changes) - try RHEL 10 first, fallback to RHEL 9
sudo oscap xccdf eval --profile stig --report report.html \
  /usr/share/xml/scap/ssg/content/ssg-rhel10-ds.xml || \
  sudo oscap xccdf eval --profile stig --report report.html \
  /usr/share/xml/scap/ssg/content/ssg-rhel9-ds.xml
```

### Step 3: Apply Remediations
```bash
# Apply remediations automatically - try RHEL 10 first, fallback to RHEL 9
sudo oscap xccdf eval --remediate --profile stig \
  /usr/share/xml/scap/ssg/content/ssg-rhel10-ds.xml || \
  sudo oscap xccdf eval --remediate --profile stig \
  /usr/share/xml/scap/ssg/content/ssg-rhel9-ds.xml
```

Or use the provided script:
```bash
sudo ./apply-stig-openscap.sh --remediate
```

## Method 3: Manual Application

If you prefer manual application, refer to the DISA STIG documentation:
- Download STIGs from: https://public.cyber.mil/stigs/
- Review each control manually
- Apply configurations as documented

## Common Tasks

### Check Compliance Without Changes
```bash
ansible-playbook playbook.yml --check --ask-become-pass
```

### Apply Only Specific Categories
```bash
# SSH hardening only
ansible-playbook playbook.yml --tags "ssh" --ask-become-pass

# Audit configuration only
ansible-playbook playbook.yml --tags "audit" --ask-become-pass
```

### Validate After Application
```bash
./validate-stig.sh
```

## Important Reminders

1. ⚠️ **Always test in non-production first**
2. ⚠️ **Take backups before applying**
3. ⚠️ **Review changes before applying**
4. ⚠️ **Reboot may be required after application**
5. ⚠️ **Some applications may break - test thoroughly**

## Troubleshooting

### "Role not found" error
- Run: `ansible-galaxy install -r requirements.yml`
- Or manually download from GitHub

### "Permission denied" error
- Ensure SSH access works
- Use `--ask-become-pass` flag
- Verify sudo privileges on target

### Services not starting
- Review `rhel9stig_service_disabled` in playbook.yml
- Some STIGs disable services that may be needed

## Next Steps

After applying STIGs:
1. Reboot the system
2. Verify all services are running
3. Test application functionality
4. Generate compliance report
5. Document any exceptions

