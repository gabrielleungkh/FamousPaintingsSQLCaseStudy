-- Solve the below SQL problems using the Famous Paintings & Museum dataset:

SELECT * FROM ARTIST; -- 421 RECORDS
-- artist_id, full_name, first_name, middle_name, last_name, nationality, style, birth, death

SELECT * FROM CANVAS_SIZE; -- 200 RECORDS
-- size_id, width, height, label

SELECT * FROM IMAGE_LINK; -- 14775 RECORDS
-- work_id, url, thumbnail_small_url, thumbnail_large_url

SELECT * FROM MUSEUM; -- 57 RECORDS
-- museum_id, name, address, city, state, postal, country, phone, url

SELECT * FROM MUSEUM_HOURS; -- 351 RECORDS
-- museum_id, day, open, close

SELECT * FROM PRODUCT_SIZE; -- 110347 RECORDS
-- work_id, size_id, sale_price, regular_price

SELECT * FROM SUBJECT; -- 6771 RECORDS
-- work_id, subject

SELECT * FROM WORK; -- 14776 RECORDS
-- work_id, name, artist_id, style, museum_id

-- 1) Fetch all the paintings which are not displayed on any museums?
SELECT *
FROM MUSEUM
WHERE MUSEUM_ID IS NULL;

-- 2) Are there museums without any paintings?
SELECT *
FROM MUSEUM
WHERE NOT EXISTS (SELECT MUSEUM_ID 
				  FROM WORK
				  WHERE MUSEUM.MUSEUM_ID = WORK.MUSEUM_ID);

-- 3A) How many paintings have an asking price of more than their regular price? 
SELECT COUNT(WORK_ID) AS NUM_PAINTINGS
FROM PRODUCT_SIZE
WHERE SALE_PRICE > REGULAR_PRICE;

-- 3B) How many paintings have an asking price of less than their regular price? 
SELECT COUNT(WORK_ID) AS NUM_PAINTINGS
FROM PRODUCT_SIZE
WHERE SALE_PRICE < REGULAR_PRICE;

-- 3C) What is the ratio of paintings with asking price less than regular price to total number of paintings?
SELECT ((SELECT CAST(COUNT(WORK_ID) AS DECIMAL)
		FROM PRODUCT_SIZE
		WHERE SALE_PRICE < REGULAR_PRICE) / COUNT(PRODUCT_SIZE.WORK_ID))
FROM PRODUCT_SIZE;

-- 4) Identify the paintings whose asking price is less than 50% of its regular price
-- subquery to find the halved regular price of every painting
-- main query that uses the subquery in the where clause
SELECT * FROM PRODUCT_SIZE;

WITH HALF_PRICE	AS 
	(SELECT *, ((CAST(REGULAR_PRICE AS DECIMAL) / 2))
	 AS HALF_REGULAR_PRICE
	 FROM PRODUCT_SIZE)
SELECT *
FROM PRODUCT_SIZE PS
JOIN HALF_PRICE HP
ON PS.WORK_ID = HP.WORK_ID
AND PS.SIZE_ID = HP.SIZE_ID
WHERE PS.SALE_PRICE < HP.HALF_REGULAR_PRICE;

-- 5) Which canvas size costs the most?
-- use rank() window function to identify the most costly canvas by sale price
-- display the label and sale price of that canvas size
SELECT LABEL, SALE_PRICE
FROM (SELECT *,
		RANK() OVER(ORDER BY SALE_PRICE DESC) AS RNK
		FROM PRODUCT_SIZE PS
		JOIN CANVAS_SIZE CS
		ON PS.SIZE_ID = CAST(CS.SIZE_ID AS TEXT)) AS X
WHERE X.RNK = 1;

-- 6) Delete duplicate records from work, product_size, subject and image_link tables
-- first find all duplicate records
-- delete those records from each table

-- duplicate all tables to be modified
DROP TABLE IF EXISTS WORK_Q6;
DROP TABLE IF EXISTS PRODUCT_SIZE_Q6;
DROP TABLE IF EXISTS SUBJECT_Q6;
DROP TABLE IF EXISTS IMAGE_LINK_Q6;

