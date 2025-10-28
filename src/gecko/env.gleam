//// This module handles environment variables for the whole application.
////
//// It is called at the very start of the main function so that the application fails
//// quickly in case a variable is missing.

import envoy
import gleam/int
import gleam/result

pub type Environment {
  Environment(db_path: String, web_port: Int, web_secret_key_base: String)
}

pub fn get_env() -> Environment {
  let assert Ok(db_path) = envoy.get("DATABASE_URL")
  let assert Ok(web_secret_key_base) = envoy.get("WEB_SECRET_KEY_BASE")
  let assert Ok(web_port) =
    envoy.get("WEB_PORT")
    |> result.unwrap("3000")
    |> int.parse

  Environment(db_path:, web_port:, web_secret_key_base:)
}
