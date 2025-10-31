-- +goose Up
create table if not exists user (
    id integer not null primary key autoincrement,
    created_at text default current_timestamp,
    username text not null unique,
    salt text not null,
    password_hash text not null,
    admin integer not null default false
) strict;

-- +goose Down
drop table if exists user;
