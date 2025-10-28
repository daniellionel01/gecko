set dotenv-load

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

watch:
  watchexec \
    --restart --verbose --wrap-process=session --stop-signal SIGTERM \
    --exts gleam --debounce 500ms --watch src/ \
    -- "just kill-ffmpeg && gleam run"

@loc:
  echo "SOURCE CODE"
  cloc . --vcs=git --exclude-dir=integration,test

@tree:
  tree -I '*.woff2|build|deps|.rebar3|ebin|.eunit|logs|*.beam|*.dump|.git|cover|doc|*.plt|*.crashdump|rel|.DS_Store'
