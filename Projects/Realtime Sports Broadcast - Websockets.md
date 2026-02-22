##### Little bit about Websockets

There are broadcast(one-to-all), unicast(one-to-one)

WebSockets for chat, video call.
WebRTC for voice, text, p2p for heavy media.
WebTransport for ultra low-latency streaming for movie streaming, and high performance systems.
SSE for one way server updates tickers, feeds.
![[websocket.png]]

## Project Journey

Project Setup :
Starting with a simple project with `npm init -y` and `express`. Making sure the server is running and adding a `gitignore` before pushing the initial scaffold to Github.

Database schema:
![[DB_schema_sportz.png]]

#### Connecting Drizzle ORM:

Creating a separate `db.js` file and adding a new connection pool

```python

import "dotenv/config";
import { drizzle } from "drizzle-orm/node-postgres";
import pg from "pg";

if (!process.env.DATABASE_URL) {
  throw new Error("DATABASE_URL is not defined");
}

export const pool = new pg.Pool({
  connectionString: process.env.DATABASE_URL,
});

export const db = drizzle(pool);

```

Then Migrating the table with `drizzle-kit migrate` to finally connect NEON (A fast Postgres Database).

#### Matches REST API

