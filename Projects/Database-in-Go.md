# Build a Database from Scratch in Go: A Hands-On Guide

*Project:****kvdb****, a persistent, crash-safe key-value store built on an LSM-tree design*

## 1. Why this project

A key-value store is the smallest thing that still forces you to confront every hard problem real databases solve: durability, crash recovery, on-disk formats, concurrency, and background maintenance. SQL, query planners and transactions sit on top of exactly this layer. LevelDB, RocksDB, Pebble (used by CockroachDB) and BadgerDB are all LSM-tree stores, and Pebble and Badger are written in Go, so you can read production code afterward.

By the end you will have:

- A **write-ahead log (WAL)** with checksums and torn-write recovery
- An in-memory **memtable** that absorbs writes
- Immutable, sorted **SSTable** files on disk
- **Tombstones** for deletes
- **Compaction** to reclaim space
- A tiny **TCP server**
- A **model-based randomized test** that catches the bugs unit tests miss

## 2. The architecture in one picture

```sql
Put(k,v) --> [1] append to WAL + fsync   (durability)
         --> [2] insert into memtable     (fast, sorted in memory)
                    memtable gets big
             [3] flush to SSTable file (sorted, immutable)
                    too many files
             [4] compaction merges SSTables

Get(k) --> memtable --> newest SSTable --> ... --> oldest SSTable
```

**The core idea:** never modify data in place. Append to a log, keep recent data in memory, and periodically write sorted immutable files. Sequential writes are fast and recovery is simple, because immutable files cannot be half-updated.

**The rule that makes it correct:** a write is acknowledged only after it is on disk in the WAL. Everything else is an optimization that can be rebuilt from the WAL after a crash.

## 3. Setup

```bash
mkdir kvdb && cd kvdb
go mod init example.com/kvdb
mkdir -p cmd/kvdb-server
```

Package layout:

```bash
kvdb/
  wal.go          // stage 1
  memtable.go     // stage 2
  sstable.go      // stage 3
  kvdb.go         // stage 4: the DB type tying it together + compaction
  kvdb_test.go    // stage 6
  cmd/kvdb-server/main.go   // stage 5
```

Everything is in `package kvdb`. Only the standard library is needed.

## 4. Stage 1: The write-ahead log

**Concept.** Before touching anything else, append the operation to a file and force it to disk with `fsync`. If the process dies, replay the log to rebuild memory.

Each record is `[crc32 (4)][keyLen (4)][valLen (4)][op (1)][key][value]`. The checksum covers everything after it. On replay, the first record that is incomplete or fails its checksum marks the end of valid data. That is a **torn write** from a crash mid-append, and we truncate it away.

