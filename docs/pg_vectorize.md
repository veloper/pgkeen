#  **pg_vectorize: a VectorDB for Postgres**  
  
[![pg_vectorize](https://private-user-
images.githubusercontent.com/15756360/301332899-34d65cba-065b-485f-84a4-76284e9def19.png?jwt=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3NDMyODczMDUsIm5iZiI6MTc0MzI4NzAwNSwicGF0aCI6Ii8xNTc1NjM2MC8zMDEzMzI4OTktMzRkNjVjYmEtMDY1Yi00ODVmLTg0YTQtNzYyODRlOWRlZjE5LnBuZz9YLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUFWQ09EWUxTQTUzUFFLNFpBJTJGMjAyNTAzMjklMkZ1cy1lYXN0LTElMkZzMyUyRmF3czRfcmVxdWVzdCZYLUFtei1EYXRlPTIwMjUwMzI5VDIyMjMyNVomWC1BbXotRXhwaXJlcz0zMDAmWC1BbXotU2lnbmF0dXJlPWIyNWI3NjUyZTRjNmRiNjQ2ZGNjZjlkMjJlNzU2NTZlMTcwNzZkZWMyM2Q3NGRmMGYwM2RlN2UzZWI0YmNiOGImWC1BbXotU2lnbmVkSGVhZGVycz1ob3N0In0.LuBEF4D2SYPz9qSsSEtWp1j_zujODp6mIMqHZdsaFO0)](https://tembo.io)

[ ![Tembo Cloud Try
Free](https://camo.githubusercontent.com/6f93fcf7720687518cc3867ba134167383cac65f015dd33d5764b7c3ebcc8327/68747470733a2f2f74656d626f2e696f2f74727946726565427574746f6e2e737667)
](https://cloud.tembo.io/sign-up)

A Postgres extension that automates the transformation and orchestration of
text to embeddings and provides hooks into the most popular LLMs. This allows
you to do vector search and build LLM applications on existing data with as
little as two function calls.

This project relies heavily on the work by
[pgvector](https://github.com/pgvector/pgvector) for vector similarity search,
[pgmq](https://github.com/tembo-io/pgmq) for orchestration in background
workers, and [SentenceTransformers](https://huggingface.co/sentence-
transformers).

* * *

[![Static
Badge](https://camo.githubusercontent.com/3bd41ea9a83c55b21bc2c818e9d2c6fa5f85199497bfbc472183c8e050aa438f/68747470733a2f2f696d672e736869656c64732e696f2f62616467652f25343074656d626f2d636f6d6d756e6974793f6c6f676f3d736c61636b266c6162656c3d736c61636b)](https://join.slack.com/t/tembocommunity/shared_invite/zt-277pu7chi-
NHtvHWvLhHwyK0Y5Y6vTPw) [![PGXN
version](https://camo.githubusercontent.com/97d917f9abea5d56f16e0dba8eeaea887d8bb1f78a6e394a9f439e385fa18278/68747470733a2f2f62616467652e667572792e696f2f70672f766563746f72697a652e737667)](https://pgxn.org/dist/vectorize/)
[![OSSRank](https://camo.githubusercontent.com/8d64425100905ff429ef660c984b688dae1ef9275995312b6e72f4191c6bce93/68747470733a2f2f736869656c64732e696f2f656e64706f696e743f75726c3d68747470733a2f2f6f737372616e6b2e636f6d2f736869656c642f33383135)](https://ossrank.com/p/3815)

pg_vectorize powers the [VectorDB
Stack](https://tembo.io/docs/product/stacks/ai/vectordb) on [Tembo
Cloud](https://cloud.tembo.io/) and is available in all hobby tier instances.

**API Documentation** : <https://tembo.io/pg_vectorize/>

**Source** : <https://github.com/tembo-io/pg_vectorize>

## Features

  * Workflows for both vector search and RAG
  * Integrations with OpenAI's [embeddings](https://platform.openai.com/docs/guides/embeddings) and [Text-Generation](https://platform.openai.com/docs/guides/text-generation) endpoints and a self-hosted container for running [Hugging Face Sentence-Transformers](https://huggingface.co/sentence-transformers)
  * Automated creation of Postgres triggers to keep your embeddings up to date
  * High level API - one function to initialize embeddings transformations, and another function to search

## Table of Contents

  * Features
  * Table of Contents
  * Installation
  * Vector Search Example
  * RAG Example
  * Updating Embeddings
  * Directly Interact with LLMs
  * Importing Pre-existing Embeddings
  * Creating a Table from Existing Embeddings

## Installation

The fastest way to get started is by running the Tembo docker container and
the vector server with docker compose:

    
    
    docker compose up -d

Then connect to Postgres:

    
    
    docker compose exec -it postgres psql
    

Enable the extension and its dependencies

    
    
    CREATE EXTENSION vectorize CASCADE;

Install into an existing Postgres instance

If you're installing in an existing Postgres instance, you will need the
following dependencies:

Rust:

  * [pgrx toolchain](https://github.com/pgcentralfoundation/pgrx)

Postgres Extensions:

  * [pg_cron](https://github.com/citusdata/pg_cron) ^1.5
  * [pgmq](https://github.com/tembo-io/pgmq) ^1
  * [pgvector](https://github.com/pgvector/pgvector) ^0.5.0

Then set the following either in postgresql.conf or as a configuration
parameter:

    
    
    -- requires restart of Postgres
    alter system set shared_preload_libraries = 'vectorize,pg_cron';
    alter system set cron.database_name = 'postgres';

And if you're running the vector-serve container, set the following url as a
configuration parameter in Postgres. The host may need to change from
`localhost` to something else depending on where you are running the
container.

    
    
    alter system set vectorize.embedding_service_url = 'http://localhost:3000/v1';
    
    SELECT pg_reload_conf();

## Vector Search Example

Text-to-embedding transformation can be done with either Hugging Face's
Sentence-Transformers or OpenAI's embeddings. The following examples use
Hugging Face's Sentence-Transformers. See the project
[documentation](https://tembo.io/pg_vectorize/examples/openai_embeddings/) for
OpenAI examples.

Follow the installation steps if you haven't already.

Setup a products table. Copy from the example data provided by the extension.

    
    
    CREATE TABLE products (LIKE vectorize.example_products INCLUDING ALL);
    INSERT INTO products SELECT * FROM vectorize.example_products;
    
    
    SELECT * FROM products limit 2;
    
    
     product_id | product_name |                      description                       |        last_updated_at        
    ------------+--------------+--------------------------------------------------------+-------------------------------
              1 | Pencil       | Utensil used for writing and often works best on paper | 2023-07-26 17:20:43.639351-05
              2 | Laptop Stand | Elevated platform for laptops, enhancing ergonomics    | 2023-07-26 17:20:43.639351-05
    

Create a job to vectorize the products table. We'll specify the tables primary
key (product_id) and the columns that we want to search (product_name and
description).

    
    
    SELECT vectorize.table(
        job_name    => 'product_search_hf',
        relation    => 'products',
        primary_key => 'product_id',
        columns     => ARRAY['product_name', 'description'],
        transformer => 'sentence-transformers/all-MiniLM-L6-v2',
        schedule    => 'realtime'
    );

This adds a new column to your table, in our case it is named
`product_search_embeddings`, then populates that data with the transformed
embeddings from the `product_name` and `description` columns.

Then search,

    
    
    SELECT * FROM vectorize.search(
        job_name        => 'product_search_hf',
        query           => 'accessories for mobile devices',
        return_columns  => ARRAY['product_id', 'product_name'],
        num_results     => 3
    );
    
    
                                           search_results                                        
    ---------------------------------------------------------------------------------------------
     {"product_id": 13, "product_name": "Phone Charger", "similarity_score": 0.8147814132322894}
     {"product_id": 6, "product_name": "Backpack", "similarity_score": 0.7743061352550308}
     {"product_id": 11, "product_name": "Stylus Pen", "similarity_score": 0.7709902653575383}
    

## RAG Example

Ask raw text questions of the example `products` dataset and get chat
responses from an OpenAI LLM.

Follow the installation steps if you haven't already.

Set the [OpenAI API key](https://platform.openai.com/docs/guides/embeddings),
this is required to for use with OpenAI's chat-completion models.

    
    
    ALTER SYSTEM SET vectorize.openai_key TO '<your api key>';
    SELECT pg_reload_conf();

Create an example table if it does not already exist.

    
    
    CREATE TABLE products (LIKE vectorize.example_products INCLUDING ALL);
    INSERT INTO products SELECT * FROM vectorize.example_products;

Initialize a table for RAG. We'll use an open source Sentence Transformer to
generate embeddings.

Create a new column that we want to use as the context. In this case, we'll
concatenate both `product_name` and `description`.

    
    
    ALTER TABLE products
    ADD COLUMN context TEXT GENERATED ALWAYS AS (product_name || ': ' || description) STORED;

Initialize the RAG project. We'll use the `openai/text-embedding-3-small`
model to generate embeddings on our source documents.

    
    
    SELECT vectorize.table(
        job_name    => 'product_chat',
        relation    => 'products',
        primary_key => 'product_id',
        columns     => ARRAY['context'],
        transformer => 'openai/text-embedding-3-small',
        schedule    => 'realtime'
    );

Now we can ask questions of the `products` table and get responses from the
`product_chat` agent using the `openai/gpt-3.5-turbo` generative model.

    
    
    SELECT vectorize.rag(
        job_name    => 'product_chat',
        query       => 'What is a pencil?',
        chat_model  => 'openai/gpt-3.5-turbo'
    ) -> 'chat_response';
    
    
    "A pencil is an item that is commonly used for writing and is known to be most effective on paper."
    

And to use a locally hosted Ollama service, change the `chat_model` parameter:

    
    
    SELECT vectorize.rag(
        job_name    => 'product_chat',
        query       => 'What is a pencil?',
        chat_model  => 'ollama/wizardlm2:7b'
    ) -> 'chat_response';
    
    
    " A pencil is a writing instrument that consists of a solid or gelignola wood core, known as the \"lead,\" encased in a cylindrical piece of breakable material (traditionally wood or plastic), which serves as the body of the pencil. The tip of the body is tapered to a point for writing, and it can mark paper with the imprint of the lead. When used on a sheet of paper, the combination of the pencil's lead and the paper creates a visible mark that is distinct from unmarked areas of the paper. Pencils are particularly well-suited for writing on paper, as they allow for precise control over the marks made."
    

💡 Note that the `-> 'chat_response'` addition selects for that field of the
JSON object output. Removing it will show the full JSON object, including
information on which documents were included in the contextual prompt.

## Updating Embeddings

When the source text data is updated, how and when the embeddings are updated
is determined by the value set to the `schedule` parameter in
`vectorize.table`.

The default behavior is `schedule => '* * * * *'`, which means the background
worker process checks for changes every minute, and updates the embeddings
accordingly. This method requires setting the `updated_at_col` value to point
to a colum on the table indicating the time that the input text columns were
last changed. `schedule` can be set to any cron-like value.

Alternatively, `schedule => 'realtime` creates triggers on the source table
and updates embeddings anytime new records are inserted to the source table or
existing records are updated.

Statements below would will result in new embeddings being generated either
immediately (`schedule => 'realtime'`) or within the cron schedule set in the
`schedule` parameter.

    
    
    INSERT INTO products (product_id, product_name, description, product_category, price)
    VALUES (12345, 'pizza', 'dish of Italian origin consisting of a flattened disk of bread', 'food', 5.99);
    
    UPDATE products
    SET description = 'sling made of fabric, rope, or netting, suspended between two or more points, used for swinging, sleeping, or resting'
    WHERE product_name = 'Hammock';

## Directly Interact with LLMs

Sometimes you want more control over the handling of embeddings. For those
situations you can directly call various LLM providers using SQL:

For text generation:

    
    
    select vectorize.generate(
      input => 'Tell me the difference between a cat and a dog in 1 sentence',
      model => 'openai/gpt-4o'
    );
    
    
                                                     generate                                                  
    -----------------------------------------------------------------------------------------------------------
     Cats are generally more independent and solitary, while dogs tend to be more social and loyal companions.
    (1 row)
    

And for embedding generation:

    
    
    select vectorize.encode(
      input => 'Tell me the difference between a cat and a dog in 1 sentence',
      model => 'openai/text-embedding-3-large'
    );
    
    
    {0.0028769304,-0.005826319,-0.0035932811, ...}
    

## Importing Pre-existing Embeddings

If you have already computed embeddings using a compatible model (e.g., using
Sentence-Transformers directly), you can import these into pg_vectorize
without recomputation:

    
    
    -- First create the vectorize project
    SELECT vectorize.table(
        job_name    => 'my_search',
        relation    => 'my_table',
        primary_key => 'id',
        columns     => ARRAY['content'],
        transformer => 'sentence-transformers/all-MiniLM-L6-v2'
    );
    
    -- Then import your pre-computed embeddings
    SELECT vectorize.import_embeddings(
        job_name            => 'my_search',
        src_table           => 'my_embeddings_table',
        src_primary_key     => 'id',
        src_embeddings_col  => 'embedding'
    );

The embeddings must match the dimensions of the specified transformer model.
For example, 'sentence-transformers/all-MiniLM-L6-v2' expects 384-dimensional
vectors.

## Creating a Table from Existing Embeddings

If you have already computed embeddings using a compatible model, you can
create a new vectorize table directly from them:

    
    
    -- Create a vectorize table from existing embeddings
    SELECT vectorize.table_from(
        relation => 'my_table',
        columns => ARRAY['content'],
        job_name => 'my_search',
        primary_key => 'id',
        src_table => 'my_embeddings_table',
        src_primary_key => 'id',
        src_embeddings_col => 'embedding',
        transformer => 'sentence-transformers/all-MiniLM-L6-v2'
    );

The embeddings must match the dimensions of the specified transformer model.
This approach ensures your pre-computed embeddings are properly imported
before any automatic updates are enabled.

## Contributing

We welcome contributions from the community! If you're interested in
contributing to `pg_vectorize`, please check out our [Contributing
Guide](https://github.com/tembo-io/pg_vectorize/blob/main/CONTRIBUTING.md).
Your contributions help make this project better for everyone.

## Community Support

If you encounter any issues or have any questions, feel free to join our
[Tembo Community
Slack](https://join.slack.com/t/tembocommunity/shared_invite/zt-2u3ctm86u-XzcyL76T7o~7Mpnt6KUx1g).
We're here to help!

