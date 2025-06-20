F.12. dict_int — example full-text search dictionary for integers  
---  
[Prev](https://www.postgresql.org/docs/contrib-dblink-build-sql-update.html "dblink_build_sql_update") | [Up](https://www.postgresql.org/docs/contrib.html "Appendix F. Additional Supplied Modules and Extensions") | Appendix F. Additional Supplied Modules and Extensions | [Home](https://www.postgresql.org/docs/index.html "PostgreSQL 17.4 Documentation") |  [Next](https://www.postgresql.org/docs/dict-xsyn.html "F.13. dict_xsyn — example synonym full-text search dictionary")  
  
* * *

## F.12. dict_int — example full-text search dictionary for integers #

[F.12.1. Configuration](https://www.postgresql.org/docs/dict-int.html#DICT-
INT-CONFIG)

[F.12.2. Usage](https://www.postgresql.org/docs/dict-int.html#DICT-INT-USAGE)

`dict_int` is an example of an add-on dictionary template for full-text
search. The motivation for this example dictionary is to control the indexing
of integers (signed and unsigned), allowing such numbers to be indexed while
preventing excessive growth in the number of unique words, which greatly
affects the performance of searching.

This module is considered “trusted”, that is, it can be installed by non-
superusers who have `CREATE` privilege on the current database.

### F.12.1. Configuration #

The dictionary accepts three options:

  * The `maxlen` parameter specifies the maximum number of digits allowed in an integer word. The default value is 6.

  * The `rejectlong` parameter specifies whether an overlength integer should be truncated or ignored. If `rejectlong` is `false` (the default), the dictionary returns the first `maxlen` digits of the integer. If `rejectlong` is `true`, the dictionary treats an overlength integer as a stop word, so that it will not be indexed. Note that this also means that such an integer cannot be searched for.

  * The `absval` parameter specifies whether leading “`+`” or “`-`” signs should be removed from integer words. The default is `false`. When `true`, the sign is removed before `maxlen` is applied.

### F.12.2. Usage #

Installing the `dict_int` extension creates a text search template
`intdict_template` and a dictionary `intdict` based on it, with the default
parameters. You can alter the parameters, for example

    
    
    mydb# ALTER TEXT SEARCH DICTIONARY intdict (MAXLEN = 4, REJECTLONG = true);
    ALTER TEXT SEARCH DICTIONARY
    

or create new dictionaries based on the template.

To test the dictionary, you can try

    
    
    mydb# select ts_lexize('intdict', '12345678');
     ts_lexize
    -----------
     {123456}
    

but real-world usage will involve including it in a text search configuration
as described in [Chapter 12](https://www.postgresql.org/docs/textsearch.html
"Chapter 12. Full Text Search"). That might look like this:

    
    
    ALTER TEXT SEARCH CONFIGURATION english
        ALTER MAPPING FOR int, uint WITH intdict;
    

* * *

[Prev](https://www.postgresql.org/docs/contrib-dblink-build-sql-update.html "dblink_build_sql_update") | [Up](https://www.postgresql.org/docs/contrib.html "Appendix F. Additional Supplied Modules and Extensions") |  [Next](https://www.postgresql.org/docs/dict-xsyn.html "F.13. dict_xsyn — example synonym full-text search dictionary")  
---|---|---  
dblink_build_sql_update  | [Home](https://www.postgresql.org/docs/index.html "PostgreSQL 17.4 Documentation") |  F.13. dict_xsyn — example synonym full-text search dictionary

