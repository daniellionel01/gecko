import gecko/env
import gleam/dynamic/decode
import sqlight

pub fn main() {
  let env = env.get_env()
  echo env.db_path
  use conn <- sqlight.with_connection(env.db_path)
  // use conn <- sqlight.with_connection(":memory:")

  let sql =
    "
    drop table if exists cats;
    create table cats (name text, age int);

    insert into cats (name, age) values
    ('Nubi', 4),
    ('Biffy', 10),
    ('Ginny', 6);
    "
  let assert Ok(Nil) = echo sqlight.exec(sql, conn)

  let cat_decoder = {
    use name <- decode.field(0, decode.string)
    use age <- decode.field(1, decode.int)
    decode.success(#(name, age))
  }

  let sql =
    "
    select name, age from cats
    where age < ?
    "
  let assert Ok([#("Nubi", 4), #("Ginny", 6)]) =
    echo sqlight.query(
      sql,
      on: conn,
      with: [sqlight.int(7)],
      expecting: cat_decoder,
    )
}
