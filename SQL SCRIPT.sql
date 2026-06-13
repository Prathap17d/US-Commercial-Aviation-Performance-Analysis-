#database creation:

create database airline_performance;
use airline_performance;

#table creation:
create table airlines(
IATA_CODE varchar(10) primary key,
AIRLINE varchar(100) not null
);
  
 create table airports(
 IATA_CODE varchar(10) primary key, 
 AIRPORT varchar(100), 
 CITY varchar(100),
 STATE varchar(55),
 COUNTRY varchar(55),
 LATITUDE decimal(9,6),
 LONGITUDE decimal(9,6)
 );
 
   
 create table flights (
 YEAR INT,
 MONTH INT,
 DAY INT,
 DAY_OF_WEEK INT,
 AIRLINE VARCHAR(10),
 FLIGHT_NUMBER INT,
 TAIL_NUMBER VARCHAR(20),
 ORIGIN_AIRPORT VARCHAR(10),
 DESTINATION_AIRPORT VARCHAR(10),
 SCHEDULED_DEPARTURE VARCHAR(10), 
 DEPARTURE_TIME VARCHAR(10),
 DEPARTURE_DELAY INT,
 TAXI_OUT INT,
 WHEELS_OFF VARCHAR(10),
 SCHEDULED_TIME INT,
 ELAPSED_TIME INT,
 AIR_TIME INT,
 DISTANCE INT,
 WHEELS_ON VARCHAR(10),
 TAXI_IN INT,
 SCHEDULED_ARRIVAL VARCHAR(10),
 ARRIVAL_TIME VARCHAR(10),
 ARRIVAL_DELAY INT,
 DIVERTED INT,
 CANCELLED INT,
 CANCELLATION_REASON VARCHAR(5),
 AIR_SYSTEM_DELAY INT,
 SECURITY_DELAY INT,
 AIRLINE_DELAY INT,
 LATE_AIRCRAFT_DELAY INT,
 WEATHER_DELAY INT
);

-- data ingestion
-- 1. Load Airlines
load data infile 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/airlines.csv'
into table airlines
fields terminated by ',' 
enclosed by '"'
lines terminated by '\n'
ignore 1 lines;

select * from airlines;
select count(*) from airlines;


-- 2. Load Airports
load data infile 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/airports.csv' 
into table airports
fields terminated by ',' 
enclosed by '"'
lines terminated by '\n'
ignore 1 lines
-- Read the row data into temporary variables first
(IATA_CODE, AIRPORT, CITY, STATE, COUNTRY, @v_latitude, @v_longitude)
-- Apply logic: If the variable is empty, set it to NULL,else load the number
SET
LATITUDE = IF(@v_latitude = '', null, @v_latitude),
LONGITUDE = IF(@v_longitude = '', null, @v_longitude);

select * from airports;
select count(*) from airports;

-- 3. Load flights:
load data infile 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/flights.csv' 
into table flights
fields terminated by ',' 
enclosed by '"'
lines terminated by '\n'
ignore 1 lines
(YEAR, MONTH, DAY, DAY_OF_WEEK, AIRLINE, FLIGHT_NUMBER, TAIL_NUMBER, 
 ORIGIN_AIRPORT, DESTINATION_AIRPORT, SCHEDULED_DEPARTURE, DEPARTURE_TIME, 
 @v_DEPARTURE_DELAY, @v_TAXI_OUT, @v_WHEELS_OFF, @v_SCHEDULED_TIME, 
 @v_ELAPSED_TIME, @v_AIR_TIME, @v_DISTANCE, @v_WHEELS_ON, @v_TAXI_IN, 
 SCHEDULED_ARRIVAL, ARRIVAL_TIME, @v_ARRIVAL_DELAY, DIVERTED, CANCELLED, 
 @v_CANCELLATION_REASON, @v_AIR_SYSTEM_DELAY, @v_SECURITY_DELAY, 
 @v_AIRLINE_DELAY, @v_LATE_AIRCRAFT_DELAY, @v_WEATHER_DELAY)
