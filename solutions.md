## Section 4.2: Self joins

```{r}
## Avoid pairing a question with itself
dbGetQuery(db, "create view question_contrasts as
               select * from questions Q1 join questions Q2
               on Q1.ownerid = Q2.ownerid
               where Q1.creationdate != Q2.creationdate")

## Remove duplicate pairs
dbGetQuery(db, "create view question_contrasts as
               select * from questions Q1 join questions Q2
               on Q1.ownerid = Q2.ownerid
               where Q1.creationdate < Q2.creationdate")
```

## Section 4.3: Set operations

***Challenge***: Find all the questions about either R or Python.

```{r}
result <- dbGetQuery(db, "select title from questions Q1 join questions_tags T1 
	       on Q1.questionid = T1.questionid where T1.tag = 'r'
	       union 
	       select title from questions Q2 join questions_tags T2
	       on Q2.questionid = T2.questionid where T2.tag = 'python'") 
```


## Section 4.4: String processing

***Challenge***: Select the questions that have "java" but not "javascript" in their titles using regular expression syntax.

```{r}
dbGetQuery(db, "select * from questions_tags where tag SIMILAR TO '%java[^s]%' limit 10")
dbGetQuery(db, "select * from questions_tags where tag SIMILAR TO '%java%'
               except
               select * from questions_tags where tag SIMILAR to '%javascript%'
               limit 10")
```

***Challenge***: Figure out how to calculate the length (in characters) of the title of each question.

```{r}
dbGetQuery(db, "select title, length(title) as nchar from questions limit 5")
```

***Challenge***: Process the creationdate field to create year, day, and month fields.


```{r}
dbExecute(db, "create view questions_dated as
               select questionid, ownerid, score, viewcount, 
               substring(creationdate from '#\"[[:digit:]]{4}#\"%' for '#') as year,
               substring(creationdate from '[[:digit:]]{4}-#\"[[:digit:]]{2}#\"%' for '#') as month,
               substring(creationdate from '[[:digit:]]{4}-[[:digit:]]{2}-#\"[[:digit:]]{2}#\"%' for '#') as day 
               from questions")
               
```

That used regular expressions for illustration but could be done with fixed length substrings, which means one could it with SUBSTR in SQLite.

```{r}
dbExecute(db, "create view questions_dated as
               select questionid, ownerid, score, viewcount, 
               substr(creationdate, 1, 4) as year,
               substr(creationdate, 6, 2) as month,
               substr(creationdate, 9, 2) as day
               from questions")
```

## Section 4.7: Subqueries

***Challenge***: Write a query that returns the title of each question and answer to each question from the user with the highest reputation amongst all those answering the question. 

```{r}
## Do in steps, first creating a view
dbExecute(db, "create view maxrep_answers as
                         select *, max(reputation) as maxRep
                             from answers A join users U
                             on A.ownerid = U.userid group by A.questionid")

resultInSteps <- dbGetQuery(db, "select * from questions join maxrep_answers
	      	 		on questions.questionid = maxrep_answers.questionid")

## Do in one step as a subquery
resultFull <- dbGetQuery(db, "select * from questions Q join
                         (select *, max(reputation) as maxRep
                             from answers A join users U
                             on A.ownerid = U.userid group by A.questionid) maxRepAnswers
                         on Q.questionid = maxRepAnswers.questionid")
```

However, one can actually do this without using a subquery...

```{r}
dbGetQuery(db, "select *, max(reputation) as maxRep from questions Q 
           join answers A on Q.questionid = A.questionid
           join users U on A.ownerid = U.userid
           group by Q.questionid where Q.questionid == 9")
```

Note that those solutions rely on the fact that when using max() as the aggregation, the elements from the other fields will correspond to the row that is the max.

***Challenge***: Write a query that would return the users who have asked a question with the Python tag. We've seen this challenge before, but do it now based on a subquery.

```
result <- dbGetQuery(db, "select displayname, userid from users where userid in
                              (select ownerid from questions join questions_tags
                              on questions.questionid = questions_tags.questionid
                              where tag = 'python')")
```

## Section 4.8: Additional challenge questions

