#### Working with Migrations: 
Creating tables using migration 
#golang #restAPI

```
package main

import (
    "database/sql"
    "log"
    "os"
    _ "github.com/mattn/go-sqlite3"  // Added this
    "github.com/golang-migrate/migrate"
    "github.com/golang-migrate/migrate/database/sqlite3"
    "github.com/golang-migrate/migrate/source/file"
)

func main() {
    if len(os.Args) < 2 {
        log.Fatal("Please provide a migration direction: 'up or down'")  // Fixed typo
    }
    
    direction := os.Args[1]
    
    db, err := sql.Open("sqlite3", "./data.db")
    if err != nil {
        log.Fatal(err)
    }
    defer db.Close()
    
    instance, err := sqlite3.WithInstance(db, &sqlite3.Config{})
    if err != nil {
        log.Fatal(err)
    }
    
    fSrc, err := (&file.File{}).Open("cmd/migrate/migrations")  // Fixed syntax
    if err != nil {
        log.Fatal(err)
    }
    
    m, err := migrate.NewWithInstance("file", fSrc, "sqlite3", instance)
    if err != nil {
        log.Fatal(err)
    }
    
    switch direction {
    case "up":
        if err := m.Up(); err != nil && err != migrate.ErrNoChange {
            log.Fatal(err)
        }
    case "down":
        if err := m.Down(); err != nil && err != migrate.ErrNoChange {
            log.Fatal(err)
        }
    default:
        log.Fatal("Invalid direction. Use 'up' or 'down'")
    }
}

```

Then using Migrate to create the files/tables
```
 migrate create -ext sql -dir ./cmd/
migrate/migrations -seq create_attendees_table

```

