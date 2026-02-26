# flask-ipa-signer 🚀 

**An automated IPA Signer for Linux environments.**

This project provides a simple IPA signing server using Python Flask, `zsign`, and Cloudflare tunnels to bypass SSL requirements for iOS installations.

---

## ✨ Features

* **One-command setup:** Automatic dependency handling and compilation.
* **Cloudflare Integration:** Secure tunnels for `itms-services://` compatibility.
* **Easy Workflow:** Integrated with iOS Shortcuts for a seamless mobile experience.

---

## 🛠️ Quick Setup

I have simplified the installation process. You no longer need to manually compile dependencies or install libraries.

1. **Clone the repository:**
```bash
git clone https://github.com/YOUR_USERNAME/flask-ipa-signer.git
cd flask-ipa-signer

```


2. **Run the auto-setup script:**
```bash
chmod +x auto-setup.sh
./auto-setup.sh
```


*This script will install `zsign`, `cloudflared`, Flask, and all necessary dependencies automatically.*

---

## 📱 How to Use

### 1. Preparation

Download the following Shortcuts on your iDevice:

* [File Transfer Shortcut](https://drive.google.com/file/d/1R7qFfyKA1qbGeAWe7ZMyVVxp672OjToO/view?usp=drivesdk)
* [Signing Shortcut](https://drive.google.com/file/d/1ms69iTsh1PF7wPSeBmWZIFQvJgE9bGRi/view?usp=drivesdk)

### 2. Transferring Certificates (`.p12` & `.mobileprovision`)

1. On the server, run:
`python3 receptor.py`
2. On your iDevice, run the **File Transfer Shortcut**.
3. Enter your server's IP and select the files to upload.
4. Once both files are transferred, stop the script on the server with `Ctrl + C`.

> [!TIP]
> **For Remote Servers (GitHub Codespaces, Oracle, Google Colab):**
> We recommend using a **VPN and SSH** together. This allows you to use `scp` or direct transfer to the VPN-assigned IP, avoiding the hassle of finding public IPs or opening ports.

### 3. Signing and Installing IPAs

1. On the server, run:
`python3 firmador.py`
2. On your iDevice, run the **Signing Shortcut**.
3. The server will generate a `https://*.trycloudflare.com` link. Copy and paste this URL into the Shortcut when prompted.
4. Select your **IPA file**, enter the **Bundle ID**, and the **.p12 password**.
5. Wait a few seconds. Google Chrome will automatically open to install your signed app via `itms-services`.

---

## ⚠️ Notes

* **Language:** Currently, server logs are in Spanish (English translation coming soon!).
* **App Names:** The script uses the filename as the app's display name, but this does not affect functionality.
* **WIP:** Termux support is currently under development.