```go
// wal.go
package kvdb

import (
    "bufio"
    "encoding/binary"
    "errors"
    "hash/crc32"
    "io"
    "os"
)

const (
    opPut      byte = 1
    opDel      byte = 2
    headerSize      = 13 // crc(4) + keyLen(4) + valLen(4) + op(1)
    maxKey          = 1 << 20
    maxVal          = 1 << 26
)

type WAL struct {
    f *os.File
    w *bufio.Writer
}

func OpenWAL(path string) (*WAL, error) {
    f, err := os.OpenFile(path, os.O_CREATE|os.O_RDWR|os.O_APPEND, 0o644)
    if err != nil {
        return nil, err
    }
    return &WAL{f: f, w: bufio.NewWriter(f)}, nil
}

func (w *WAL) Append(op byte, key, val []byte) error {
    buf := make([]byte, headerSize+len(key)+len(val))
    binary.LittleEndian.PutUint32(buf[4:], uint32(len(key)))
    binary.LittleEndian.PutUint32(buf[8:], uint32(len(val)))
    buf[12] = op
    copy(buf[headerSize:], key)
    copy(buf[headerSize+len(key):], val)
    binary.LittleEndian.PutUint32(buf[0:], crc32.ChecksumIEEE(buf[4:]))

    if _, err := w.w.Write(buf); err != nil {
        return err
    }
    if err := w.w.Flush(); err != nil { // user-space buffer -> OS
        return err
    }
    return w.f.Sync() // OS page cache -> disk. This is the durability point.
}

func (w *WAL) Close() error {
    if err := w.w.Flush(); err != nil {
        return err
    }
    return w.f.Close()
}

// ReplayWAL calls apply for every valid record and returns how many bytes
// were valid, so the caller can truncate any torn tail.
func ReplayWAL(path string, apply func(op byte, k, v []byte)) (int64, error) {
    f, err := os.Open(path)
    if errors.Is(err, os.ErrNotExist) {
        return 0, nil
    }
    if err != nil {
        return 0, err
    }
    defer f.Close()

    r := bufio.NewReader(f)
    hdr := make([]byte, headerSize)
    var valid int64
    for {
        if _, err := io.ReadFull(r, hdr); err != nil {
            return valid, nil // clean EOF or torn header
        }
        kl := binary.LittleEndian.Uint32(hdr[4:])
        vl := binary.LittleEndian.Uint32(hdr[8:])
        if kl > maxKey || vl > maxVal { // garbage lengths: don't allocate them
            return valid, nil
        }
        body := make([]byte, kl+vl)
        if _, err := io.ReadFull(r, body); err != nil {
            return valid, nil // torn body
        }
        h := crc32.NewIEEE()
        h.Write(hdr[4:])
        h.Write(body)
        if h.Sum32() != binary.LittleEndian.Uint32(hdr[0:]) {
            return valid, nil // corrupt record
        }
        apply(hdr[12], body[:kl], body[kl:])
        valid += int64(headerSize) + int64(len(body))
    }
}
```

**What the pros do that you just did:**

- Checksum every record, because disks and crashes corrupt data.
- Validate lengths *before* allocating. A corrupt length field should not cause a 4 GB allocation.
- `Flush()` and `Sync()` are different. `Flush` moves bytes to the OS; only `Sync` makes them survive power loss.

**Try it:** write a 10-line test that appends three records, then replays and prints them. Then append garbage bytes to the file and confirm replay still returns exactly three records.

## 5. Stage 2: The memtable

**Concept.** Recent writes live in memory so reads are fast and so we can write them to disk in sorted order later. A deleted key is stored as a **tombstone**, a marker saying "this key is deleted". You cannot just remove it, because older SSTables may still contain the key.

We use a plain map and sort at flush time. Production engines use a skip list so the data stays sorted and supports concurrent readers; that is a good upgrade later.

```go
// memtable.go
package kvdb

import "sort"

type kv struct {
    key  string
    val  []byte
    tomb bool
}

type memtable struct {
    m    map[string]kv
    size int // approximate bytes
}

func newMemtable() *memtable { return &memtable{m: map[string]kv{}} }

func (t *memtable) put(e kv) {
    if old, ok := t.m[e.key]; ok {
        t.size -= len(old.key) + len(old.val)
    }
    t.m[e.key] = e
    t.size += len(e.key) + len(e.val)
}

func (t *memtable) sorted() []kv {
    out := make([]kv, 0, len(t.m))
    for _, e := range t.m {
        out = append(out, e)
    }
    sort.Slice(out, func(i, j int) bool { return out[i].key < out[j].key })
    return out
}
```

## 6. Stage 3: SSTables

**Concept.** An SSTable (sorted string table) is an immutable file of key-value records sorted by key, followed by an index and a footer.

```
[record][record][record]...[index entries][footer]
record = keyLen(4) valLen(4) tomb(1) key value
index  = keyLen(4) offset(8) key           (one per record)
footer = indexStart(8) count(8) magic(4)
```

The footer is at a fixed position from the end, so the reader can always find the index. The magic number lets us reject files that are not SSTables.

Two habits that matter here:

1. **Write to a temp file, fsync, then `rename`.** Rename is atomic on POSIX filesystems, so readers never see a half-written SSTable.
2. **fsync the directory** after the rename so the new directory entry itself is durable.

