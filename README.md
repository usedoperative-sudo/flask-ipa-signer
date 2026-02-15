# flask-ipa-signer

**English description**

A simple IPA Signer based in Python Flask library, zsign and free CloudFlare tunnels

*Requirements*
- `zsign` command in `/usr/bin` or `/bin`
- `cloudflared` command in `/usr/bin` or `/bin`
- Python Flask library installed
- Google Chrome installed in iDevice

*Compiling `zsign`*

1.- Clone zhlynn's zsign repo from https://github.com/zhlynn/zsign

2.- Install dependencies
```
apt install -y g++ pkg-config libssl-dev libminizip-dev
```

3.- Change current directory to `zsign/build/linux`

4.- Build with `make clean && make`

5.- Move or link compiled binary to `/usr/bin` or `/bin`

*Installing Flask*

Use `pip` or `apt` to install the Flask library

`pip` method:

`pip install Flask`

`apt` method:

`apt install python3-flask -y`

*Installing `cloudflared`*

1.- Download `cloudflared` binary from CloudFlare website, check for the correct arquitecture
https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/downloads/

2.- Move or link downloaded binary to `/usr/bin` or `/bin`

*Downloading, preparing and running the signing server*

**Warning**: The Python logs will be in Spanish

1.- Clone this repo on signing server

2.- Download the next shortcut in your iDevice `LINK_NOT_READY`

*Transfering files*

3.- Run `python3 receptor.py` in the signing server

4.- Run the downloaded shortcut

5.- Write the server IP on the shortcut

6.- Select thes files to transfer to the server (.mobileprovision and .p12 files), the file names don't matter

7.- Repeat from step 4 for both files

8.- End the Python script with ^C (Ctrl + C)

*Running the server*

9.- Download this shortcut `LINK_NOT_READY`

10.- In the server run `python3 firmador.py`

11.- In the iDevice run the downloaded Shortcut

12.- The server will generate a `https://*.trycloudflare.com` link, send and copy the link in the Shortcut when it prompts a URL

13.- When the shortcut requests to select a file, you must select the desired IPA file

14.- Enter the Bundle ID of the desired app and .p12 password when prompted by the shortcut

15.- Now just wait

16.- Wait some seconds, the IPA file will be signed and a `itms-services://` will be generated, then Chrome will open to install the app

17.- It should be noted that the file name will be taken as the app's name in the system by the script, but this does not affect its functionality.