CREATE TABLE IF NOT EXISTS WORK_Q6 AS TABLE WORK;
CREATE TABLE IF NOT EXISTS PRODUCT_SIZE_Q6 AS TABLE PRODUCT_SIZE;
CREATE TABLE IF NOT EXISTS SUBJECT_Q6 AS TABLE SUBJECT;
CREATE TABLE IF NOT EXISTS IMAGE_LINK_Q6 AS TABLE IMAGE_LINK;

-----------------------------------------------------------------------------------

-- try deleting duplicates using row_number()
-- this query actually deletes every record where there is a duplicate instead of only deleting the duplicate
/*
DELETE FROM WORK_Q6
WHERE WORK_ID IN
	(SELECT WORK_ID
		FROM (SELECT *,
				ROW_NUMBER() OVER(PARTITION BY WORK_ID) AS DUPL_COUNTER
				FROM WORK_Q6)
	  	WHERE DUPL_COUNTER > 1);
*/

-- DELETE DUPLICATES FROM WORK

-- find all duplicates and delete using a temporary unique id column
-- first add temporary id column
ALTER TABLE WORK_Q6 ADD COLUMN RN INT GENERATED ALWAYS AS IDENTITY;
-- find all unique records by grouping all work_id's together
-- for duplicate records that are found, keep the record with the lowest unique id
-- delete all records that are not unique
DELETE FROM WORK_Q6
WHERE RN NOT IN (SELECT MIN(RN)
					FROM WORK_Q6
					GROUP BY WORK_ID);
-- drop the temporary id column
ALTER TABLE WORK_Q6 DROP COLUMN RN;

-----------------------------------------------------------------------------------

-- DELETE DUPLICATES FROM PRODUCT_SIZE

ALTER TABLE PRODUCT_SIZE_Q6 ADD COLUMN RN INT GENERATED ALWAYS AS IDENTITY;
DELETE FROM PRODUCT_SIZE_Q6
WHERE RN NOT IN (SELECT MIN(RN)
					FROM PRODUCT_SIZE_Q6
					GROUP BY WORK_ID, SIZE_ID);
ALTER TABLE PRODUCT_SIZE_Q6 DROP COLUMN RN;

-----------------------------------------------------------------------------------

-- DELETE DUPLICATES FROM SUBJECT

ALTER TABLE SUBJECT_Q6 ADD COLUMN RN INT GENERATED ALWAYS AS IDENTITY;
DELETE FROM SUBJECT_Q6
WHERE RN NOT IN (SELECT MIN(RN)
					FROM SUBJECT_Q6
					GROUP BY WORK_ID, SUBJECT);
ALTER TABLE SUBJECT_Q6 DROP COLUMN RN;

-----------------------------------------------------------------------------------

-- DELETE DUPLICATES FROM IMAGE_LINK

ALTER TABLE IMAGE_LINK_Q6 ADD COLUMN RN INT GENERATED ALWAYS AS IDENTITY;
DELETE FROM IMAGE_LINK_Q6
WHERE RN NOT IN (SELECT MIN(RN)
					FROM IMAGE_LINK_Q6
					GROUP BY WORK_ID);
ALTER TABLE IMAGE_LINK_Q6 DROP COLUMN RN;

-- 7) Identify the museums with invalid city information in the given dataset

-- POSIX regular expression matching to any city field that has one or more digit
SELECT *
FROM MUSEUM
WHERE CITY ~ '[0-9]+';

-- 8) Museum_Hours table has 1 invalid entry. Identify it and remove it.

-- duplicate the museum_hours table
DROP TABLE IF EXISTS MUSEUM_HOURS_Q8;
CREATE TABLE IF NOT EXISTS MUSEUM_HOURS_Q8 AS TABLE MUSEUM_HOURS;

-- check if the opening time is later than the closing time for any entry

SELECT * 
FROM MUSEUM_HOURS_Q8 
WHERE CAST(OPEN AS TIME) > CAST(CLOSE AS TIME);
-- failed to cast because of some bad formatting
-- fix formatting to do the check
UPDATE MUSEUM_HOURS_Q8 
SET CLOSE = '08:00:PM' 
WHERE CLOSE = '08 :00:PM';
-- no errors in opening time vs closing time

-- check for duplicate records
SELECT MUSEUM_ID, DAY, COUNT(*) 
FROM MUSEUM_HOURS_Q8 
GROUP BY MUSEUM_ID, DAY 
HAVING COUNT(*) > 1;