```go
// sstable.go
package kvdb

import (
    "bufio"
    "encoding/binary"
    "fmt"
    "io"
    "os"
    "path/filepath"
    "sort"
    "strconv"
    "strings"
)

const (
    sstMagic  uint32 = 0x4b565342 // "KVSB"
    footerLen        = 20
    recHdrLen        = 9
)

func sstPath(dir string, seq uint64) string {
    return filepath.Join(dir, fmt.Sprintf("%06d.sst", seq))
}

func syncDir(dir string) error {
    d, err := os.Open(dir)
    if err != nil {
        return err
    }
    defer d.Close()
    return d.Sync()
}

func writeSSTable(path string, entries []kv) error {
    tmp := path + ".tmp"
    f, err := os.Create(tmp)
    if err != nil {
        return err
    }
    w := bufio.NewWriter(f)

    offsets := make([]uint64, len(entries))
    var off uint64
    for i, e := range entries {
        offsets[i] = off
        var h [recHdrLen]byte
        binary.LittleEndian.PutUint32(h[0:], uint32(len(e.key)))
        binary.LittleEndian.PutUint32(h[4:], uint32(len(e.val)))
        if e.tomb {
            h[8] = 1
        }
        w.Write(h[:])
        w.WriteString(e.key)
        w.Write(e.val)
        off += uint64(recHdrLen + len(e.key) + len(e.val))
    }
    indexStart := off
    for i, e := range entries {
        var b [12]byte
        binary.LittleEndian.PutUint32(b[0:], uint32(len(e.key)))
        binary.LittleEndian.PutUint64(b[4:], offsets[i])
        w.Write(b[:])
        w.WriteString(e.key)
    }
    var foot [footerLen]byte
    binary.LittleEndian.PutUint64(foot[0:], indexStart)
    binary.LittleEndian.PutUint64(foot[8:], uint64(len(entries)))
    binary.LittleEndian.PutUint32(foot[16:], sstMagic)
    w.Write(foot[:])

    if err := w.Flush(); err != nil {
        f.Close()
        return err
    }
    if err := f.Sync(); err != nil {
        f.Close()
        return err
    }
    if err := f.Close(); err != nil {
        return err
    }
    if err := os.Rename(tmp, path); err != nil {
        return err
    }
    return syncDir(filepath.Dir(path))
}

type sstable struct {
    f    *os.File
    path string
    seq  uint64
    keys []string // full index in memory (simple; see roadmap for sparse index)
    offs []uint64
}

func openSSTable(path string) (*sstable, error) {
    seq, err := strconv.ParseUint(strings.TrimSuffix(filepath.Base(path), ".sst"), 10, 64)
    if err != nil {
        return nil, fmt.Errorf("bad sstable name %q", path)
    }
    f, err := os.Open(path)
    if err != nil {
        return nil, err
    }
    st, err := f.Stat()
    if err != nil || st.Size() < footerLen {
        f.Close()
        return nil, fmt.Errorf("sstable %s too small or unreadable", path)
    }
    var foot [footerLen]byte
    if _, err := f.ReadAt(foot[:], st.Size()-footerLen); err != nil {
        f.Close()
        return nil, err
    }
    if binary.LittleEndian.Uint32(foot[16:]) != sstMagic {
        f.Close()
        return nil, fmt.Errorf("sstable %s: bad magic", path)
    }
    indexStart := binary.LittleEndian.Uint64(foot[0:])
    n := binary.LittleEndian.Uint64(foot[8:])

    t := &sstable{f: f, path: path, seq: seq}
    r := bufio.NewReader(io.NewSectionReader(f, int64(indexStart), st.Size()-footerLen-int64(indexStart)))
    for i := uint64(0); i < n; i++ {
        var b [12]byte
        if _, err := io.ReadFull(r, b[:]); err != nil {
            f.Close()
            return nil, err
        }
        kb := make([]byte, binary.LittleEndian.Uint32(b[0:]))
        if _, err := io.ReadFull(r, kb); err != nil {
            f.Close()
            return nil, err
        }
        t.keys = append(t.keys, string(kb))
        t.offs = append(t.offs, binary.LittleEndian.Uint64(b[4:]))
    }
    return t, nil
}

func (s *sstable) readAt(i int) (kv, error) {
    var h [recHdrLen]byte
    if _, err := s.f.ReadAt(h[:], int64(s.offs[i])); err != nil {
        return kv{}, err
    }
    kl := binary.LittleEndian.Uint32(h[0:])
    vl := binary.LittleEndian.Uint32(h[4:])
    val := make([]byte, vl)
    if vl > 0 {
        if _, err := s.f.ReadAt(val, int64(s.offs[i])+recHdrLen+int64(kl)); err != nil {
            return kv{}, err
        }
    }
    return kv{key: s.keys[i], val: val, tomb: h[8] == 1}, nil
}

func (s *sstable) get(key string) (kv, bool, error) {
    i := sort.SearchStrings(s.keys, key) // binary search
    if i == len(s.keys) || s.keys[i] != key {
        return kv{}, false, nil
    }
    e, err := s.readAt(i)
    return e, err == nil, err
}
```

