set dotenv-load

export GOOSE_MIGRATION_DIR := "./priv/db/migrations"

default:
  @just --choose

dev:
  gleam dev

test:
  gleam test

codegen:
  gleam run -m parrot

lint:
  podman run --rm -i docker.io/hadolint/hadolint < Dockerfile
  uvx sqlfluff lint src/gecko/sql/ --dialect sqlite
  shellcheck bin/*.sh

run:
  just codegen
  gleam run

pod:
  podman build -t gecko .
  podman run --rm --env-file .env.docker -p 3000:3000 gecko

watch:
  watchexec \
    --restart --verbose --wrap-process=session --stop-signal SIGTERM \
    --exts gleam --debounce 500ms --watch src/ \
    -- "gleam run"

@loc:
  echo "SOURCE CODE"
  cloc . --vcs=git --exclude-dir=integration,test

@tree:
  tree -I '*.woff2|build|deps|.rebar3|ebin|.eunit|logs|*.beam|*.dump|.git|cover|doc|*.plt|*.crashdump|rel|.DS_Store'

@gen-secret-key:
  openssl rand -base64 64 | tr -dc 'A-Za-z0-9' | head -c64; echo

goose +args:
  goose sqlite3 "${DATABASE_URL}" {{args}}

seed:
  sqlite3 "${DATABASE_URL}" < priv/db/seed.sql

db-shell:
  sqlite3 "${DATABASE_URL}"

@deps-ls:
  gleam deps list | column -t

repomix:
  bunx repomix --include "src/**/*.gleam,**/*.sh,**/*.yml,Justfile" --style xml -o REPO.xml
