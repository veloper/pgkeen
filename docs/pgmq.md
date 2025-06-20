# Postgres Message Queue (PGMQ)

A lightweight message queue. Like [AWS SQS](https://aws.amazon.com/sqs/) and
[RSMQ](https://github.com/smrchy/rsmq) but on Postgres.

[![Tembo Cloud Try
Free](https://camo.githubusercontent.com/6f93fcf7720687518cc3867ba134167383cac65f015dd33d5764b7c3ebcc8327/68747470733a2f2f74656d626f2e696f2f74727946726565427574746f6e2e737667)](https://cloud.tembo.io/sign-
up)

[![Static
Badge](https://camo.githubusercontent.com/3bd41ea9a83c55b21bc2c818e9d2c6fa5f85199497bfbc472183c8e050aa438f/68747470733a2f2f696d672e736869656c64732e696f2f62616467652f25343074656d626f2d636f6d6d756e6974793f6c6f676f3d736c61636b266c6162656c3d736c61636b)](https://join.slack.com/t/tembocommunity/shared_invite/zt-293gc1k0k-3K8z~eKW1SEIfrqEI~5_yw)
[![OSSRank](https://camo.githubusercontent.com/6614312452bcfc810c885157d97e197fe39bbcf10c7a0746049072b9e736b743/68747470733a2f2f736869656c64732e696f2f656e64706f696e743f75726c3d68747470733a2f2f6f737372616e6b2e636f6d2f736869656c642f33383039)](https://ossrank.com/p/3809)
[![PGXN
version](https://camo.githubusercontent.com/10c5359a5d2b810e2f7948edacf05da2f64664899fd41f55a80af35d6aed8ae9/68747470733a2f2f62616467652e667572792e696f2f70672f70676d712e737667)](https://pgxn.org/dist/pgmq/)

**Documentation** : <https://tembo.io/pgmq/>

**Source** : <https://github.com/tembo-io/pgmq>

## Features

  * Lightweight - No background worker or external dependencies, just Postgres functions packaged in an extension
  * Guaranteed "exactly once" delivery of messages to a consumer within a visibility timeout
  * API parity with [AWS SQS](https://aws.amazon.com/sqs/) and [RSMQ](https://github.com/smrchy/rsmq)
  * Messages stay in the queue until explicitly removed
  * Messages can be archived, instead of deleted, for long-term retention and replayability

Supported on Postgres 14-17.

## Table of Contents

  * Postgres Message Queue (PGMQ)
    * Features
    * Table of Contents
    * Installation
      * Updating
    * Client Libraries
    * SQL Examples
      * Creating a queue
      * Send two messages
      * Read messages
      * Pop a message
      * Archive a message
      * Delete a message
      * Drop a queue
    * Configuration
      * Partitioned Queues
    * Visibility Timeout (vt)
    * Who uses pgmq?
    * ✨ Contributors

## Installation

The fastest way to get started is by running the Tembo Docker image, where
PGMQ comes pre-installed in Postgres.

    
    
    docker run -d --name pgmq-postgres -e POSTGRES_PASSWORD=postgres -p 5432:5432 tembo.docker.scarf.sh/tembo/pg17-pgmq:latest

If you'd like to build from source, you can follow the instructions in
[CONTRIBUTING.md](https://github.com/tembo-io/pgmq/blob/main/CONTRIBUTING.md).

### Updating

To update PGMQ versions, follow the instructions in
[UPDATING.md](https://github.com/tembo-io/pgmq/blob/main/pgmq-
extension/UPDATING.md).

## Client Libraries

  * [Rust](https://github.com/tembo-io/pgmq/tree/main/pgmq-rs)
  * [Python (only for psycopg3)](https://github.com/tembo-io/pgmq/tree/main/tembo-pgmq-python)

Community

  * [Dart](https://github.com/Ofceab-Studio/dart_pgmq)
  * [Go](https://github.com/craigpastro/pgmq-go)
  * [Elixir](https://github.com/v0idpwn/pgmq-elixir)
  * [Elixir + Broadway](https://github.com/v0idpwn/off_broadway_pgmq)
  * [Java (Spring Boot)](https://github.com/adamalexandru4/pgmq-spring)
  * [Kotlin JVM (JDBC)](https://github.com/vdsirotkin/pgmq-kotlin-jvm)
  * [Javascript (NodeJs)](https://github.com/Muhammad-Magdi/pgmq-js)
  * [TypeScript (NodeJs](https://github.com/waitingsong/pgmq-js/tree/main/packages/pgmq-js) \+ [Midway.js](https://midwayjs.org/))
  * [TypeScript (Deno)](https://github.com/tmountain/deno-pgmq)
  * [.NET](https://github.com/brianpursley/Npgmq)
  * [Python (with SQLAlchemy)](https://github.com/jason810496/pgmq-sqlalchemy)

## SQL Examples

    
    
    # Connect to Postgres
    psql postgres://postgres:postgres@0.0.0.0:5432/postgres
    
    
    -- create the extension in the "pgmq" schema
    CREATE EXTENSION pgmq;

### Creating a queue

Every queue is its own table in the `pgmq` schema. The table name is the queue
name prefixed with `q_`. For example, `pgmq.q_my_queue` is the table for the
queue `my_queue`.

    
    
    -- creates the queue
    SELECT pgmq.create('my_queue');
    
    
     create
    -------------
    
    (1 row)
    

### Send two messages

    
    
    -- messages are sent as JSON
    SELECT * from pgmq.send(
      queue_name  => 'my_queue',
      msg         => '{"foo": "bar1"}'
    );

The message id is returned from the send function.

    
    
     send
    -----------
             1
    (1 row)
    
    
    
    -- Optionally provide a delay
    -- this message will be on the queue but unable to be consumed for 5 seconds
    SELECT * from pgmq.send(
      queue_name => 'my_queue',
      msg        => '{"foo": "bar2"}',
      delay      => 5
    );
    
    
     send
    -----------
             2
    (1 row)
    

### Read messages

Read `2` message from the queue. Make them invisible for `30` seconds. If the
messages are not deleted or archived within 30 seconds, they will become
visible again and can be read by another consumer.

    
    
    SELECT * FROM pgmq.read(
      queue_name => 'my_queue',
      vt         => 30,
      qty        => 2
    );
    
    
     msg_id | read_ct |          enqueued_at          |              vt               |     message
    --------+---------+-------------------------------+-------------------------------+-----------------
          1 |       1 | 2023-08-16 08:37:54.567283-05 | 2023-08-16 08:38:29.989841-05 | {"foo": "bar1"}
          2 |       1 | 2023-08-16 08:37:54.572933-05 | 2023-08-16 08:38:29.989841-05 | {"foo": "bar2"}
    

If the queue is empty, or if all messages are currently invisible, no rows
will be returned.

    
    
    SELECT * FROM pgmq.read(
      queue_name => 'my_queue',
      vt         => 30,
      qty        => 1
    );
    
    
     msg_id | read_ct | enqueued_at | vt | message
    --------+---------+-------------+----+---------
    

### Pop a message

    
    
    -- Read a message and immediately delete it from the queue. Returns an empty record if the queue is empty or all messages are invisible.
    SELECT * FROM pgmq.pop('my_queue');
    
    
     msg_id | read_ct |          enqueued_at          |              vt               |     message
    --------+---------+-------------------------------+-------------------------------+-----------------
          1 |       1 | 2023-08-16 08:37:54.567283-05 | 2023-08-16 08:38:29.989841-05 | {"foo": "bar1"}
    

### Archive a message

Archiving a message removes it from the queue and inserts it to the archive
table.

    
    
    -- Archive message with msg_id=2.
    SELECT pgmq.archive(
      queue_name => 'my_queue',
      msg_id     => 2
    );
    
    
     archive
    --------------
     t
    (1 row)
    

Or archive several messages in one operation using `msg_ids` (plural)
parameter:

First, send a batch of messages

    
    
    SELECT pgmq.send_batch(
      queue_name => 'my_queue',
      msgs       => ARRAY['{"foo": "bar3"}','{"foo": "bar4"}','{"foo": "bar5"}']::jsonb[]
    );
    
    
     send_batch 
    ------------
              3
              4
              5
    (3 rows)
    

Then archive them by using the msg_ids (plural) parameter.

    
    
    SELECT pgmq.archive(
      queue_name => 'my_queue',
      msg_ids    => ARRAY[3, 4, 5]
    );
    
    
     archive 
    ---------
           3
           4
           5
    (3 rows)
    

Archive tables can be inspected directly with SQL. Archive tables have the
prefix `a_` in the `pgmq` schema.

    
    
    SELECT * FROM pgmq.a_my_queue;
    
    
     msg_id | read_ct |          enqueued_at          |          archived_at          |              vt               |     message     
    --------+---------+-------------------------------+-------------------------------+-------------------------------+-----------------
          2 |       0 | 2024-08-06 16:03:41.531556+00 | 2024-08-06 16:03:52.811063+00 | 2024-08-06 16:03:46.532246+00 | {"foo": "bar2"}
          3 |       0 | 2024-08-06 16:03:58.586444+00 | 2024-08-06 16:04:02.85799+00  | 2024-08-06 16:03:58.587272+00 | {"foo": "bar3"}
          4 |       0 | 2024-08-06 16:03:58.586444+00 | 2024-08-06 16:04:02.85799+00  | 2024-08-06 16:03:58.587508+00 | {"foo": "bar4"}
          5 |       0 | 2024-08-06 16:03:58.586444+00 | 2024-08-06 16:04:02.85799+00  | 2024-08-06 16:03:58.587543+00 | {"foo": "bar5"}
    

### Delete a message

Send another message, so that we can delete it.

    
    
    SELECT pgmq.send('my_queue', '{"foo": "bar6"}');
    
    
     send
    -----------
            6
    (1 row)
    

Delete the message with id `6` from the queue named `my_queue`.

    
    
    SELECT pgmq.delete('my_queue', 6);
    
    
     delete
    -------------
     t
    (1 row)
    

### Drop a queue

Delete the queue `my_queue`.

    
    
    SELECT pgmq.drop_queue('my_queue');
    
    
     drop_queue
    -----------------
     t
    (1 row)
    

## Configuration

### Partitioned Queues

You will need to install
[pg_partman](https://github.com/pgpartman/pg_partman/) if you want to use
`pgmq` partitioned queues.

`pgmq` queue tables can be created as a partitioned table by using
`pgmq.create_partitioned()`.
[pg_partman](https://github.com/pgpartman/pg_partman/) handles all maintenance
of queue tables. This includes creating new partitions and dropping old
partitions.

Partitions behavior is configured at the time queues are created, via
`pgmq.create_partitioned()`. This function has three parameters:

`queue_name: text`: The name of the queue. Queues are Postgres tables
prepended with `q_`. For example, `q_my_queue`. The archive is instead
prefixed by `a_`, for example `a_my_queue`.

`partition_interval: text` \- The interval at which partitions are created.
This can be either any valid Postgres `Duration` supported by pg_partman, or
an integer value. When it is a duration, queues are partitioned by the time at
which messages are sent to the table (`enqueued_at`). A value of `'daily'`
would create a new partition each day. When it is an integer value, queues are
partitioned by the `msg_id`. A value of `'100'` will create a new partition
every 100 messages. The value must agree with `retention_interval` (time based
or numeric). The default value is `daily`. For archive table, when interval is
an integer value, then it will be partitioned by `msg_id`. In case of duration
it will be partitioned on `archived_at` unlike queue table.

`retention_interval: text` \- The interval for retaining partitions. This can
be either any valid Postgres `Duration` supported by pg_partman, or an integer
value. When it is a duration, partitions containing data greater than the
duration will be dropped. When it is an integer value, any messages that have
a `msg_id` less than `max(msg_id) - retention_interval` will be dropped. For
example, if the max `msg_id` is 100 and the `retention_interval` is 60, any
partitions with `msg_id` values less than 40 will be dropped. The value must
agree with `partition_interval` (time based or numeric). The default is `'5
days'`. Note: `retention_interval` does not apply to messages that have been
deleted via `pgmq.delete()` or archived with `pgmq.archive()`. `pgmq.delete()`
removes messages forever and `pgmq.archive()` moves messages to the
corresponding archive table forever (for example, `a_my_queue`).

In order for automatic partition maintenance to take place, several settings
must be added to the `postgresql.conf` file, which is typically located in the
postgres `DATADIR`. `pg_partman_bgw.interval` in `postgresql.conf`. Below are
the default configuration values set in Tembo docker images.

Add the following to `postgresql.conf`. Note, changing
`shared_preload_libraries` requires a restart of Postgres.

`pg_partman_bgw.interval` sets the interval at which `pg_partman` conducts
maintenance. This creates new partitions and dropping of partitions falling
out of the `retention_interval`. By default, `pg_partman` will keep 4
partitions "ahead" of the currently active partition.

    
    
    shared_preload_libraries = 'pg_partman_bgw' # requires restart of Postgres
    pg_partman_bgw.interval = 60
    pg_partman_bgw.role = 'postgres'
    pg_partman_bgw.dbname = 'postgres'
    

## Visibility Timeout (vt)

pgmq guarantees exactly once delivery of a message within a visibility
timeout. The visibility timeout is the amount of time a message is invisible
to other consumers after it has been read by a consumer. If the message is NOT
deleted or archived within the visibility timeout, it will become visible
again and can be read by another consumer. The visibility timeout is set when
a message is read from the queue, via `pgmq.read()`. It is recommended to set
a `vt` value that is greater than the expected time it takes to process a
message. After the application successfully processes the message, it should
call `pgmq.delete()` to completely remove the message from the queue or
`pgmq.archive()` to move it to the archive table for the queue.

## Who uses pgmq?

As the pgmq community grows, we'd love to see who is using it. Please send a
PR with your company name and @githubhandle.

Currently, officially using pgmq:

  1. [Tembo](https://tembo.io) [[@ChuckHend](https://github.com/ChuckHend)]
  2. [Supabase](https://supabase.com) [[@Supabase](https://github.com/supabase)]
  3. [Sprinters](https://sprinters.sh) [[@sprinters-sh](https://github.com/sprinters-sh)]

## ✨ Contributors

Thanks goes to these incredible people:

[
![](https://camo.githubusercontent.com/89fdd4ddb8e1c2077cfbc3fa52755f2e37a5321046d8109900909151a8c97c30/68747470733a2f2f636f6e747269622e726f636b732f696d6167653f7265706f3d74656d626f2d696f2f70676d71)
](https://github.com/tembo-io/pgmq/graphs/contributors)