## 7. Stage 4: The DB type, flush, and compaction

**Concept.** This is the conductor. On `Open`, load the SSTables, then replay the WAL into a fresh memtable. On write: WAL first, then memtable. When the memtable is big, flush it.

**The ordering that matters most in `flush`:** the SSTable must be fully durable *before* the WAL is discarded. If we crash between the two, the WAL replays records that are already in the SSTable. That is harmless, because replaying a put twice gives the same result. Writes are **idempotent**, which is what makes crash recovery simple.

```go
// kvdb.go
package kvdb

import (
    "errors"
    "fmt"
    "os"
    "path/filepath"
    "sort"
    "sync"
)

var ErrNotFound = errors.New("kvdb: key not found")

type Options struct {
    MemtableBytes int // flush threshold; default 4 MiB
}

type DB struct {
    mu      sync.RWMutex
    dir     string
    opts    Options
    wal     *WAL
    mem     *memtable
    tables  []*sstable // oldest -> newest
    nextSeq uint64
}

func Open(dir string, opts Options) (*DB, error) {
    if opts.MemtableBytes == 0 {
        opts.MemtableBytes = 4 << 20
    }
    if err := os.MkdirAll(dir, 0o755); err != nil {
        return nil, err
    }
    db := &DB{dir: dir, opts: opts, mem: newMemtable()}

    paths, err := filepath.Glob(filepath.Join(dir, "*.sst"))
    if err != nil {
        return nil, err
    }
    sort.Strings(paths) // zero-padded names sort by sequence number
    for _, p := range paths {
        t, err := openSSTable(p)
        if err != nil {
            return nil, fmt.Errorf("open %s: %w", p, err)
        }
        db.tables = append(db.tables, t)
        db.nextSeq = t.seq + 1
    }

    walPath := filepath.Join(dir, "wal.log")
    valid, err := ReplayWAL(walPath, func(op byte, k, v []byte) {
        db.mem.put(kv{key: string(k), val: append([]byte(nil), v...), tomb: op == opDel})
    })
    if err != nil {
        return nil, err
    }
    if err := os.Truncate(walPath, valid); err != nil && !errors.Is(err, os.ErrNotExist) {
        return nil, err // drop the torn tail
    }
    if db.wal, err = OpenWAL(walPath); err != nil {
        return nil, err
    }
    return db, nil
}

func (db *DB) write(op byte, key string, val []byte) error {
    db.mu.Lock()
    defer db.mu.Unlock()
    if err := db.wal.Append(op, []byte(key), val); err != nil {
        return err // not durable => do NOT apply to memory or acknowledge
    }
    db.mem.put(kv{key: key, val: append([]byte(nil), val...), tomb: op == opDel})
    if db.mem.size >= db.opts.MemtableBytes {
        return db.flush()
    }
    return nil
}

func (db *DB) Put(k string, v []byte) error { return db.write(opPut, k, v) }
func (db *DB) Delete(k string) error        { return db.write(opDel, k, nil) }

func (db *DB) Get(key string) ([]byte, error) {
    db.mu.RLock()
    defer db.mu.RUnlock()
    if e, ok := db.mem.m[key]; ok {
        return result(e)
    }
    for i := len(db.tables) - 1; i >= 0; i-- { // newest wins
        e, ok, err := db.tables[i].get(key)
        if err != nil {
            return nil, err
        }
        if ok {
            return result(e)
        }
    }
    return nil, ErrNotFound
}

func result(e kv) ([]byte, error) {
    if e.tomb {
        return nil, ErrNotFound
    }
    return e.val, nil
}

// flush: caller holds db.mu.
func (db *DB) flush() error {
    if len(db.mem.m) == 0 {
        return nil
    }
    path := sstPath(db.dir, db.nextSeq)
    if err := writeSSTable(path, db.mem.sorted()); err != nil {
        return err
    }
    t, err := openSSTable(path)
    if err != nil {
        return err
    }
    // The SSTable is durable. Only now is it safe to discard the WAL.
    if err := db.wal.Close(); err != nil {
        return err
    }
    walPath := filepath.Join(db.dir, "wal.log")
    if err := os.Truncate(walPath, 0); err != nil {
        return err
    }
    if db.wal, err = OpenWAL(walPath); err != nil {
        return err
    }
    db.nextSeq++
    db.tables = append(db.tables, t)
    db.mem = newMemtable()
    return nil
}

// Compact merges all SSTables into one. Newer entries override older ones.
func (db *DB) Compact() error {
    db.mu.Lock()
    defer db.mu.Unlock()
    if len(db.tables) < 2 {
        return nil
    }
    merged := map[string]kv{}
    for _, t := range db.tables { // oldest -> newest, so later overwrites earlier
        for i := range t.keys {
            e, err := t.readAt(i)
            if err != nil {
                return err
            }
            merged[e.key] = e
        }
    }
    out := make([]kv, 0, len(merged))
    for _, e := range merged {
        out = append(out, e) // tombstones are KEPT, see the note below
    }
    sort.Slice(out, func(i, j int) bool { return out[i].key < out[j].key })

    path := sstPath(db.dir, db.nextSeq)
    if err := writeSSTable(path, out); err != nil {
        return err
    }
    nt, err := openSSTable(path)
    if err != nil {
        return err
    }
    db.nextSeq++
    old := db.tables
    db.tables = []*sstable{nt}
    for _, t := range old {
        t.f.Close()
        os.Remove(t.path)
    }
    return syncDir(db.dir)
}

func (db *DB) Close() error {
    db.mu.Lock()
    defer db.mu.Unlock()
    err := db.wal.Close()
    for _, t := range db.tables {
        t.f.Close()
    }
    return err
}
```