-- duplicate record exists so remove it

ALTER TABLE MUSEUM_HOURS_Q8 ADD COLUMN RN INT GENERATED ALWAYS AS IDENTITY;
DELETE FROM MUSEUM_HOURS_Q8
WHERE RN NOT IN (SELECT MIN(RN)
					FROM MUSEUM_HOURS_Q8
					GROUP BY MUSEUM_ID, DAY);
ALTER TABLE MUSEUM_HOURS_Q8 DROP COLUMN RN;

-- 9) Fetch the top 10 most famous painting subject

-- assumption that "most famous" means the subjects with the most works

SELECT S.SUBJECT,
COUNT(W.WORK_ID),
RANK() OVER(ORDER BY COUNT(W.WORK_ID) DESC)
FROM WORK W 
JOIN SUBJECT S ON W.WORK_ID = S.WORK_ID
GROUP BY S.SUBJECT
LIMIT 10;

-- 10) Identify the museums which are open on both Sunday and Monday. Display museum name, city.

-- find all museums that are open on Sunday
-- intersect that with all museums that are open on Monday
(SELECT M.NAME, M.CITY
FROM MUSEUM M
JOIN MUSEUM_HOURS MH
ON M.MUSEUM_ID = MH.MUSEUM_ID
WHERE MH.DAY = 'Sunday')
INTERSECT
(SELECT M.NAME, M.CITY
FROM MUSEUM M
JOIN MUSEUM_HOURS MH
ON M.MUSEUM_ID = MH.MUSEUM_ID
WHERE MH.DAY = 'Monday')
ORDER BY NAME;

-- 11) How many museums are open every single day?

SELECT COUNT(*) AS NUM_MUSEUMS
FROM (SELECT COUNT(*) FROM MUSEUM_HOURS
		GROUP BY MUSEUM_ID
		HAVING COUNT(*) = 7);

-- 12) Which are the top 5 most popular museum? (Popularity is defined based on most no of paintings in a museum)

-- use rank() window function to find the top 5
-- since the column created by a window function can't be used directly,
-- use it as a subquery to isolate the top 5 museums
SELECT * 
FROM MUSEUM M
JOIN (SELECT W.MUSEUM_ID,
	  	COUNT(W.MUSEUM_ID),
	  	RANK() OVER(ORDER BY COUNT(W.WORK_ID) DESC)
		FROM WORK W
		JOIN MUSEUM M
		ON W.MUSEUM_ID = M.MUSEUM_ID
		GROUP BY W.MUSEUM_ID) AS X
ON M.MUSEUM_ID = X.MUSEUM_ID
WHERE X.RANK <= 5
ORDER BY X.RANK;

-- 13) Who are the top 5 most popular artist? (Popularity is defined based on most no of paintings done by an artist)

SELECT *
FROM ARTIST A
JOIN (SELECT W.ARTIST_ID,
	  	COUNT(W.ARTIST_ID),
	  	RANK() OVER(ORDER BY COUNT(W.WORK_ID) DESC)
		FROM WORK W
		JOIN ARTIST A
		ON W.ARTIST_ID = A.ARTIST_ID
		GROUP BY W.ARTIST_ID) AS X
ON A.ARTIST_ID = X.ARTIST_ID
WHERE X.RANK <= 5
ORDER BY X.RANK;

-- 14) Display the 3 least popular canva sizes

-- some size_id's correspond to the same painting size described by the label
-- group by both those parameters
-- use dense_rank() instead of rank() so bottom 3 can be ranked more easily
SELECT *
FROM (SELECT PS.SIZE_ID,
		CS.LABEL,
	  	COUNT(W.WORK_ID),
	  	DENSE_RANK() OVER(ORDER BY COUNT(W.WORK_ID))
		FROM WORK W
		JOIN PRODUCT_SIZE PS
		ON W.WORK_ID = PS.WORK_ID
		JOIN CANVAS_SIZE CS
		ON PS.SIZE_ID = CAST(CS.SIZE_ID AS TEXT)
		GROUP BY PS.SIZE_ID, CS.LABEL) AS X
WHERE X.DENSE_RANK <= 3;

