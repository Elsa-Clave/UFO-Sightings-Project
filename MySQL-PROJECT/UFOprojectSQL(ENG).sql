-- UFO SIGTHINGHS DATABASE-----------------------------------------------
-- -----------------------------------------------------------------------
USE ufo;
-- -----------------------------------------------------------------------

DROP TABLE IF EXISTS ufo_1;

CREATE TABLE ufo_1 like maininfo;
INSERT INTO ufo_1
SELECT * FROM maininfo;

-- The table "maininfo" is a backup from the original (IGNORE TABLE MAININFO)
-- -----------------------------------------------------------------------
SELECT * from ufo_1;
SELECT * from maininfo;
-- -----------------------------------------------------------------------

ALTER TABLE ufo_1
ADD COLUMN index_column INT AUTO_INCREMENT,
ADD PRIMARY KEY (index_column);

ALTER TABLE ufo_1 MODIFY index_column INT(11) UNIQUE NOT NULL AFTER index_;

-- In this table the index is not properly done (from a previous error when exporting from Python), 
-- we create a new index and move it so it's the first column
-- Setting index_column as PRIMARY KEY

-- -----------------------------------------------------------------------

ALTER TABLE ufo_1
DROP COLUMN index_;

-- Dropping wrong index

-- ----------------------------------------------------------------------

/*ALTER TABLE ufo_1 MODIFY index_column INT(11) UNIQUE NOT NULL AFTER index_;

ALTER TABLE ufo_1
CHANGE MyUnknownColumn index_ INT(11);
*/
-- Changing name of the column

-- ------------------------------------------------------------------------

DROP TABLE IF EXISTS Location;

CREATE TABLE Location (
location_id INT AUTO_INCREMENT PRIMARY KEY,
city_name VARCHAR(255) DEFAULT NULL,
state_province VARCHAR(255) DEFAULT NULL,
country VARCHAR(255) DEFAULT NULL,
latitude FLOAT DEFAULT NULL,
longitude FLOAT DEFAULT NULL);

INSERT INTO Location (city_name, state_province, country, latitude, longitude)
SELECT city, state, country, latitude, longitude FROM ufo_1; 

-- Creating a table named "location" with the related information, first setting the columns and then filling with the corresponding info.
-- From main table ufo_1

-- ---------------------------------------------------------------------------

ALTER TABLE ufo_1
ADD COLUMN location_id INT(11);

ALTER TABLE ufo_1
ADD CONSTRAINT fk_ufo_location
FOREIGN KEY (location_id)
REFERENCES Location(location_id);

-- Declaring column location_id from table ufo_1 as ForeignKey with a constraint

-- ------------------------------------------------------------------------------

/*ATTEMPTS TO IMPUTE DATA FROM location_id of table location to location_id of table ufo_1 (main table)
Does not execute any query, error "lost connection to sql server during query"

The objective is to add the location_id column to the ufo_1 table, which is the primary key of the location table,
Link so that it is the same info with a join based on the city info and thus relate the tables
*/

/*UPDATE ufo_1
JOIN location ON ufo_1.city = location.city_name 
AND ufo_1.state = location.state_province 
AND ufo_1.country = location.country
AND ufo_1.latitude = location.latitude
AND ufo_1.longitude = location.longitude
SET ufo_1.location_id = location.location_id;
*/

/* UPDATE ufo_1
SET location_id = (
    SELECT location_id
    FROM location
    WHERE ufo_1.city = Location.city_name
    AND ufo_1.state = Location.state_province
    AND ufo_1.country = Location.country
    LIMIT 1
);
*/

/* UPDATE ufo_1
INNER JOIN location ON ufo_1.city = location.city_name
                    AND ufo_1.state = location.state_province
                    AND ufo_1.country = location.country
                    AND ufo_1.latitude = location.latitude
                    AND ufo_1.longitude = location.longitude
SET ufo_1.location_id = location.location_id;
*/

-- -------------------------------------------------------------------------------------

-- Finally I did the mentioned changes by creating a PROCEDURE to execute batch processing (in batches of 1000 rows),
-- then I called said function:

DELIMITER //

