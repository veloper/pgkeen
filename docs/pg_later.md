# pg_later

Execute SQL now and get the results later.

A postgres extension to execute queries asynchronously. Built on
[pgmq](https://github.com/tembo-io/pgmq).

[![Tembo Cloud Try
Free](https://camo.githubusercontent.com/6f93fcf7720687518cc3867ba134167383cac65f015dd33d5764b7c3ebcc8327/68747470733a2f2f74656d626f2e696f2f74727946726565427574746f6e2e737667)](https://cloud.tembo.io/sign-
up)

[![Static
Badge](https://camo.githubusercontent.com/3bd41ea9a83c55b21bc2c818e9d2c6fa5f85199497bfbc472183c8e050aa438f/68747470733a2f2f696d672e736869656c64732e696f2f62616467652f25343074656d626f2d636f6d6d756e6974793f6c6f676f3d736c61636b266c6162656c3d736c61636b)](https://join.slack.com/t/tembocommunity/shared_invite/zt-20dtnhcmo-
pLNV7_Aobi50TdTLpfQ~EQ) [![PGXN
version](https://camo.githubusercontent.com/8c2b4c50e2511b330fa439f97683c20a467c3513b8b9ecd735eabcca7fa46f6a/68747470733a2f2f62616467652e667572792e696f2f70672f70675f6c617465722e737667)](https://pgxn.org/dist/pg_later/)

## Installation

### Run with docker

    
    
    docker run -p 5432:5432 -e POSTGRES_PASSWORD=postgres quay.io/tembo/pglater-pg:latest

If you'd like to build from source, you can follow the instructions in
[CONTRIBUTING.md](https://github.com/tembo-
io/pg_later/blob/main/CONTRIBUTING.md).

### Using the extension

Initialize the extension's backend:

    
    
    CREATE EXTENSION pg_later CASCADE;
    
    SELECT pglater.init();

Execute a SQL query now:

    
    
    select pglater.exec(
      'select * from pg_available_extensions order by name limit 2'
    ) as job_id;
    
    
     job_id 
    --------
         1
    (1 row)
    

Come back at some later time, and retrieve the results by providing the job
id:

    
    
    select pglater.fetch_results(1);
    
    
     pg_later_results
    --------------------
    {
      "query": "select * from pg_available_extensions order by name limit 2",
      "job_id": 1,
      "result": [
        {
          "name": "adminpack",
          "comment": "administrative functions for PostgreSQL",
          "default_version": "2.1",
          "installed_version": null
        },
        {
          "name": "amcheck",
          "comment": "functions for verifying relation integrity",
          "default_version": "1.3",
          "installed_version": null
        }
      ],
      "status": "success"
    }
    