-- 15) Which museum is open for the longest during a day. Dispay museum name, state and hours open and which day?

DROP TABLE IF EXISTS MUSEUM_HOURS_Q15;
CREATE TABLE IF NOT EXISTS MUSEUM_HOURS_Q15 AS TABLE MUSEUM_HOURS;

-- failed to cast because of some bad formatting
-- fix formatting to cast
UPDATE MUSEUM_HOURS_Q15
SET CLOSE = '08:00:PM'
WHERE CLOSE = '08 :00:PM';

SELECT M.NAME, M.STATE, X.HOURS_OPEN, X.DAY
FROM MUSEUM M
JOIN (SELECT MUSEUM_ID, DAY,
		(CAST(CLOSE AS TIME) - CAST(OPEN AS TIME)) AS HOURS_OPEN
		FROM MUSEUM_HOURS_Q15) AS X
ON M.MUSEUM_ID = X.MUSEUM_ID
ORDER BY HOURS_OPEN DESC
LIMIT 1;

-- 16) Which museum has the most no of most popular painting style?

-- to find most popular painting style use CTE
WITH POPULAR_STYLE AS (SELECT STYLE, COUNT(WORK_ID),
						RANK() OVER(ORDER BY COUNT(WORK_ID) DESC)
						FROM WORK
						GROUP BY STYLE)
-- main query will show museum name, most popular art style,
-- and number of paintings of that style
SELECT M.NAME, Q.STYLE, Q.COUNT AS NUM_PAINTINGS
FROM MUSEUM M
JOIN (SELECT M.MUSEUM_ID, W.STYLE, COUNT(1)
		FROM WORK W
		JOIN MUSEUM M
		ON W.MUSEUM_ID = M.MUSEUM_ID
		WHERE STYLE = (SELECT STYLE
						FROM POPULAR_STYLE
						WHERE RANK = 1)
		GROUP BY M.MUSEUM_ID, W.STYLE
		ORDER BY COUNT(1) DESC
		LIMIT 1) AS Q
ON M.MUSEUM_ID = Q.MUSEUM_ID

-- 17) Identify the artists whose paintings are displayed in multiple countries

SELECT FULL_NAME, COUNT(COUNTRY)
FROM (SELECT DISTINCT A.FULL_NAME, M.COUNTRY
		FROM ARTIST A
		JOIN WORK W
		ON A.ARTIST_ID = W.ARTIST_ID
		JOIN MUSEUM M
		ON W.MUSEUM_ID = M.MUSEUM_ID
		ORDER BY A.FULL_NAME)
GROUP BY FULL_NAME
HAVING COUNT(COUNTRY) > 1
ORDER BY COUNT(COUNTRY) DESC

-- 18) Display the country and the city with most no of museums. Output 2 separate columns to mention the city and country. If there are multiple values, separate them with comma.

WITH MOST_COUNTRY AS (SELECT COUNTRY, COUNT(1)
						FROM MUSEUM
						GROUP BY COUNTRY
						ORDER BY COUNT(1) DESC),
	 COUNTRY_RANK AS (SELECT COUNTRY, COUNT,
						RANK() OVER(ORDER BY COUNT DESC) AS RNK
						FROM MOST_COUNTRY),
	 MOST_CITY AS (SELECT CITY, COUNT(1)
						FROM MUSEUM
						GROUP BY CITY
						ORDER BY COUNT(1) DESC),
	 CITY_RANK AS (SELECT CITY, COUNT,
						RANK() OVER(ORDER BY COUNT DESC) AS RNK
						FROM MOST_CITY)
SELECT STRING_AGG(DISTINCT X.COUNTRY, ', ') AS COUNTRY, STRING_AGG(Y.CITY, ', ') AS CITY
FROM COUNTRY_RANK AS X
CROSS JOIN
CITY_RANK AS Y
WHERE X.RNK = 1 AND Y.RNK = 1

-- 19) Identify the artist and the museum where the most expensive and least expensive painting is placed. Display the artist name, sale_price, painting name, museum name, museum city and canvas label

-- 20) Which country has the 5th highest no of paintings?

-- 21) Which are the 3 most popular and 3 least popular painting styles?

-- 22) Which artist has the most no of Portraits paintings outside USA?. Display artist name, no of paintings and the artist nationality.