SET 
DEPARTURE_DELAY     = IF(@v_DEPARTURE_DELAY = '', 0, @v_DEPARTURE_DELAY),
TAXI_OUT            = IF(@v_TAXI_OUT = '', 0, @v_TAXI_OUT),
WHEELS_OFF          = IF(@v_WHEELS_OFF = '', null, @v_WHEELS_OFF),
SCHEDULED_TIME      = IF(@v_SCHEDULED_TIME = '', 0, @v_SCHEDULED_TIME),
ELAPSED_TIME        = IF(@v_ELAPSED_TIME = '', 0, @v_ELAPSED_TIME),
AIR_TIME            = IF(@v_AIR_TIME = '', 0, @v_AIR_TIME),
DISTANCE            = IF(@v_DISTANCE = '', 0, @v_DISTANCE),
WHEELS_ON           = IF(@v_WHEELS_ON = '', null, @v_WHEELS_ON),
TAXI_IN             = IF(@v_TAXI_IN = '', 0, @v_TAXI_IN),
ARRIVAL_DELAY       = IF(@v_ARRIVAL_DELAY = '', 0, @v_ARRIVAL_DELAY),
CANCELLATION_REASON = IF(@v_CANCELLATION_REASON = '', null, @v_CANCELLATION_REASON),
AIR_SYSTEM_DELAY    = IF(@v_AIR_SYSTEM_DELAY = '', 0, @v_AIR_SYSTEM_DELAY),
SECURITY_DELAY      = IF(@v_SECURITY_DELAY = '', 0, @v_SECURITY_DELAY),
AIRLINE_DELAY       = IF(@v_AIRLINE_DELAY = '', 0, @v_AIRLINE_DELAY),
LATE_AIRCRAFT_DELAY = IF(@v_LATE_AIRCRAFT_DELAY = '', 0, @v_LATE_AIRCRAFT_DELAY),
WEATHER_DELAY       = IF(@v_WEATHER_DELAY = '', 0, @v_WEATHER_DELAY);
    

USE airline_performance;

CREATE OR REPLACE VIEW v_analytical_flights AS
SELECT 
f.YEAR,
f.MONTH,
f.DAY,
f.DAY_OF_WEEK,
f.FLIGHT_NUMBER,
f.TAIL_NUMBER,
f.DISTANCE,
f.AIRLINE as airline_code,
al.AIRLINE as airline_name,
    
-- 3. Origin Airport Details 
f.ORIGIN_AIRPORT as origin_airport_code,
COALESCE(org.AIRPORT, f.ORIGIN_AIRPORT) as origin_airport_name, 
COALESCE(org.CITY, 'Unknown City') as origin_city,             
COALESCE(org.STATE, 'NA') as origin_state,                     
org.LATITUDE as origin_latitude,
org.LONGITUDE as origin_longitude,
    
-- 4. Destination Airport Details 
f.DESTINATION_AIRPORT as dest_airport_code,
COALESCE(dst.AIRPORT, f.DESTINATION_AIRPORT) as dest_airport_name, 
COALESCE(dst.CITY, 'Unknown City') as dest_city,                 
COALESCE(dst.STATE, 'NA') as dest_state,                         
dst.LATITUDE as dest_latitude,
dst.LONGITUDE as dest_longitude,
    
-- 5. Operational Clean Datetime Fields
str_to_date(
     concat(f.YEAR, '-', f.MONTH, '-', f.DAY, ' ', LPAD(f.SCHEDULED_DEPARTURE, 4, '0')), 
        '%Y-%c-%e %H%i'
    ) as scheduled_departure_datetime,

f.DEPARTURE_DELAY,
f.TAXI_OUT,
f.AIR_TIME,
f.TAXI_IN,
f.ARRIVAL_DELAY,
f.AIR_SYSTEM_DELAY,
f.SECURITY_DELAY,
f.AIRLINE_DELAY,
f.LATE_AIRCRAFT_DELAY,
f.WEATHER_DELAY,
f.DIVERTED,
f.CANCELLED,
f.CANCELLATION_REASON AS cancellation_code,
    
