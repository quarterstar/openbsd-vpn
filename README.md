# OpenBSD VPN

OpenBSD VPN is a specialized deployment script for WireGuard VPN servers on OpenBSD instances. Moreover, the script:

0. searches for already existing OpenBSD VPN instances;
0. deletes any already existing instances, and;
0. automatically deploys a new one after it has finished cleaning up past instances.

Furthermore, the server deploys the VPN server at a random datacenter location, if allowed by the selected `<plan>`.

## Table of Contents

- [Backends](#backends)
- [Specification](#specification)
- [Dependencies](#dependencies)
- [Usage](#usage)

## Backends

Backends exist for the deployment of the instance and VPN. Also, they are responsible for picking a random location for the VPN according to the plan selected.
 Currently, this script supports the following cloud providers:

- Vultr

> [!NOTE]
> Many cloud providers are missing. If you would like to contribute, refer to the specification below.

### Specification

The information in this section only concerns developers of backend APIs.

Each backend needs to follow the prescribed filesystem-oriented API:

#### Input

| File        | Required | Arguments                  | Purpose
| ----------- | -------- | -------------------------- | -------
| `create.py` | Yes      | `api_key`, `plan`, `label` | Create a new VPN server instance; install WireGuard, SSH and configure firewall
| `delete.py` | No       | `api_key`, `plan`, `label` | Delete old VPN server instance

- `api_key`: the API key generated by the cloud provider for the account.
- `plan`: the plan chosen by the user for the server instance.
- `label`: the label chosen by the user for the server instance. (This is used to detect old instances and delete them.)

Input files should reside in `./backend/$BACKEND` and backend can be selected via the `<provider>` argument described in [Usage](#usage).

#### Output

Output after instance creation (in `create.py`) should be stored in the `instance.txt` text file in the following form:

```
OLD_ID=<id_of_old_instance>
IP=<ip_of_new_instance>
PASSWORD=<root_password_of_new_instance>
```

`OLD_ID` may be omitted if the respective backend does not support old instance deletion.

## Dependencies

- `bash`
- `python3`
- `openssh`
- `sshpass`

> [!NOTE]
> Dependencies are automatically installed via shebang in Nix environments.

## Usage

Run the deployment script with the necessary credentials and information:

```
Usage: ./deploy.sh --provider <provider> --wg-pub-key <wg-pub-key> --api-key <api-key> --plan <plan> --label <label> [--hosts <hosts>] [--port <port>]
```

If the deployment is succesful, a file `server.env`, will be created in the following form:

```
IP=<ip_address_of_new_instance>
PUBLIC_KEY=<public_key_of_new_instance>
```

### Arguments

- `<provider>`: the cloud provider (backend) to deploy the VPN to.
- `<wg-pub-key>`: the public key of the WireGuard peer connecting to the VPN server.
- `<api-key>`: the Vultr account's API key.
- `<plan>`: the plan to be used for Vultr cloud instances.
- `<label>`: the label to be used for the cloud instances.
- `<port>`: the port that should be used by the WireGuard server. (Default: `51820`)
- `<mtu>`: the Maximum Transmission Unit that should be allowed by the WireGuard server.
- `<listen-address>`: the address the WireGuard server should listen to.
- `<hosts>`: set of comma-separated internal IP addresses of the hosts that should be allowed access to the WireGuard server. (Default: `10.1.0.2/32`)
- `<locations>`: pool of comma-separated candidates for regions the backend should pick from for the instance deployment.

### Example (Fake Data)

```
# Example usage for Vultr deployment
# Keep API key secret!
./deploy.sh \
    --provider vultr \
    --wg-pub-key U4wn5njgD5wlG3HanQcenrKsWc2okND4IYqNoGa8HBw= \
    --api-key UW9KKWA23YYNPRYKL9XWJAQH24UAX3H5YF9W \
    --plan vc2-1c-1gb \
    --label obsdvpn \
    --listen-address 10.1.0.1 \
    --port 51820 \
    --mtu 1500 \
    --hosts 10.1.0.2/32,192.168.2.0/24 \
    --locations ewr,lax,ord,ams,syd,sgp \
```

## Troubleshooting

### Cannot connect to certain websites / Cannot connect to websites at all.

The issue is most likely related to your MTU. Usually, it is in the 1400-1500 range. Consider increasing or decreasing it until a certain value gives improved results. Look at [Additional Suggestions](#additional) for more information.

## Additional Suggestions

- Use [nr-wg-mtu-finder](https://github.com/nitred/nr-wg-mtu-finder) to find the optimal MTU for your WireGuard server.
- If you like this deployment solution, consider checking out my hardened NixOS router, [Nixter](https://github.com/quarterstar/nixter), for an intermediary router solution in your home network.

## License

All code included in this repository is licensed under the terms of the [MIT License](LICENSE).
