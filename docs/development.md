# Development

*Admission: I develop on macos, I have no idea if or how this runs on windows.*

## Software

To run this software on your local machine you need the following software installed:
- https://gleam.run
- https://www.ffmpeg.org

Technically optional, but used in this project:
- https://github.com/pressly/goose
- https://github.com/casey/just
- https://github.com/wagoodman/dive
- https://podman.io

## Environment Variables

```sh
# .env / to run locally without container
tee .env >/dev/null <<EOF
DATABASE_URL=file:/data/gecko_dev.db
WEB_SECRET_KEY_BASE=$(openssl rand -hex 32)
WEB_PORT=3000
EOF
``````

```sh
# .env.docker / to run in podman container
tee .env.docker >/dev/null <<EOF
DATABASE_URL=file:/app/gecko_dev.db
WEB_SECRET_KEY_BASE=$(openssl rand -hex 32)
WEB_PORT=3000
EOF
```

## Database

Working with the database is done via just recipes:
```sh
just goose up                    # latest migration
just goose reset                 # roll bkac all migrations
just goose create add_column sql # create new migration
just seed                        # loads ./priv/db/seed.sql
```

Full `goose` documentation: https://github.com/pressly/goose

## Running Locally

This will run a web server and the media converter agent in a static supervisor (OTP).
We use `just` because it automatically loads in the `.env` file.

```sh
just run
# -- or --
just watch # restarts on *.gleam file changes
```

## Running Podman

Make sure you create a `.env.docker` file which is going to be used for the podman container.

```sh
just pod
```

## Docker Image Size

The size of the docker image should always be kept in mind and monitored.

```sh
dive podman://gecko
# or
CI=true dive podman://gecko
```

## Linting

- Dockerfiles: https://github.com/hadolint/hadolint
- SQL files: https://github.com/sqlfluff/sqlfluff
- Bash Scripts: https://github.com/koalaman/shellcheck

## Version Audits

This is how you can open a shell session to explore the alpine base (f.e. for package versions)
```sh
podman run --rm -it erlang:28.0.2.0-alpine sh
```
```sh
apk version ffmpeg
apk info ffmpeg
```
