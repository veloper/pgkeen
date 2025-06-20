Chapter 44. PL/Python — Python Procedural Language  
---  
[Prev](https://www.postgresql.org/docs/plperl-under-the-hood.html "43.8. PL/Perl Under the Hood") | [Up](https://www.postgresql.org/docs/server-programming.html "Part V. Server Programming") | Part V. Server Programming | [Home](https://www.postgresql.org/docs/index.html "PostgreSQL 17.4 Documentation") |  [Next](https://www.postgresql.org/docs/plpython-funcs.html "44.1. PL/Python Functions")  
  
* * *

## Chapter 44. PL/Python — Python Procedural Language

**Table of Contents**

[44.1. PL/Python Functions](https://www.postgresql.org/docs/plpython-
funcs.html)

[44.2. Data Values](https://www.postgresql.org/docs/plpython-data.html)

    

[44.2.1. Data Type Mapping](https://www.postgresql.org/docs/plpython-
data.html#PLPYTHON-DATA-TYPE-MAPPING)

[44.2.2. Null, None](https://www.postgresql.org/docs/plpython-
data.html#PLPYTHON-DATA-NULL)

[44.2.3. Arrays, Lists](https://www.postgresql.org/docs/plpython-
data.html#PLPYTHON-ARRAYS)

[44.2.4. Composite Types](https://www.postgresql.org/docs/plpython-
data.html#PLPYTHON-DATA-COMPOSITE-TYPES)

[44.2.5. Set-Returning Functions](https://www.postgresql.org/docs/plpython-
data.html#PLPYTHON-DATA-SET-RETURNING-FUNCS)

[44.3. Sharing Data](https://www.postgresql.org/docs/plpython-sharing.html)

[44.4. Anonymous Code Blocks](https://www.postgresql.org/docs/plpython-
do.html)

[44.5. Trigger Functions](https://www.postgresql.org/docs/plpython-
trigger.html)

[44.6. Database Access](https://www.postgresql.org/docs/plpython-
database.html)

    

[44.6.1. Database Access Functions](https://www.postgresql.org/docs/plpython-
database.html#PLPYTHON-DATABASE-ACCESS-FUNCS)

[44.6.2. Trapping Errors](https://www.postgresql.org/docs/plpython-
database.html#PLPYTHON-TRAPPING)

[44.7. Explicit Subtransactions](https://www.postgresql.org/docs/plpython-
subtransaction.html)

    

[44.7.1. Subtransaction Context
Managers](https://www.postgresql.org/docs/plpython-
subtransaction.html#PLPYTHON-SUBTRANSACTION-CONTEXT-MANAGERS)

[44.8. Transaction Management](https://www.postgresql.org/docs/plpython-
transactions.html)

[44.9. Utility Functions](https://www.postgresql.org/docs/plpython-util.html)

[44.10. Python 2 vs. Python 3](https://www.postgresql.org/docs/plpython-
python23.html)

[44.11. Environment Variables](https://www.postgresql.org/docs/plpython-
envar.html)

The PL/Python procedural language allows PostgreSQL functions and procedures
to be written in the [Python language](https://www.python.org).

To install PL/Python in a particular database, use `CREATE EXTENSION
plpython3u`.

### Tip

If a language is installed into `template1`, all subsequently created
databases will have the language installed automatically.

PL/Python is only available as an “untrusted” language, meaning it does not
offer any way of restricting what users can do in it and is therefore named
`plpython3u`. A trusted variant `plpython` might become available in the
future if a secure execution mechanism is developed in Python. The writer of a
function in untrusted PL/Python must take care that the function cannot be
used to do anything unwanted, since it will be able to do anything that could
be done by a user logged in as the database administrator. Only superusers can
create functions in untrusted languages such as `plpython3u`.

### Note

Users of source packages must specially enable the build of PL/Python during
the installation process. (Refer to the installation instructions for more
information.) Users of binary packages might find PL/Python in a separate
subpackage.

* * *

[Prev](https://www.postgresql.org/docs/plperl-under-the-hood.html "43.8. PL/Perl Under the Hood") | [Up](https://www.postgresql.org/docs/server-programming.html "Part V. Server Programming") |  [Next](https://www.postgresql.org/docs/plpython-funcs.html "44.1. PL/Python Functions")  
---|---|---  
43.8. PL/Perl Under the Hood  | [Home](https://www.postgresql.org/docs/index.html "PostgreSQL 17.4 Documentation") |  44.1. PL/Python Functions

