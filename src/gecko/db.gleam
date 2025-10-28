//// This module contains functionality to connect to the database. The connection pre-configures
//// good defaults for working with SQlite, f.e. WAL mode (https://sqlite.org/wal.html)

import gecko/env
import gleam/dynamic/decode
import gleam/list
import gleam/option
import parrot/dev
import sqlight

/// Returns a connection to SQlite and configures the database with settings for production.
pub fn with_connection(cb: fn(sqlight.Connection) -> a) {
  let db_path = env.get_env().db_path
  use on <- sqlight.with_connection(db_path)

  // https://kerkour.com/sqlite-for-servers
  let assert Ok(_) = sqlight.exec("PRAGMA journal_mode = wal;", on:)
  let assert Ok(_) = sqlight.exec("PRAGMA synchronous = normal;", on:)
  let assert Ok(_) = sqlight.exec("PRAGMA foreign_keys = true;", on:)
  let assert Ok(_) = sqlight.exec("PRAGMA busy_timeout = 5000;", on:)
  let assert Ok(_) = sqlight.exec("PRAGMA temp_store = memory;", on:)
  let assert Ok(_) = sqlight.exec("PRAGMA cache_size = 1000000000;", on:)

  cb(on)
}

/// Runs `sqlight.query`, but ignores the output.
/// This is useful if you want to execute a prepared statement,
/// since you cannot pass any parameters to `sqlight.exec`.
pub fn query_ignore(
  statement: #(String, List(dev.Param)),
  on: sqlight.Connection,
) -> Result(Nil, sqlight.Error) {
  let #(sql, with) = statement
  let with = list.map(with, parrot_to_sqlight)
  case sqlight.query(sql, on:, with:, expecting: decode.success(Nil)) {
    Error(e) -> Error(e)
    Ok(_) -> Ok(Nil)
  }
}

pub fn query_one(
  statement: #(String, List(dev.Param), decode.Decoder(a)),
  on: sqlight.Connection,
) -> Result(option.Option(a), sqlight.Error) {
  let #(sql, with, expecting) = statement
  let with = list.map(with, parrot_to_sqlight)
  case sqlight.query(sql, on:, with:, expecting:) {
    Error(e) -> Error(e)
    Ok([row, ..]) -> Ok(option.Some(row))
    Ok([]) -> Ok(option.None)
  }
}

pub fn query_many(
  statement: #(String, List(dev.Param), decode.Decoder(a)),
  on: sqlight.Connection,
) -> Result(List(a), sqlight.Error) {
  let #(sql, with, expecting) = statement
  let with = list.map(with, parrot_to_sqlight)
  case sqlight.query(sql, on:, with:, expecting:) {
    Error(e) -> Error(e)
    Ok(rows) -> Ok(rows)
  }
}

/// Maps auto-generated parrot query parameters to sqlight values (https://github.com/daniellionel01/parrot)
pub fn parrot_to_sqlight(param: dev.Param) -> sqlight.Value {
  case param {
    dev.ParamFloat(x) -> sqlight.float(x)
    dev.ParamInt(x) -> sqlight.int(x)
    dev.ParamString(x) -> sqlight.text(x)
    dev.ParamBitArray(x) -> sqlight.blob(x)
    dev.ParamNullable(x) -> sqlight.nullable(fn(a) { parrot_to_sqlight(a) }, x)
    dev.ParamDate(_) -> panic as "sqlite does not support dates"
    dev.ParamList(_) -> panic as "sqlite does not implement lists"
    dev.ParamBool(_) -> panic as "sqlite does not support booleans"
    dev.ParamTimestamp(_) -> panic as "sqlite does not support timestamps"
    dev.ParamDynamic(_) -> panic as "dynamic parameter not implemented"
  }
}