-- Enriched Data: Decoded Cancellation Reason Description
case f.CANCELLATION_REASON
     when 'A' then 'Carrier/Airline'
     when 'B' then 'Weather'
     when 'C' then 'National Air System (NAS)'
     when 'D' then 'Security'
      else 'Not Cancelled'
end as cancellation_reason_desc

from flights f
left join airlines al on f.AIRLINE = al.IATA_CODE
left join airports org on f.ORIGIN_AIRPORT = org.IATA_CODE
left join airports dst on f.DESTINATION_AIRPORT = dst.IATA_CODE;

select 
scheduled_departure_datetime, 
airline_name, 
origin_airport_name, 
dest_airport_name, 
cancellation_reason_desc 
from v_analytical_flights 
limit 50;

-- Exploratory Data Analysis (EDA) & KPI Definition 

-- Overall flight volumes, cancellations (total, by reason), and diversions. 
select
count(*) as total_flights,
count(
case when cancellation_reason_desc!="Not Cancelled" then 1 end)
    as total_cancellation,
sum(DIVERTED) as total_diversions from v_analytical_flights;
    
-- Basic statistics for departure and arrival delays (average, median, min, max).
select
-- DEPARTURE
round(avg(DEPARTURE_DELAY), 2) as avg_departure_delay,
min(DEPARTURE_DELAY) as min_departure_delay, 
max(DEPARTURE_DELAY) as max_departure_delay,
-- ARRIVAL    
round(avg(ARRIVAL_DELAY), 2) as avg_arrival_delay,
min(ARRIVAL_DELAY) as min_arrival_delay,
max(ARRIVAL_DELAY) as max_arrival_delay
from v_analytical_flights;

-- The distribution of different types of delays (airline, weather, NAS, etc.).
select
sum(AIRLINE_DELAY) as airline,
sum(WEATHER_DELAY) as weather,
sum(AIR_SYSTEM_DELAY) as nas,
sum(LATE_AIRCRAFT_DELAY) as late_plane,
sum(SECURITY_DELAY) as security
from v_analytical_flights

-- CORE KPI CALCULATION:
-- On-Time Performance (OTP) Rate (%):
select 
round((count(case when ARRIVAL_DELAY <= 15 and cancellation_reason_desc = 'Not Cancelled' then 1 end) / count(*)) * 100, 2) as otp_rate_pct 
from v_analytical_flights;

-- Average Delays in arrival and departure: 
select 
round(avg(DEPARTURE_DELAY), 2) as KPI_avg_departure_delay_mins,
round(avg(ARRIVAL_DELAY), 2) as KPI_avg_arrival_delay_mins
from v_analytical_flights;

-- Cancellation Rate (%)
select 
round((count(case when cancellation_reason_desc!="Not Cancelled" then 1 end))/(count(*))*100,2) as cancellation_rate_pcnt
from v_analytical_flights; 

-- percentage distribution of different types of delays:
with delay_totals as (
select
sum(AIRLINE_DELAY) as airline,
sum(WEATHER_DELAY) as weather,
sum(AIR_SYSTEM_DELAY) as nas,
sum(LATE_AIRCRAFT_DELAY) as late_plane,
sum(SECURITY_DELAY) as security,
-- Calculate the grand total 
(sum(AIRLINE_DELAY) + sum(WEATHER_DELAY) + sum(AIR_SYSTEM_DELAY) + 
sum(LATE_AIRCRAFT_DELAY) + sum(SECURITY_DELAY)) as grand_total
from v_analytical_flights
)
-- Percentage contribution of each delay type
select
round((airline / grand_total) * 100, 2) as airline_contrib_pct,
round((weather / grand_total) * 100, 2) as weather_contrib_pct,
round((nas / grand_total) * 100, 2) as nas_contrib_pct,
round((late_plane / grand_total) * 100, 2) as late_aircraft_contrib_pct,
round((security / grand_total) * 100, 2) as security_contrib_pct
from delay_totals;
    
