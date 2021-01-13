## @knitr example1

dbGetQuery(db, "select count(*) from questions")
dbGetQuery(db, "select count(distinct ownerid) from questions")

## @knitr example2

dbGetQuery(db, "select count(*) from questions group by ownerid")
dbGetQuery(db, "select ownerid, count(*) from questions group by ownerid")
dbGetQuery(db, "select ownerid, count(*) as n from questions group by ownerid 
	       having n >= 50 order by n desc")

## @knitr example3

dbGetQuery(db, "select ownerid, count(*) as n from questions join users on
               questions.ownerid = users.userid
               group by ownerid having n >= 50 order by n desc limit 20")