**Why compaction keeps tombstones (a real subtlety).** Imagine we dropped them and crashed after writing the merged file but before deleting the old files. On restart, an old SSTable still holds the deleted key's value, and nothing newer says it was deleted, so the key comes back from the dead. Real engines solve this with a **MANIFEST** file that atomically records which SSTables are live. Adding one is your first stretch exercise.

**Known limits of this version (on purpose):** compaction holds the write lock for its whole duration, and it merges everything at once. Production engines compact in the background with leveled or tiered strategies and let readers keep using immutable file versions.

## 8. Stage 5: Put a server in front of it

A database is a process other programs talk to. Here is a minimal line protocol: `SET key value`, `GET key`, `DEL key`.

```go
// cmd/kvdb-server/main.go
package main

import (
    "bufio"
    "context"
    "errors"
    "fmt"
    "log"
    "net"
    "os"
    "os/signal"
    "strings"
    "sync"
    "syscall"

    kvdb "example.com/kvdb"
)

func main() {
    db, err := kvdb.Open("./data", kvdb.Options{})
    if err != nil {
        log.Fatal(err)
    }
    ln, err := net.Listen("tcp", "127.0.0.1:7379")
    if err != nil {
        log.Fatal(err)
    }

    ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
    defer stop()

    var wg sync.WaitGroup
    go func() {
        <-ctx.Done()
        ln.Close() // stop accepting
    }()

    for {
        c, err := ln.Accept()
        if err != nil {
            break
        }
        wg.Add(1)
        go func() {
            defer wg.Done()
            defer c.Close()
            serve(c, db)
        }()
    }
    wg.Wait() // let in-flight requests finish
    if err := db.Close(); err != nil {
        log.Printf("close: %v", err)
    }
    log.Println("shut down cleanly")
}

func serve(c net.Conn, db *kvdb.DB) {
    sc := bufio.NewScanner(c)
    for sc.Scan() {
        parts := strings.SplitN(sc.Text(), " ", 3)
        switch strings.ToUpper(parts[0]) {
        case "SET":
            if len(parts) != 3 {
                fmt.Fprintln(c, "ERR usage: SET key value")
            } else if err := db.Put(parts[1], []byte(parts[2])); err != nil {
                fmt.Fprintln(c, "ERR", err)
            } else {
                fmt.Fprintln(c, "OK")
            }
        case "GET":
            if len(parts) != 2 {
                fmt.Fprintln(c, "ERR usage: GET key")
                continue
            }
            v, err := db.Get(parts[1])
            if errors.Is(err, kvdb.ErrNotFound) {
                fmt.Fprintln(c, "NIL")
            } else if err != nil {
                fmt.Fprintln(c, "ERR", err)
            } else {
                fmt.Fprintln(c, string(v))
            }
        case "DEL":
            if len(parts) != 2 {
                fmt.Fprintln(c, "ERR usage: DEL key")
            } else if err := db.Delete(parts[1]); err != nil {
                fmt.Fprintln(c, "ERR", err)
            } else {
                fmt.Fprintln(c, "OK")
            }
        default:
            fmt.Fprintln(c, "ERR unknown command")
        }
    }
}
```