-- no of flights operated by time of day;    
select 
case 
    when time(scheduled_departure_datetime) between '00:00:00' and '05:59:59' then '1. Late Night (12am-6am)'
    when time(scheduled_departure_datetime) between '06:00:00' and '11:59:59' then '2. Morning (6am-12pm)'
    when time(scheduled_departure_datetime) between '12:00:00' and '17:59:59' then '3. Afternoon (12pm-6pm)'
    else '4. Evening/Night (6pm-12am)'
end as  time_of_day_bucket,
count(*) as total_flights
from  v_analytical_flights
group by 1
order by total_flights desc ;


-- Perform initial aggregations to understand how these KPIs vary by:
-- KPIs by Airline Carrier
select airline_name,
count(*) as total_flights,
round((count(case when cancellation_reason_desc != 'Not Cancelled' then 1 end)/count(*))*100,2) as cancellation_rate_pcnt,
round(avg(ARRIVAL_DELAY),2) as avg_arrival_daley,
round((count(case when ARRIVAL_DELAY <=15 and cancellation_reason_desc = 'Not Cancelled' then 1 end)/count(*)) * 100,2) as airline_otp_rate
from v_analytical_flights
group by airline_name
order by  airline_otp_rate limit 10; 

-- Slicing KPIs by Top 10 best & Worst origin and destination Airports
-- origin airport
select 
origin_airport_name,
count(*) as total_flights,
round(avg(DEPARTURE_DELAY),2) as avg_deprt_delay
from v_analytical_flights
group by origin_airport_name
having total_flights >10000
order by avg_deprt_delay asc limit 10;

select 
origin_airport_name,
count(*) as total_flights,
round(avg(DEPARTURE_DELAY),2) as avg_depart_delay
from v_analytical_flights
group by origin_airport_name
having total_flights>10000
order by avg_depart_delay desc limit 10;


-- destination airports
select dest_airport_name,
count(*) as total_flights,
round(avg(arrival_delay),2) as avg_arrival_delay
from  v_analytical_flights
group by dest_airport_name
having total_flights>=10000
order by avg_arrival_delay asc limit 10;

 
select dest_airport_name,
count(*) as total_flights,
round(avg(arrival_delay),2) as avg_arrival_delay
from v_analytical_flights
group by dest_airport_name
having total_flights>=10000
order by avg_ariival_delay desc limit 10


select
month as flight_month,
count(*) as total_flight,
round(avg(DEPARTURE_DELAY),2) as avg_depart_delay_min,
round(avg(arrival_delay),2) as avg_arrival_delay_min,
round((count(case when DEPARTURE_DELAY<=15 and cancelled=0 then 1 end)*100.0)/count(*),2) as otp_rate_pcnt, 
round(((count(case when cancellation_reason_desc != 'Not Cancelled' then 1 end))/count(*))*100,2) as can_rate_pcnt
from v_analytical_flights
group by month
order by month asc;

select
day_of_week as day,
count(*) as total_flight,
round(avg(DEPARTURE_DELAY),2) as avg_depart_delay_min,
round(avg(arrival_delay),2) as avg_arrival_delay_min,
round((count(case when DEPARTURE_DELAY<=15 and cancelled=0 then 1 end)*100.0)/count(*),2) as otp_rate_pcnt, 
round(((count(case when cancellation_reason_desc != 'Not Cancelled' then 1 end))/count(*))*100,2) as can_rate_pcnt
from v_analytical_flights
group by day
order by day asc;

select
hour(scheduled_departure_datetime) as time,
count(*) as total_flight,
round(avg(DEPARTURE_DELAY),2) as avg_depart_delay_min,
round(avg(arrival_delay),2) as avg_arrival_delay_min,
round((count(case when DEPARTURE_DELAY<=15 and cancelled=0 then 1 end)*100.0)/count(*),2) as otp_rate_pcnt, 
round(((count(case when cancellation_reason_desc != 'Not Cancelled' then 1 end))/count(*))*100,2) as can_rate_pcnt
from v_analytical_flights
group by time
order by total_flight desc;


















