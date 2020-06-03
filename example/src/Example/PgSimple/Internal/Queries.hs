{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE ImplicitParams #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE OverloadedStrings #-}
module Example.PgSimple.Internal.Queries where

import Database.PostgreSQL.Tx (Tx(tx), TxM)
import qualified Control.Exception as Exception
import qualified Database.PostgreSQL.Simple as PG.Simple
import qualified Database.PostgreSQL.Tx.Simple as Tx
import qualified Example.PgSimple.Internal.DB as DB

new :: Dependencies -> IO DB.Handle
new deps =
  pure DB.Handle
    { DB.insertMessage = insertMessage deps
    , DB.fetchMessage = fetchMessage deps

    , DB.close = mempty
    }

withHandle :: Dependencies -> (DB.Handle -> IO a) -> IO a
withHandle deps = Exception.bracket (new deps) DB.close

newtype Dependencies = Dependencies { conn :: PG.Simple.Connection }

run :: Dependencies -> Tx.PgSimpleM a -> TxM a
run deps = tx (conn deps)

insertMessage :: Dependencies -> String -> TxM Int
insertMessage deps s = run deps do
  Tx.query
    "insert into foo(message) values (?) returning id"
    (PG.Simple.Only s)
    >>= \case
      [PG.Simple.Only k] -> pure k
      rows -> error $ "Expected exactly 1 row, got " <> show (length rows)

fetchMessage :: Dependencies -> Int -> TxM (Maybe String)
fetchMessage deps k = run deps do
  Tx.query
    "select message from foo where id = ?"
    (PG.Simple.Only k)
    >>= \case
      [] -> pure Nothing
      [PG.Simple.Only s] -> pure $ Just s
      rows -> error $ "Expected 0 or 1 rows, got " <> show (length rows)