Run it with `go run ./cmd/kvdb-server`, then `nc 127.0.0.1 7379` in another terminal. Type `SET a 1`, `GET a`, then press Ctrl+C on the server and start it again. `GET a` should still return `1`.

**Crash test by hand:** run the server, `SET` a few keys, then `kill -9` it (no graceful shutdown). Restart and `GET` them. Every acknowledged write should survive, because the WAL was fsynced before `OK` was sent.

## 9. Stage 6: Test it the way database engineers do

Example-based tests are not enough for storage engines. The bugs live in interleavings: a delete, then a flush, then a reopen, then a compaction. The technique is a **model-based randomized test**. Run thousands of random operations against both your DB and a trivial in-memory `map`, and check they never disagree.

```go
// kvdb_test.go
package kvdb

import (
    "errors"
    "fmt"
    "math/rand"
    "os"
    "path/filepath"
    "testing"
)

func must(t *testing.T, err error) {
    t.Helper()
    if err != nil {
        t.Fatal(err)
    }
}

func TestModel(t *testing.T) {
    dir := t.TempDir()
    opts := Options{MemtableBytes: 256} // tiny, so flushes happen constantly
    db, err := Open(dir, opts)
    must(t, err)
    model := map[string]string{}
    rng := rand.New(rand.NewSource(1))

    for i := 0; i < 20000; i++ {
        k := fmt.Sprintf("k%03d", rng.Intn(200))
        switch rng.Intn(12) {
        case 0, 1:
            must(t, db.Delete(k))
            delete(model, k)
        case 2:
            must(t, db.Close())
            db, err = Open(dir, opts) // simulate restart
            must(t, err)
        case 3:
            must(t, db.Compact())
        default:
            v := fmt.Sprint(i)
            must(t, db.Put(k, []byte(v)))
            model[k] = v
        }
        // Check every key after every step (200 keys, cheap).
        for j := 0; j < 200; j++ {
            ck := fmt.Sprintf("k%03d", j)
            got, err := db.Get(ck)
            want, ok := model[ck]
            switch {
            case !ok && !errors.Is(err, ErrNotFound):
                t.Fatalf("step %d key %s: want not found, got %q err=%v", i, ck, got, err)
            case ok && (err != nil || string(got) != want):
                t.Fatalf("step %d key %s: want %q, got %q err=%v", i, ck, want, got, err)
            }
        }
    }
}

func TestTornWALTail(t *testing.T) {
    dir := t.TempDir()
    db, err := Open(dir, Options{})
    must(t, err)
    must(t, db.Put("a", []byte("1")))
    must(t, db.Put("b", []byte("2")))
    must(t, db.Close())

    // Simulate a crash mid-append: junk after the last good record.
    f, err := os.OpenFile(filepath.Join(dir, "wal.log"), os.O_APPEND|os.O_WRONLY, 0o644)
    must(t, err)
    f.Write([]byte{0xde, 0xad, 0xbe, 0xef, 1, 2, 3})
    f.Close()

    db, err = Open(dir, Options{})
    must(t, err)
    defer db.Close()
    if v, err := db.Get("b"); err != nil || string(v) != "2" {
        t.Fatalf("lost data after torn tail: %q %v", v, err)
    }
    must(t, db.Put("c", []byte("3"))) // and the DB must still accept writes
}
```