***Challenge***: Create a frequency list of the tags used in the top 100 most answered questions. This is a hard one - try to work it out in pieces, starting with the query that finds the most answered questions and joining that to other tables as needed. Note there is a way to do this with a JOIN and a way without a JOIN.

Here's one solution that joins a table to the result of a subquery.

```
result1 <- dbGetQuery(db, "select T.tag, count(*) as tagCnt from
               questions_tags T 
               join 
               (select questionid from answers
               group by questionid order by count(*) desc limit 100) most_answered
               on T.questionid = most_answered.questionid
               group by T.tag order by tagCnt desc")
```

Here's another solution that uses the subquery in a WHERE:

```
result2 <- dbGetQuery(db, "select T.tag, count(*) as tagCnt from
               questions_tags T where questionid in
               (select questionid from answers
               group by questionid order by count(*) desc limit 100)
               group by T.tag order by tagCnt desc")
```

***Challenge***: How would you find all the answers associated with the user with the most upvotes?

Here we match on upvotes:

```{r}
result <- dbGetQuery(db, "select * from answers join users on answers.ownerid = users.userid
               where upvotes =
               (select max(upvotes) from users)")
```

Here we determine the user and then get that user's answers:

```{r}
result <- dbGetQuery(db, "select * from answers join (select *, max(upvotes) from users) on ownerid = userid")
```


One consideration is that there could be multiple users tied for the most upvotes.

## Section 6: Window functions

***Challenge***: Use a window function to compute the average viewcount for each ownerid for the 10 questions preceding each question. 


```{r}
result <- dbGetQuery(db, "select *,
                          avg(viewcount) over (partition by ownerid order by julianday(creationdate)
                          rows between 10 preceding and 1 preceding) as avg_view           
                          from questions where ownerid is not null limit 50")
```

***Challenge (hard)***: Find the users who have asked one question that is highly-viewed (viewcount > 1000) with their remaining questions not highly-viewed (viewcount < 20).

As a first step, this finds the viewcount, rank of each question and number of questions asked by the user

```{r}
result <- dbGetQuery(db, "select *,
                         rank() over w as rank,
                         max(viewcount) over w as maxcount
                         from questions where ownerid is not null
                         window w as (partition by ownerid order by viewcount desc)")
```

Now let's use that result as a subquery where we filter based on the conditions we need to satisfy:

```{r}
result <- dbGetQuery(db, "select * from
                         (select *,
                         rank() over w as rank,
                         max(viewcount) over w as maxcount
                         from questions where ownerid is not null
                         window w as (partition by ownerid order by viewcount desc))
                         where rank = 2 and viewcount < 100 and maxcount > 1000")
```                         
                               


## Section 7: complicated queries

Rough sketch pseudo code solutions.

1) Given a table of user sessions with the format
```
date | session_id | user_id | session_time
```
calculate the distribution of the average daily
total session time in the last month. I.e., you want to get each user's daily average and then find the distribution over users. The output should be something like:
like:
```
minutes_per_day | number_of_users
```

Pseudo-code answer:

a) filter to last month (use datetime functionality to extract month or by comparing to the day that was one month ago)
b) sum session_time grouped by user
c) divide by number of days in month and round
d) count grouped by minutes_per_day 


2) Consider a table of messages of the form
```
sender_id | receiver_id | message_id
```
For each user, find the three users they message the most.

Pseudo-code answer:

a) count grouped by sender and receiver
b) window function to rank for each sender in descending order on the count
c) filter to rank <= 3


3) Suppose you have are running an online experiment and have a table on
the experimental design
```
user_id | test_group | date_first_exposed
```
Suppose you also have a messages table that indicates if each message
was sent on web or mobile:
```
date | sender_id | receive_id | message_id | interface (web or mobile)
```
What is the average (over users) of the average number of messages sent per day for each test group
if you look at the users who have sent messages only on mobile in the last month.

Pseudo-code answer:

a) filter to messages in last month
a) subquery to get mobile-only users - find all mobile users and use EXCEPT to remove all web users
b) join design, messages tables and count grouped by users, filtering to mobile users
c) divide by number of days in month
d) average grouped by test_group

(Note issue of selection bias in who decides to only send mobile messages or send messages at all...)
