{-# LANGUAGE TemplateHaskell #-}

module DataSource (
    connect, defineTable
  ) where

import Database.HDBC.Query.TH (defineTableFromDB)
import Database.HDBC.Schema.Driver (typeMap)
import Database.HDBC.Schema.SQLite3 (driverSQLite3)
import Database.HDBC.Sqlite3 (Connection, connectSqlite3)
import Language.Haskell.TH (Q, Dec, TypeQ)

connect :: IO Connection
connect = connectSqlite3 "examples.db"

defineTable :: String -> Q [Dec]
defineTable tableName =
  defineTableFromDB
    connect
    (driverSQLite3 { typeMap = [("FLOAT", [t|Double|])] }) -- overwrite the default type map with yours
    "main" -- schema name, ignored by SQLite
    tableName
    [''Show]