CREATE PROCEDURE UpdateUFOWithLocation()
BEGIN
    -- Declaración variables
    DECLARE total_rows INT;
    DECLARE offset INT;
    DECLARE batch_size INT;
    
    -- Numero total de filas a actualizar (68119)
    SELECT COUNT(*) INTO total_rows FROM ufo_1;
    
    -- Tamaño del batch (mil filas cada vez)
    SET batch_size = 1000; -- Adjust the batch size as needed
    
    -- Inicializar offset
    SET offset = 0;
    
    -- Loop hasta que todas las filas esten actualizadas
    WHILE offset < total_rows DO
        -- Update a batch of rows
        UPDATE ufo_1
        JOIN (
            SELECT u.index_column, l.location_id
            FROM ufo_1 u
            JOIN Location l ON u.city = l.city_name 
                           AND u.state = l.state_province 
                           AND u.country = l.country
                           AND u.latitude = l.latitude
                           AND u.longitude = l.longitude
            LIMIT offset, batch_size
        ) AS batch_location ON ufo_1.index_column = batch_location.index_column
        SET ufo_1.location_id = batch_location.location_id;
        
        -- incrementar offset del proximo batch
        SET offset = offset + batch_size;
    END WHILE;
END //

DELIMITER ;

-- ------------------------------------------------------------------------
CALL UpdateUFOWithLocation();
-- ------------------------------------------------------------------------

DROP TABLE IF EXISTS shapes;
CREATE TABLE shapes (
    shape_id INT AUTO_INCREMENT PRIMARY KEY,
    shape_name VARCHAR(255)
);

INSERT INTO Shapes (shape_name)
SELECT  shape FROM ufo_1;

-- Create shapes table, with shape info from the ufo_1 table
-- shape_id column is PK

-- -------------------------------------------------------------------------

ALTER TABLE ufo_1
ADD COLUMN shape_id INT(11);

ALTER TABLE ufo_1
ADD CONSTRAINT fk_ufo_shapes
FOREIGN KEY (shape_id)
REFERENCES shapes(shape_id);

-- Declare location_id column of table ufo_1 as ForeignKey with constraint

-- --------------------------------------------------------------------------

-- I repeat PROCEDURE creation for the other "shapes" table:

DELIMITER //

CREATE PROCEDURE UpdateUFOWithShape()
BEGIN
    DECLARE total_rows INT;
    DECLARE offset INT;
    DECLARE batch_size INT;
    
    SELECT COUNT(*) INTO total_rows FROM ufo_1;
    SET batch_size = 1000;
    SET offset = 0;
    
    WHILE offset < total_rows DO
        UPDATE ufo_1
        JOIN (
            SELECT u.index_column, s.shape_id
            FROM ufo_1 u
            JOIN shapes s ON u.shape = s.shape_name
            LIMIT offset, batch_size
        ) AS batch_shape ON ufo_1.index_column = batch_shape.index_column
        SET ufo_1.shape_id = batch_shape.shape_id;
        
        SET offset = offset + batch_size;
    END WHILE;
END //

DELIMITER ;
-- --------------------------------------------------------------
CALL UpdateUFOWithShape();
-- --------------------------------------------------------------

CREATE TABLE ufo_0 like ufo_1;
INSERT INTO ufo_0
SELECT * FROM ufo_1;

-- Copy of ufo_1 because I am going to drop columns, for security I have a backup

-- --------------------------------------------------------------
ALTER TABLE ufo_0
DROP COLUMN city,
DROP COLUMN state,
DROP COLUMN country,
DROP COLUMN shape,
DROP COLUMN latitude,
DROP COLUMN longitude;
-- ---------------------------------------------------------------
-- I already have the 3 tables related through PK - FK
-- the ufo_0 table keeps the necessary information to avoid duplication
-- --------------------------------------------------------------

-- Change the datetime format of the date and date posted column of ufo_0 and ufo_1

UPDATE ufo_0
SET datetime = STR_TO_DATE(
    REPLACE(datetime, ' 24:00', ' 00:00'),
    '%m/%d/%Y %H:%i'
);

ALTER TABLE ufo_0
MODIFY datetime DATE;

UPDATE ufo_0
SET `date posted` = STR_TO_DATE(`date posted`, '%m/%d/%Y');
-- ------------------------------------------------------------------
UPDATE ufo_1
SET datetime = STR_TO_DATE(
    REPLACE(datetime, ' 24:00', ' 00:00'),
    '%m/%d/%Y %H:%i'
);

ALTER TABLE ufo_1
MODIFY datetime DATE;

UPDATE ufo_1
SET `date posted` = STR_TO_DATE(`date posted`, '%m/%d/%Y');


-- --------------------------------------------------------------
use ufo;  -- DATA ANALYSIS--------------------------------------
-- --------------------------------------------------------------


