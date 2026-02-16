USE StackOverflow2013;
EXECUTE dbo.DropIndexes;
SET NOCOUNT ON;


/*
     ██╗ ██████╗ ██╗███╗   ██╗███████╗██╗
     ██║██╔═══██╗██║████╗  ██║██╔════╝██║
     ██║██║   ██║██║██╔██╗ ██║███████╗██║
██   ██║██║   ██║██║██║╚██╗██║╚════██║╚═╝
╚█████╔╝╚██████╔╝██║██║ ╚████║███████║██╗
 ╚════╝  ╚═════╝ ╚═╝╚═╝  ╚═══╝╚══════╝╚═╝

*/


/*
Joins are quite interesting things, aren't they?

One moment you have a table sitting there, just
minding its own business, and the next moment
it's being matched up against some other table
in a battle to the death for ultimate database supremacy.

Okay, maybe it's not all that jarring. They're used to it.

Joins are used to relate data between two or more things.

Why "things"?

In SQL, just about all query results are "tabular", and can
be joined together to form a single result set for users.

You can join:
  * Tables
  * Views
  * Subqueries
  * Derived tables
  * Common Table Expressions
  * Multi-Statement and Inline Functions
  * VALUES clauses

The point of joins comes back to the point of databases.

Databases, at least the kind that we're working with, will
(hopefully) contain multiple tables, with some degree of
normalization applied to them, and hopefully some well-defined
and -indexed keys to find matching (or non-matching!) rows.

SQL Server uses quite standard logical join types:
  * CROSS JOIN
  * (INNER) JOIN
  * LEFT (OUTER) JOIN
  * RIGHT (OUTER) JOIN
  * FULL (OUTER) JOIN

There are of course Semi-Joins and Anti-Semi Joins, but 
those aren't "written" join types. 

The engine can use them for queries expressed in certain ways: e.g. 
  * EXISTS
  * NOT EXISTS
  * IN
  * NOT IN

There are a couple T-SQL specific joins that you can use, 
CROSS APPLY and OUTER APPLY, commonly implemented in 
other database engines as LATERAL JOINs.

In SQL Server, a JOIN can be implemented physically with
  * Apply Nested Loops
  * Nested Loops Join
  * Merge Join
  * Hash Join

Nested Loops is the simplest and most versatile join algorithm.

Merge Joins and Hash Joins require at least one equality predicate
(except Merge FULL OUTER JOIN).

Since everyone else who talks about joins says this, I'm going to
say it for completeness, but it's not a terribly important detail:
  * All Joins begin as a Cross Join, with ON filters applied next
  * Unless it's a Cross Join, of course. Then you get a Cartesian Product.

*/


/*
Some simple temporary tables
*/
DROP TABLE IF EXISTS
    #t0,
    #t1;

CREATE TABLE 
    #t0 
(
    id bigint NULL
);

CREATE TABLE 
    #t1 
(
    id bigint NULL
);

INSERT 
    #t0 
(
    id
)
SELECT
    gs.value
FROM GENERATE_SERIES(1, 5, 1) AS gs;

INSERT 
    #t1 
(
    id
)
SELECT
    gs.value
FROM GENERATE_SERIES(1, 5, 1) AS gs;


/*
Force a Loop Join for predictability

The predicate for the JOIN ON clause
is applied at the Nested Loops Join
operator. Hover over the Nested Loops Join 
for a tool tip that shows the Predicate.

Enable query plans (CTRL + M).

*/

SELECT
    t0.id,
    t1.id
FROM #t0 AS t0
JOIN #t1 AS t1
  ON t1.id = t0.id
OPTION(LOOP JOIN);


/*
Force a Loop Join for predictability

The Apply Loops Join will have a new section 
in the tool tip for "Outer References", and the 
Seek on the inner side of the Nested Loops Join (#t1)
will reference a Scalar Operator with the id column
from #t0 as the Seek Predicate.

Enable query plans (CTRL + M).

The index makes this easier to demonstrate.

*/


/*Could also be a clustered index here*/
CREATE INDEX t1 ON #t1 (id);

SELECT
    t0.id,
    t1.id
FROM #t0 AS t0
JOIN #t1 AS t1
  ON t1.id = t0.id
OPTION(LOOP JOIN);

/*No longer necessary*/
DROP INDEX
    t1 
ON #t1;


/*
Force a Merge Join for predictability

Merge Joins have two requirements:
  * At least one equality predicate (except full join)
  * Sorted inputs

Merge Joins may be One to Many, or
Many to Many, and can use Bitmaps.

These are discussed in greater length in my 
performance tuning courses, but not here.

Note the Sort operators in the plan with
no indexes, and the lack of Sort operators
in the plan after adding indexes.

*/

SELECT
    t0.id,
    t1.id
FROM #t0 AS t0
JOIN #t1 AS t1
  ON t1.id = t0.id
OPTION(MERGE JOIN);


/*Could also use non-clustered indexes here*/
CREATE CLUSTERED INDEX t0 ON #t0(id);
CREATE CLUSTERED INDEX t1 ON #t1(id);


SELECT
    t0.id,
    t1.id
FROM #t0 AS t0
JOIN #t1 AS t1
  ON t1.id = t0.id
OPTION(MERGE JOIN);

DROP INDEX t0 ON #t0;
DROP INDEX t1 ON #t1;

/*
Force a Hash Join for predictability

Hash Joins only have one requirement;
at least one equality predicate. There
are many things that can go on internally
with Hash Joins, including Bitmap usage. 

Again, these are covered in my performance
tuning courses, but not here, as it's a wide topic.

*/

SELECT
    t0.id,
    t1.id
FROM #t0 AS t0
JOIN #t1 AS t1
  ON t1.id = t0.id
OPTION(HASH JOIN);


/*
Semi and Anti Semi-Joins with EXISTS
and NOT EXISTS. No Join syntax or hints
for these. Look at query plans for visual
confirmation of the join type used in each.

*/

SELECT
    t0.*
FROM #t0 AS t0
WHERE EXISTS
(
    SELECT
        1/0
    FROM #t1 AS t1
    WHERE t1.id = t0.id
);

SELECT
    t0.*
FROM #t0 AS t0
WHERE NOT EXISTS
(
    SELECT
        1/0
    FROM #t1 AS t1
    WHERE t1.id = t0.id
);


/*
JOIN Fundamentals
  * Joins relate data between two or more tabular data sources
  * Used to combine data from normalized tables into a single result set
  * Can join tables, views, subqueries, derived tables, CTEs, functions, 
    and VALUES clauses

JOIN Types in SQL Server
  * CROSS JOIN: Cartesian product of two tables
  * (INNER) JOIN: Returns only matching rows from both tables
  * LEFT (OUTER) JOIN: Returns all rows from left table, 
    matching rows from right
  * RIGHT (OUTER) JOIN: Returns all rows from right table, 
    matching rows from left
  * FULL (OUTER) JOIN: Returns all rows from both tables
  * APPLY (CROSS/OUTER): SQL Server's implementation similar 
    to LATERAL joins

Physical JOIN Implementations
  * Nested Loops Join: Most versatile, works with any predicates
  * Merge Join: Requires equality predicate and sorted inputs
  * Hash Join: Requires equality predicate, builds hash table
  * Apply Nested Loops: Special type with outer references

Semi and Anti-Semi Joins
  * Not explicit JOIN syntax but logical operations
  * Implemented using EXISTS and NOT EXISTS
  * IN and NOT IN can also use these join types
  * Used when only checking for existence of matching rows

*/