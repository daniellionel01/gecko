# Deployment

_This guide has been written to work for `Ubuntu 24.04.3 LTS`. Other linux distributions and versions have not been tested by me._

In this guide we will go through every miniscule step from a fresh server to a running instance of this service.

## Security Basics

To harden our server, we will first take measurements to improve the security situation.

Login to the server:
```sh
ssh root@<server_ip>
```

Disable password authentication and root login:
```sh
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
systemctl reload ssh
```

Enable the [UFW (Uncomplicated Firewall)](https://wiki.ubuntu.com/UncomplicatedFirewall):
```sh
ufw allow ssh
ufw allow http
ufw allow https
ufw enable
```

Enable automatic security updates:
```sh
apt install --yes unattended-upgrades
systemctl start unattended-upgrades
```

For additional security, we will create a dedicated user that is not root. This user will be able to run sudo commands:
```sh
adduser max
usermod -aG sudo max

rsync -a ~/.ssh/ /home/max/.ssh/
chown -R max:max /home/max/.ssh/
```

Make sure to keep your root ssh connection open while trying to login to the new user, in case something goes wrong.
Since we disabled root login in the first step, you could lock yourself out:
```sh
ssh max@<server_ip>
```

## Useful Software

This software is not technically required to run the service successfully, but I found them very productive in
my everyday sys-ops tasks.

```sh
# install https://github.com/atuinsh/atuin for really useful shell history
bash <(curl --proto '=https' --tlsv1.2 -sSf https://setup.atuin.sh)
atuin import auto
```

## Enable Podman v5

Ubuntu 24 comes with podman v4 by default (using `apt-get`). To enable v5, we have to go through the following steps:
```sh
sudo cp /etc/apt/sources.list.d/ubuntu.sources /etc/apt/sources.list.d/ubuntu.sources.bak
sudo tee /etc/apt/sources.list.d/ubuntu.sources >/dev/null <<'EOF'
Types: deb
URIs: https://mirror.hetzner.com/ubuntu/packages
Suites: noble noble-updates noble-backports plucky plucky-updates plucky-backports
Components: main universe restricted multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: https://mirror.hetzner.com/ubuntu/security
Suites: noble-security plucky-security
Components: main universe restricted multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF

sudo tee /etc/apt/preferences.d/podman.pref >/dev/null <<'EOF'
Package: *
Pin: release n=plucky-security
Pin-Priority: 990

Package: podman buildah golang-github-containers-common crun libgpgme11t64 libgpg-error0 golang-github-containers-image catatonit conmon containers-storage
Pin: release n=plucky
Pin-Priority: 991

Package: libsubid4 netavark passt aardvark-dns containernetworking-plugins libslirp0 slirp4netns
Pin: release n=plucky
Pin-Priority: 991

Package: *
Pin: release n=plucky
Pin-Priority: 400
EOF
```

```sh
sudo apt update
sudo apt install podman
```

## Essential Software

This software is required to run the service on a server.
```sh
sudo apt install --yes podman caddy sqlite3
```

We use github actions to automatically build our container image. For our server to automatically
be able to download it, we have to authenticate the github container registry (ghrc.io):
```sh
echo "YOUR_GITHUB_PAT" | sudo podman login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin
```

## Service Prerequsites

We will need a few things on our server before we instantiate it with podman. Namely an environment
variable file and a service directory. The service directory stores the database and media files.

We will create a directory in `/srv` (short for "service data"). It requires sudo privileges, but we
want the user `max` to be able to operate in it:
```sh
sudo install -d -m 700 -o max -g max /srv/max
```

Make sure to get and insert your `TMDB_API_KEY` from [https://www.themoviedb.org/documentation/api](https://www.themoviedb.org/documentation/api). Let's create the `.env` file:
```sh
sudo tee /srv/max/.env >/dev/null <<EOF
DATABASE_URL=sqlite:/data/max.db
WEB_SECRET_KEY_BASE=$(openssl rand -hex 32)
WEB_PORT=3000
TMDB_API_KEY=...
STORAGE_DIRECTORY_PATH=/data/storage
EOF
```

Create a systemd service:
```sh
sudo tee /etc/containers/systemd/max.container >/dev/null <<'EOF'
[Unit]
Description=Self hosted media application
After=local-fs.target

[Container]
Image=ghcr.io/daniellionel01/max:latest
AutoUpdate=registry
PublishPort=3000:3000

Volume=/srv/max:/data:rw,z

EnvironmentFile=/srv/max/.env

# Restart the service if the page no longer loads
HealthCmd=sh -c /app/healthcheck.sh
HealthInterval=30s
HealthTimeout=5s
HealthRetries=3
HealthOnFailure=restart

[Service]
Delegate=yes
TimeoutStopSec=30
KillMode=mixed
RestartSec=5

[Install]
WantedBy=multi-user.target default.target
EOF
```

## Starting the Service

For the service to be accessible via https, all you need to do is point an `A` DNS record to the IP of your server.
In this example: `max.kurz.net`.

This will start the systemd service, which in turn manages a podman container instance:
```sh
systemctl daemon-reload
systemctl start max.service

# verify the service is running
$ curl -I localhost:3000/login
HTTP/1.1 200 OK
```

Now for the reverse proxy:
```sh
sudo tee /etc/caddy/Caddyfile >/dev/null <<'EOF'
max.kurz.net {
  reverse_proxy localhost:3000
}
EOF

sudo systemctl restart caddy
```

It will take a couple of minutes for the SSL certificate to be generated and the DNS to propogate completely to your region, so don't forget to be patient!

## Creating a User

Our service should now be running and accessible through the internet. Since the database has just been created, we will manually create a user.

There is a command we can run with the `max` package to give us a hash and salt for our password:
```sh
sudo podman run --rm max run hash <password>
```

Wow connect to the database and insert the user with the salt and hash from the previous command:
```sh
sudo sqlite3 /srv/max/max.db
sqlite> insert into user (username, salt, password_hash, admin) values ('admin', '...', '...', 0);
```

## CI/CD

Every push to main builds and pushes to the github container registry under `ghcr.io/daniellionel01/max:latest`.

The systemd service is setup with `AutoUpdate=registry` which will pull the updated image every 60 minutes.

If you want to force refresh systemd with the new image, you can do the following:

```sh
sudo podman pull ghcr.io/daniellionel01/max:latest
sudo systemctl restart max.service
```