-- Number of sightings by City, State-Province
SELECT country, COUNT(*) AS sightings_count
FROM location
GROUP BY country;

SELECT state_province, COUNT(*) AS sightings_count
FROM location
GROUP BY state_province
ORDER BY sightings_count DESC;

SELECT city_name, COUNT(*) AS sightings_count
FROM location
GROUP BY city_name
ORDER BY sightings_count DESC
LIMIT 10;

-- Average time of sightings
SELECT AVG(`duration (seconds)`) AS avg_duration_seconds
FROM ufo_0;

-- The most reported UFO shapes
SELECT shape_name, COUNT(*) AS shape_count
FROM shapes s
JOIN ufo_0 u ON s.shape_id = u.shape_id
GROUP BY shape_name
ORDER BY shape_count DESC;
-- ---------------------------------------------------------------

-- Analysis of sightings over time
-- Year
SELECT YEAR(datetime) AS sighting_year, COUNT(*) AS num_sightings
FROM ufo_0
GROUP BY sighting_year
ORDER BY sighting_year;

SELECT YEAR(datetime) AS sighting_year, COUNT(*) AS num_sightings
FROM ufo_0
GROUP BY sighting_year
ORDER BY num_sightings DESC;

-- Month
SELECT YEAR(datetime) AS sighting_year, MONTH(datetime) AS sighting_month, COUNT(*) AS num_sightings
FROM ufo_0
GROUP BY sighting_year, sighting_month
ORDER BY sighting_year, sighting_month;

SELECT YEAR(datetime) AS sighting_year, MONTH(datetime) AS sighting_month, COUNT(*) AS num_sightings
FROM ufo_0
GROUP BY sighting_year, sighting_month
ORDER BY num_sightings DESC;

-- Day
SELECT DATE(datetime) AS sighting_date, COUNT(*) AS num_sightings
FROM ufo_0
GROUP BY sighting_date
ORDER BY sighting_date;

-- -------------------------------------------
-- Determine trends by seasonality
-- Grouping by months or quarters

SELECT MONTH(datetime) AS sighting_month, COUNT(*) AS num_sightings
FROM ufo_0
GROUP BY sighting_month
ORDER BY num_sightings DESC;

SELECT QUARTER(datetime) AS sighting_quarter, COUNT(*) AS num_sightings
FROM ufo_0
GROUP BY sighting_quarter
ORDER BY sighting_quarter;

-- Day of the week with the most sightings
SELECT DAYNAME(datetime) AS day_of_week, COUNT(*) AS num_sightings
FROM ufo_0
GROUP BY day_of_week
ORDER BY num_sightings DESC
LIMIT 1;

-- ---------------------------------------------------------
-- Identify locations with the highest number of sightings
SELECT city_name, COUNT(*) AS num_sightings
FROM location l
JOIN ufo_0 u ON l.location_id = u.location_id
GROUP BY city_name
ORDER BY num_sightings DESC;

SELECT country, COUNT(*) AS num_sightings
FROM location l
JOIN ufo_0 u ON l.location_id = u.location_id
GROUP BY country
ORDER BY num_sightings DESC;
-- --------------------------------------------------------------------
-- Most reported UFO shapes according to location

SELECT s.shape_name, l.country, COUNT(*) AS shape_count
FROM shapes s
JOIN ufo_0 u ON s.shape_id = u.shape_id
JOIN location l ON u.location_id = l.location_id
GROUP BY s.shape_name, l.country
ORDER BY s.shape_name, shape_count DESC;
-- ------------------------------------------------------------------------
-- Window function. Ranking of sightings based on their duration

SELECT index_column, datetime, `duration (seconds)`,
       ROW_NUMBER() OVER (ORDER BY `duration (seconds)` DESC) AS duration_rank
FROM ufo_0
ORDER BY `duration (seconds)` DESC
LIMIT 3;

-- Now I use a subquery to also (based on the previous one), including the total number of sightings for each "shape"

SELECT shape_name, AVG(`duration (seconds)`) AS avg_duration,
       (SELECT COUNT(*)
        FROM ufo_0 u
        JOIN shapes s ON u.shape_id = s.shape_id
        WHERE s.shape_name = shapes.shape_name) AS num_sightings
FROM ufo_0 u
JOIN shapes ON u.shape_id = shapes.shape_id
GROUP BY shape_name;
-- -----------------------------------------------------------------------------------------


