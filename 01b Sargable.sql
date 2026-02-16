    USE StackOverflow2013;
    SET NOCOUNT ON;
    SET STATISTICS TIME, IO ON;
    
    EXEC dbo.DropIndexes;
    
    CREATE INDEX 
        whatever 
    ON dbo.Comments 
        (UserId)
    WITH (SORT_IN_TEMPDB = ON, ONLINE = OFF);
    GO 
    CREATE INDEX 
        apathy 
    ON dbo.Comments 
        (Score, UserId) 
    WITH (SORT_IN_TEMPDB = OFF, ONLINE = OFF);
    GO 
    CREATE INDEX 
        ennui ON 
    dbo.Comments 
        (PostId, UserId)
    WITH (SORT_IN_TEMPDB = ON, ONLINE = OFF);
    GO 




/*
███████╗ █████╗ ██████╗  ██████╗  █████╗ ██████╗ ██╗     ███████╗
██╔════╝██╔══██╗██╔══██╗██╔════╝ ██╔══██╗██╔══██╗██║     ██╔════╝
███████╗███████║██████╔╝██║  ███╗███████║██████╔╝██║     █████╗  
╚════██║██╔══██║██╔══██╗██║   ██║██╔══██║██╔══██╗██║     ██╔══╝  
███████║██║  ██║██║  ██║╚██████╔╝██║  ██║██████╔╝███████╗███████╗
╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝╚═════╝ ╚══════╝╚══════╝
*/


    /*
    Turn on query plans!
    */







    /*
    What is SARGable?
    
    When you write queries and you want them to be fast, 
        your goal should be to write the simplest query you can.
    
    Unfortunately, what’s simple to you may be difficult for the optimizer, and for your query. 
    
    Some examples of this in joins and where clauses are:
        * function(column) = something
        * column + column = something
        * column + value = something
        * column = @something or @something IS NULL
        * column like '%something'
        * column = case when …
    
    And when you do stuff like this, your queries can end up with all sorts of bad side effects:
        * Increased CPU (burn baby burn)
        * Index Scans (when you could have Seeks)
        * Implicit Conversion (if your predicates produce a different data type)
        * Poor Cardinality Estimates (poking the optimizer in the eye)
        * Inappropriate Plan Choices (because the optimizer is blind now, you jerk)
        * Long Running Queries (yay job security!)
    */
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    /*How big is this thing?*/
    SELECT 
        records = FORMAT(COUNT(*), 'N0')
    FROM dbo.Comments AS c;
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    /*Let's look at two queries, we don't have a good index for either of them...*/

    SELECT 
        records = COUNT_BIG(*)
    FROM dbo.Comments AS c WITH (INDEX = PK_Comments_Id) 
    WHERE c.UserId IS NOT NULL --SARGable
    AND   1 = (SELECT 1);
    
    SELECT 
        records = COUNT_BIG(*)
    FROM dbo.Comments AS c WITH (INDEX = PK_Comments_Id) 
    WHERE ISNULL(c.UserId, -2147483647 ) > 0 --Decidedly less SARGable
    AND   1 = (SELECT 1);
    
    
    /*Add the index...*/
    CREATE INDEX whatever ON dbo.Comments (UserId);
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    

    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    /*With a non-selective predicate?*/
    SELECT 
        records = COUNT_BIG(*)
    FROM dbo.Comments AS c 
    WHERE c.UserId IS NOT NULL --SARGable
    AND   1 = (SELECT 1);
    
    SELECT 
        records = COUNT_BIG(*)
    FROM dbo.Comments AS c 
    WHERE ISNULL(c.UserId, -2147483647 ) > 0 --Decidedly less SARGable
    AND   1 = (SELECT 1);
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    /*
    Outcome: 
        The sargable query can seek, but it still has to read most of the rows.
        The non-saragable query can't, but they do similar amounts of work anyway.
    */
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    /*What about with a more selective predicate?*/
 
    SELECT 
        records = COUNT_BIG(*)
    FROM dbo.Comments AS c 
    WHERE c.UserId IS NULL --SARGable
    AND   1 = (SELECT 1);
    
    SELECT 
        records = COUNT_BIG(*)
    FROM dbo.Comments AS c 
    WHERE ISNULL(c.UserId, -2147483647 ) < 0 --Decidedly less SARGable
    AND   1 = (SELECT 1);
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    /*
    Outcome: 
        The sargable query can seek, but now it can really do a lot less work.
        The non-saragable query still can't, and it does way more work (and still goes parallel)
    */
    
    /*What if we limit it?*/
    SELECT 
        records = COUNT_BIG(*)
    FROM dbo.Comments AS c 
    WHERE ISNULL(c.UserId, -2147483647 ) < 0 --Decidedly less SARGable
    AND   1 = (SELECT 1)
    OPTION(MAXDOP 1);
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    /*
    Outcome: 
        Takes 1.3 seconds, still lots of extra reads
    */
    
    /*
    What we know so far:
        SARGability matters when predicates are selective, 
        and the column we're searching on is the leading key column of an index
    */
    
    
    
    
    
    
    
    
    
    
    /*What about with slightly different predicates?*/
    CREATE INDEX 
        apathy 
    ON dbo.Comments 
        (Score, UserId); 
    
    /*How many?*/
    SELECT TOP (100) 
        c.Score, 
        records = 
            FORMAT(COUNT_BIG(*), 'N0')
    FROM dbo.Comments AS c
    GROUP BY c.Score
    ORDER BY COUNT_BIG(*) DESC;
    
    
    /*This is not selective at all for Score*/

    SELECT 
        records = COUNT_BIG(*)
    FROM dbo.Comments AS c 
    WHERE c.UserId IS NULL --SARGable
    AND   c.Score = 0
    AND   1 = (SELECT 1);
    
    SELECT 
        records = COUNT_BIG(*)
    FROM dbo.Comments AS c 
    WHERE ISNULL(c.UserId, -2147483647 ) < 0 --Decidedly less SARGable
    AND   c.Score = 0
    AND   1 = (SELECT 1);
    
    /*
    Outcome: 
        Sargable query does a lot less work
        Non-sargable still needs to go parallel
    */
    
    /*Control for parallelism?*/
    SELECT 
        records = COUNT_BIG(*)
    FROM dbo.Comments AS c 
    WHERE ISNULL(c.UserId, -2147483647 ) < 0 --Decidedly less SARGable
    AND   c.Score = 0
    AND   1 = (SELECT 1)
    OPTION(MAXDOP 1);
    
    /*
    Outcome: 
        Takes 1.5 seconds, lots of reads, etc.
    */
    
    
    /*This is selective for Score*/    
    
    SELECT 
        records = COUNT_BIG(*)
    FROM dbo.Comments AS c 
    WHERE c.UserId IS NOT NULL --SARGable
    AND   c.Score = 26
    AND   1 = (SELECT 1);
    
    SELECT 
        records = COUNT_BIG(*)
    FROM dbo.Comments AS c 
    WHERE ISNULL(c.UserId, -2147483647 ) > 0 --Decidedly less SARGable
    AND   c.Score = 26
    AND   1 = (SELECT 1);

    
    
    
    
    
    
    
    
    
    
    
    
    

/*
Sargability matters most when:
 * It’s the leading index column and a seek is appropriate

Sargability matters less when:
 * You don’t have a good index anyway
 * The leading predicate is selective and you can seek

But you should always aim for SARGable predicates. 
There’s not often a good reason to avoid it.

*/