Run everything with the race detector, which catches locking mistakes:

```
go test -race ./...
```

Then add two more habits:

- **Fuzz the parsers.** `go test -fuzz` against `ReplayWAL` and `openSSTable` with random bytes. A parser that panics on corrupt input is a production outage waiting to happen.
- **Benchmark honestly.** Write a `BenchmarkPut` and notice that every `Put` pays for an fsync. That is the single biggest cost in the system and the reason for the first roadmap item below.

## 10. What makes this "production-ready" (and what is still missing)

What you already did that tutorials usually skip:

| Concern | Where you handled it |
| --- | --- |
| Durability | fsync the WAL before acknowledging a write |
| Crash recovery | WAL replay, torn-tail truncation, idempotent writes |
| Corruption detection | CRC per WAL record, magic number on SSTables |
| Atomic file publication | temp file, fsync, rename, fsync directory |
| Hostile or garbage input | length limits checked before allocation |
| Graceful shutdown | signal handling, drain connections, close the DB |
| Verification | model-based test, torn-write test, race detector |

What is still missing, and what to add next, roughly in order of payoff:

1. **Group commit.** Batch concurrent writers into one fsync. This gives the largest throughput gain.
2. **Write batches.** An atomic `Batch{Put, Put, Delete}` that is one WAL record (your first taste of transactions).
3. **MANIFEST file.** Atomically track which SSTables are live, then safely garbage-collect tombstones.
4. **Bloom filters** per SSTable so `Get` skips files that cannot contain the key.
5. **Sparse index plus block cache** instead of holding every key in memory. Fix the full index in `sstable` first.
6. **Skip list memtable** and an **immutable memtable** being flushed while a new one takes writes.
7. **Background compaction** with leveled strategy, so writes are not blocked.
8. **Iterators and snapshots** (`Scan(start, end)`) using sequence numbers for MVCC-style consistent reads.
9. **File format versioning**, so a future release can still read today's files.
10. **Observability:** metrics for flush count, compaction time, WAL fsync latency, and SSTable count; structured logs.

## 11. Suggested way to work through this

1. Type the code in yourself rather than pasting it, one stage at a time. Run the "Try it" check after each stage.
2. After Stage 4, run `TestModel` and then **deliberately break something**: move the WAL truncate above the SSTable write in `flush`, or drop the `Sync()` call. Observe which tests fail and which don't. The ones that don't fail show where your tests have gaps.
3. Implement roadmap items 1 to 3 before anything else. They teach the most about real database internals.
4. Read production code once you have built the toy version: Pebble and BadgerDB (both Go LSM engines), and bbolt (a Go B-tree engine, the main alternative design to LSM).

## 12. Further reading

- *Designing Data-Intensive Applications* by Martin Kleppmann, chapter 3 (storage engines: LSM-trees versus B-trees)
- The LevelDB implementation notes (the file formats and compaction design this guide is modeled on)
- The Bitcask paper (a simpler log-structured design, a good warm-up)
- CMU 15-445 Database Systems lectures (free online) for the layers above storage: buffer pools, query execution, transactions

When you finish Stage 4 and have `TestModel` passing, come back and tell me how it went. The next natural step is picking one of the roadmap items and building it together.