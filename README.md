# Flask IPA Signer 🚀 

**An automated IPA Signer for Linux environments.**

This project provides a simple IPA signing server using Python Flask, `zsign`, and Cloudflare tunnels to bypass SSL requirements for iOS installations.

---

## ✨ Features

* **One-command setup:** Automatic dependency handling and compilation.
* **Cloudflare Integration:** Secure tunnels for `itms-services://` compatibility.
* **Easy Workflow:** Integrated with iOS Shortcuts for a seamless mobile experience.
* **OCSP Checker:** Use zsign's new feature to verify the validity of previously signed IPA files, and to verify the OCSP status of the certificate used by the server for signing, and external certificates.
---

## 🛠️ Quick Setup

I have simplified the installation process. You no longer need to manually compile dependencies or install libraries.

1. **Clone the repository:**
```bash
git clone https://github.com/usedoperative-sudo/flask-ipa-signer.git
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

* [File Transfer Shortcut](https://drive.google.com/file/d/1R7qFfyKA1qbGeAWe7ZMyVVxp672OjToO/view?usp=drivesdk) (**Outdated**)
* [Signing Shortcut](https://www.icloud.com/shortcuts/00996ede9a144d5fbbbb142d8ea1c335)

### 2. Transferring Certificates (`.p12` & `.mobileprovision`, **Shortcut Outdated!!**)

1. Open a SSH server pn the signing server
2. On your iDevice, use a terminal emulator or a SFTP transfer app.
3. Find your server's local IP, then send the files with the app interface/`scp` command to this project root directory.
4. Once both files are transferred, stop the SSH server on the signing server with `Ctrl + C` or `pkill` command.

> [!TIP]
> **For Remote Servers (GitHub Codespaces, Oracle, Google Colab):**
> I recommend using a **VPN and SSH** together. This allows you to use `scp` or direct transfer to the VPN-assigned IP, avoiding the hassle of finding public IPs or opening ports.

### 3. Signing and Installing IPAs

1. On the server, run:
`python3 firmador.py`
2. On your iDevice, run the **Signing Shortcut**.
3. The server will generate a `https://*.trycloudflare.com` link. Copy and paste this URL into the Shortcut when prompted.
4. Select your **IPA file**, enter the **Bundle ID**, and the **.p12 password**.
5. Wait a few seconds. Google Chrome will automatically open to install your signed app via `itms-services`.

---

## ⚠️ Notes

* ~**Language:** Currently, server logs are in Spanish~ [**English translation is here!**].
* ~**App Names:** The script uses the IPA filename as the app's display name, but this does not affect functionality~ [**Now this was solved too!**].
* ~**WIP:** Termux support is currently under development~ [**Termux is now fully supported**].
* ~**`zsign` updated:** Zhlynn (the author of zsign) updated their project; Flask IPA Signer has already been adapted for desktop Linux environments, but I cannot currently verify compatibility with Android (Termux) environments~ [**`zsign`'s last version is now fully suppported in both environments**]
---

## 🤝 Acknowledgements

A huge thanks to the community for helping improve this tool. 

Special shoutout to **u/Luiscorona511** from [Reddit](https://www.reddit.com/user/Luiscorona511), the project's very first tester! (Proof [here](https://drive.google.com/file/d/1ietX2xB13Dm46GW5Llx92oIPqgyCkWWA/view?usp=drivesdk).) - Because of them I know the project works in iOS 26.4
