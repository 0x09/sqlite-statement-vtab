SQLite module to define virtual tables and table-valued functions natively using SQL.

statement_vtab is particularly handy as an interface for deriving multiple outputs from built-in or user-defined functions without the need to create a specialized module.

# Example
Example which dynamically creates a virtual table `split_date` that uses the built-in `strftime` function to extract year, month, and day from a date input into columns:
```SQL
.load statement_vtab

-- define a virtual table with columns "year", "month", "day", and hidden column "date" for input
CREATE VIRTUAL TABLE split_date USING statement((
  SELECT
    strftime('%Y', :date) AS year,
    strftime('%m', :date) AS month,
    strftime('%d', :date) AS day
));

-- split_date can be used as a table-valued function
SELECT * FROM split_date('2019-11-13');
year        month       day       
----------  ----------  ----------
2019        11          13        

-- or as a regular virtual table if the arguments are provided as equal constraints
SELECT * FROM split_date WHERE date = '2019-11-13';
year        month       day       
----------  ----------  ----------
2019        11          13        

-- when used with an "in" clause, yields multiple rows from one statement
SELECT * FROM split_date WHERE date IN('2019-11-13','2020-11-13','2021-11-13');
year        month       day       
----------  ----------  ----------
2019        11          13        
2020        11          13        
2021        11          13        

-- apply split_date to values from some other table
CREATE TABLE dates (date TEXT);
INSERT INTO dates VALUES('2019-11-13'), ('2020-11-13'), ('2021-11-13');

-- as a table-valued function
SELECT * FROM dates, split_date(dates.date);
date        year        month       day       
----------  ----------  ----------  ----------
2019-11-13  2019        11          13        
2020-11-13  2020        11          13        
2021-11-13  2021        11          13        

-- equivalently using the usual table syntax
SELECT * FROM dates INNER JOIN split_date ON split_date.date = dates.date;
date        year        month       day       
----------  ----------  ----------  ----------
2019-11-13  2019        11          13        
2020-11-13  2020        11          13        
2021-11-13  2021        11          13        
-- (in this case a natural join would work just as well)
```

# Syntax
`CREATE VIRTUAL TABLE tablename USING statement((stmt))`

Where `stmt` may be any select statement supported by SQLite: https://www.sqlite.org/lang_select.html

## Column definitions
Columns defined by the provided statement become columns in the resulting virtual table:
```SQL
CREATE VIRTUAL TABLE abc USING statement((select 1 as a, 2 as b, 3 as c));

SELECT * FROM abc;
a           b           c         
----------  ----------  ----------
1           2           3         
```
This extends to other (virtual) tables as well. Using the built in [dbstat](https://www.sqlite.org/dbstat.html) virtual table as an example, we can reproduce its columns with:
```SQL
CREATE VIRTUAL TABLE another_dbstat USING statement((SELECT * FROM dbstat));

SELECT * FROM another_dbstat;
name           path        pageno      pagetype    ncell       payload     unused      mx_payload  pgoffset    pgsize    
-------------  ----------  ----------  ----------  ----------  ----------  ----------  ----------  ----------  ----------
sqlite_master  /           1           leaf        2           206         3774        115         0           4096      
```
And in this case the declared type affinity of the columns is preserved as well.

## Parameter binding
For substituting values into the statement, statement_vtab relies on SQLite's parameter binding syntax. Any bound parameter names become hidden columns in the virtual table, and so can be used as arguments to the resulting table-valued function or referenced directly. See https://www.sqlite.org/lang_expr.html#varparam for a detailed description of SQLite's syntax for parameter binding.

### Anonymous params
Unnamed arguments are indexed by position:
```SQL
CREATE VIRTUAL TABLE arguments USING statement((SELECT ? AS a, ? AS b, ? AS c));

-- call with table-valued function syntax
SELECT * FROM arguments('x','y','z');
a           b           c         
----------  ----------  ----------
x           y           z         

-- or using the indexes as column names
SELECT * from ARGUMENTS WHERE [1] = 'x' AND [2] = 'y' AND [3] = 'z';
a           b           c         
----------  ----------  ----------
x           y           z         

```
Note that this will create a new numbered parameter for each `?`. Unnamed parameters can be referenced multiple times with the ?NNN syntax.
```SQL
CREATE VIRTUAL TABLE sumdiff USING statement((SELECT ? + ? AS sum, ?1 - ?2 AS difference));

SELECT * FROM sumdiff(1,3);
sum         difference
----------  ----------
4           -2        

-- Though it's usually better to be explicit and number all params in that case. The following definition of `sumdiff` is equivalent to the first.
CREATE VIRTUAL TABLE sumdiff USING statement((SELECT ?1 + ?2 AS sum, ?1 - ?2 AS difference));
```

### Named params
Named parameters may be used; these will still be treated positionally when using the table-valued function syntax:
```SQL
-- this example uses the `sqrt` function from https://www.sqlite.org/contrib/download/extension-functions.c
CREATE VIRTUAL TABLE hypot USING statement((SELECT sqrt(:x * :x + :y * :y) AS hypotenuse));

-- call "hypot" as a table-valued function
SELECT * FROM hypot(3,4);
hypotenuse
----------
5.0       

-- or by referencing the named parameter columns "x" and "y" directly
SELECT * FROM hypot WHERE x = 3 AND y = 4;
hypotenuse
----------
5.0       

-- though inputs will be suppressed from *, we can ask for these explicitly
SELECT x, y, * FROM hypot(3,4);
x           y           hypotenuse
----------  ----------  ----------
3           4           5.0       

SELECT x, y, * FROM hypot WHERE x = 3 AND y = 4;
x           y           hypotenuse
----------  ----------  ----------
3           4           5.0       
```

Any parameters not provided when querying the resulting vtab are treated as NULLs. The `coalesce`/`ifnull` SQL functions can thus be used to supply argument defaults, though note that this vtab does not attempt to differentiate between an argument that was simply omitted vs one that was explicitly provided as NULL.
