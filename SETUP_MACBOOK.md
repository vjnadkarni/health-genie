# MacBook Pro Setup Instructions

Follow these steps to set up your MacBook Pro M3 laptop to sync with your Mac Mini desktop via the GitHub wip branch.

## 1. Clone the Repository

Open Terminal on your MacBook Pro and run:

```bash
cd ~
mkdir -p venv
cd venv
git clone -b wip git@github.com:vjnadkarni/health-genie.git
cd health-genie
```

## 2. Set Up SSH Key

### Option A: Use existing SSH key
If you already have the `ssh-vjnadkarni-key` on your MacBook Pro:

1. Copy the SSH keys to `~/.ssh/` if not already there
2. Set correct permissions:
   ```bash
   chmod 600 ~/.ssh/ssh-vjnadkarni-key
   chmod 644 ~/.ssh/ssh-vjnadkarni-key.pub
   ```

### Option B: Create new SSH key for MacBook Pro
If you want a separate key for the laptop:

1. Generate new SSH key:
   ```bash
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/ssh-vjnadkarni-macbook-key -C "vjnadkarni@gmail.com"
   ```

2. Add the public key to GitHub:
   ```bash
   cat ~/.ssh/ssh-vjnadkarni-macbook-key.pub
   ```
   Copy the output and add it to: https://github.com/settings/keys

## 3. Configure SSH

Create or update `~/.ssh/config`:

```bash
cat >> ~/.ssh/config << 'EOF'

# GitHub for health-genie project
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/ssh-vjnadkarni-key
    IdentitiesOnly yes
    UseKeychain yes
    AddKeysToAgent yes
EOF
```

Note: Adjust the IdentityFile path if using a different key.

## 4. Add SSH Key to Keychain

```bash
ssh-add --apple-use-keychain ~/.ssh/ssh-vjnadkarni-key
```

Enter your passphrase when prompted. It will be saved in the keychain.

## 5. Test SSH Connection

```bash
ssh -T git@github.com
```

You should see: "Hi vjnadkarni! You've successfully authenticated..."

## 6. Set Up Python Virtual Environment

```bash
cd ~/venv/health-genie
python3 -m venv venv
source venv/bin/activate
```

Install any requirements (when they exist):
```bash
pip install -r requirements.txt  # if exists
```

## 7. Configure Git User

```bash
git config user.name "Vijay Nadkarni"
git config user.email "vjnadkarni@gmail.com"
```

## 8. Set Up Sync Scripts

Copy the sync scripts to ~/venv/bin/ (or create them):

```bash
mkdir -p ~/venv/bin
# The scripts should be provided or you can copy them from the Mac Mini
# Make sure they're executable:
chmod +x ~/venv/bin/push-wip.sh ~/venv/bin/pull-wip.sh
```

### Test pull-wip.sh:
```bash
pull-wip.sh
```
This should show "Already up to date" if everything is synced.

### Test push-wip.sh:
Make a small test change:
```bash
echo "# Test from MacBook Pro" >> test_macbook.txt
push-wip.sh
```

## Daily Workflow

### At Home (MacBook Pro) - Starting Work:
```bash
cd ~/venv/health-genie
pull-wip.sh
source venv/bin/activate
# Work on your project...
```

### At Home (MacBook Pro) - Before Leaving:
```bash
push-wip.sh
```

### At Work (Mac Mini) - Starting Work:
```bash
cd ~/venv/health-genie
pull-wip.sh
source venv/bin/activate
# Work on your project...
```

### At Work (Mac Mini) - Before Leaving:
```bash
push-wip.sh
```

## Troubleshooting

1. **Permission denied (publickey)**: 
   - Check SSH key is added: `ssh-add -l`
   - Re-add key: `ssh-add --apple-use-keychain ~/.ssh/ssh-vjnadkarni-key`

2. **Merge conflicts**:
   - The pull script will warn you
   - Resolve conflicts manually, then commit

3. **Uncommitted changes warning**:
   - The scripts will detect and handle this
   - Choose to stash, commit, or abort as needed

## Tips

- Always run `./push-wip.sh` before leaving a machine
- Always run `./pull-wip.sh` when starting on a machine
- The scripts will prevent most common sync issues
- Keep the virtual environment activated when working: `source venv/bin/activate`