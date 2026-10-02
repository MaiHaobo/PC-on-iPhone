---
name: iOS issue
about: Report an issue or crash for iOS
title: ''
labels: ''
assignees: ''

---

**Describe the issue**
A clear and concise description of what the issue is. **BEFORE SUBMITTING YOUR ISSUE, PLEASE LOOK AT THE PINNED ISSUES AND USE THE SEARCH FUNCTION TO MAKE SURE IT IS NOT ALREADY REPORTED. ALWAYS COMMENT ON AN EXISTING ISSUE INSTEAD OF MAKING A NEW ONE.**

**Configuration (required)**
* PC on iPhone Version: 
* OS Version: 
* Device Model: 
* Is it jailbroken (name jailbreak used)? 
* How did you install PC on iPhone? 

**Crash log**
If the app crashed, you need a crash log. To get your crash log, open the Settings app and browse to `Privacy -> Analytics & Improvements -> Analytics Data` and find the latest entry for PC on iPhone. You should export the text and attach it here.

**Debug log**
For all issues, _including_ crashes, you should attach a debug log. Open PC on iPhone, and open the settings for the VM you wish to launch. Near the bottom of the configuration options (or at the top of the `QEMU` page) is `Debug Log`. Turn it on and save the VM. After you experience the issue, quit the VM and re-launch PC on iPhone. Open the VM settings again and select `Export Log...` and attach it here.

**Upload VM**
(Optional) If possible, upload the `config.plist` inside the `.utm`. If you do not have this, you can upload the entire `.utm` but note this contains your personal data. Since GitHub has an attachment size limit, you may want to upload to another service such as Google Drive. Link it here.
