create database QuickBite_Analytics;
use QuickBite_Analytics;

select * from dim_customer;
select * from dim_delivery_agent;
select * from dim_restaurant;
select * from fact_orders;

alter table dim_customer
rename column ï»¿CustomerID to CustomerID;
alter table dim_delivery_agent
rename column ï»¿AgentID to AgentID;
alter table dim_restaurant
rename column ï»¿RestaurantID to RestaurantID;
alter table fact_orders
rename column ï»¿OrderID to OrderID;

alter table dim_customer
modify CustomerID int primary key;
set sql_safe_updates = 0;
update dim_customer
set Member_Since = str_to_date(Member_Since, '%d-%m-%Y');
set sql_safe_updates = 1;

alter table dim_delivery_agent
modify AgentID int primary key;

alter table dim_restaurant
modify RestaurantID int primary key;

alter table fact_orders
modify OrderID int primary key;

alter table fact_orders
add constraint fo_customer
foreign key(CustomerID) references dim_customer(CustomerID);

alter table fact_orders
add constraint fo_restaurant
foreign key(RestaurantID) references dim_restaurant(RestaurantID);

alter table fact_orders
add constraint fo_agent
foreign key(AgentID) references dim_delivery_agent(AgentID);

set sql_safe_updates = 0;
update fact_orders
set Order_Date = str_to_date(Order_Date, '%d-%m-%Y');
set sql_safe_updates = 1;

select r.City, count(f.OrderID) as Total_Order_Count,
sum(f.Order_Amount) as Total_Revenue
from fact_orders f
join dim_restaurant r
on r.RestaurantID = f.RestaurantID
where Year(f.Order_Date) = 2022
group by r.City
having Total_Order_Count >= 1
order by Total_Revenue desc;

select r.Cuisine_Type,
sum(f.Order_Amount) as Total_Revenue,
count(f.OrderID) as Total_Order_Count
from fact_orders f
join dim_restaurant r
on r.RestaurantID = f.RestaurantID
group by r.Cuisine_Type
order by Total_Revenue desc limit 1;

select r.Restaurant_Name, count(f.OrderID) as Total_Order_Count,
sum(f.Order_Amount) as Total_Revenue,
avg(f.Order_Amount) as Average_Order_Value,
dense_rank() over(order by sum(f.Order_Amount) desc) as Ranked_Revenue
from fact_orders f
join dim_restaurant r
on r.RestaurantID = f.RestaurantID
group by r.RestaurantID, r.Restaurant_Name;

select r.Restaurant_Name, r.Cuisine_Type,
max(f.Order_Amount) as Highest_Order_Amount
from fact_orders f
join dim_restaurant r
on f.RestaurantID = r.RestaurantID
group by r.RestaurantID, r.Restaurant_Name, r.Cuisine_Type
order by Highest_Order_Amount desc;

select f.CustomerID, max(r.City) as City,
count(f.OrderID) as Total_Order_Count,
sum(f.Order_Amount) as Lifetime_Spend
from fact_orders f
join dim_restaurant r
on r.RestaurantID = f.RestaurantID
group by f.CustomerID
order by Lifetime_Spend desc limit 10;

select AgentID, count(OrderID) as Total_Deliveries,
avg(Delivery_Minutes) as Average_Delivery_Time
from fact_orders f
group by AgentID
order by Total_Deliveries desc;

select d.City, avg(f.Delivery_Minutes) as Average_Delivery_Time
from fact_orders f
join dim_delivery_agent d
on f.AgentID = d.AgentID
group by d.City
order by Average_Delivery_Time asc;

select r.RestaurantID, r.Restaurant_Name
from fact_orders f
join dim_restaurant r
on f.RestaurantID = r.RestaurantID
group by r.RestaurantID, r.Restaurant_Name
having
count(case when Year(f.Order_Date) = 2023 then 1 end) > 0 and
count(case when Year(f.Order_Date) = 2022 then 1 end) = 0; 

select c.CustomerID, c.Customer_Name, count(f.OrderID) as Number_Of_Orders,
avg(f.Order_Amount) as Average_Order_Value
from fact_orders f
join dim_customer c
on c.CustomerID = f.CustomerID
group by c.CustomerID, c.Customer_Name
having Number_Of_Orders > 5 and
Average_Order_Value > 600;

select Year(Order_Date) as Year, sum(Order_Amount) as Total_Revenue, 
count(OrderID) as Total_Orders,
avg(Order_Amount) as Average_Order_Value
from fact_orders
where Year(Order_Date) in (2020, 2021, 2022, 2023)
group by Year(Order_Date)
order by Year asc;

with RestaurantsRank as (
select r.Cuisine_Type, r.Restaurant_Name,
avg(f.Rating) as Average_Rating,
count(f.OrderID) as Total_Orders,
row_number() over(partition by r.Cuisine_Type
order by avg(f.Rating) desc) as Ranking
from fact_orders f
join dim_restaurant r
on f.RestaurantID = r.RestaurantID
group by r.Cuisine_Type, r.Restaurant_Name)
select Cuisine_Type, Restaurant_Name,
Average_Rating, Total_Orders
from RestaurantsRank
where Ranking = 1;

with PaymentSection as (
select Payment_Mode, count(OrderID) as Transaction_Count,
sum(Order_Amount) as Total_Revenue
from fact_orders
group by Payment_Mode)
select Payment_Mode, Transaction_Count, Total_Revenue,
(Total_Revenue * 100.0)/(select sum(Total_Revenue) from PaymentSection) as
Percentage_Revenue_Share
from PaymentSection;

with AnnualRevenue as (
select r.RestaurantID, r.Restaurant_Name,
sum(case when Year(f.Order_Date) = 2020 then f.Order_Amount else 0 end) as Revenue_2020,
sum(case when Year(f.Order_Date) = 2021 then f.Order_Amount else 0 end) as Revenue_2021
from fact_orders f
join dim_restaurant r
on f.RestaurantID = r.RestaurantID
group by r.RestaurantID, r.Restaurant_Name),
AnnualGrowth as (
select Restaurant_Name, Revenue_2020, Revenue_2021,
((Revenue_2021 - Revenue_2020) * 100.0) / nullif(Revenue_2020, 0) as
Percentage_Growth
from AnnualRevenue
where Revenue_2020 > 0)
select Restaurant_Name, Revenue_2020, Revenue_2021, Percentage_Growth
from AnnualGrowth
order by Percentage_Growth desc limit 1;

with TopCustomers as (
select c.CustomerID, c.Customer_Name,
count(f.OrderID) as Total_Orders
from fact_orders f
join dim_customer c
on f.CustomerID = c.CustomerID
group by c.CustomerID, c.Customer_Name
order by Total_Orders desc limit 5)
select tc.Customer_Name, Year(f.Order_Date) as Order_Year,
count(f.OrderID) as Orders_Count,
sum(f.Order_Amount) as Total_Revenue
from fact_orders f
join TopCustomers tc
on f.CustomerID = tc.CustomerID
where Year(f.Order_Date) in (2020, 2021, 2022, 2023)
group by tc.Customer_Name, Order_Year
order by tc.Customer_Name, Order_Year;

with DeliveryAgents as (
select d.City,
count(distinct d.AgentID) as Number_Of_Delivery_Agents,
count(f.OrderID) as Total_Orders
from fact_orders f
join dim_delivery_agent d
on f.AgentID = d.AgentID
group by d.City)
select City, Number_Of_Delivery_Agents, Total_Orders,
round(Total_Orders * 1.0 / nullif(Number_Of_Delivery_Agents, 0), 2) as
Average_Order_Per_Agent
from DeliveryAgents
order by Total_Orders desc;

select Customer_Name, Email,
count(distinct CustomerID) as Total_Distinct_CustomerIDs,
group_concat(CustomerID) as Assigned_CustomerID
from dim_customer
group by Customer_Name, Email
having count(distinct CustomerID) > 1;

select f.AgentID, d.Agent_Name,
date(f.Order_Date) as Order_Date,
count(f.OrderID) as Total_Orders
from fact_orders f
join dim_delivery_agent d
on f.AgentID = d.AgentID
group by f.AgentID, d.Agent_Name, Order_Date
having Total_Orders > 50
order by Total_Orders desc;

select OrderID, CustomerID, RestaurantID, Order_Amount
from fact_orders
where Order_Amount > 3 * (select avg(Order_Amount) from fact_orders)
order by Order_Amount desc;

select f.OrderID, r.Restaurant_Name, d.Agent_Name, r.City, f.Order_Date,
f.Delivery_Minutes
from fact_orders f
join dim_restaurant r
on f.RestaurantID = r.RestaurantID
join dim_delivery_agent d
on f.AgentID = d.AgentID
where f.Delivery_Minutes > 180
order by f.Delivery_Minutes desc;

select f.OrderID, f.CustomerID, f.Order_Date,
c.Member_Since
from fact_orders f
join dim_customer c
on f.CustomerID = c.CustomerID
where f.Order_Date < c.Member_Since;

with DuplicateCustomers as (
select c1.CustomerID as Duplicate_ID, c2.CustomerID as Original_ID, c1.Customer_Name, c1.Email
from dim_customer c1
join dim_customer c2 
on c1.Customer_Name = c2.Customer_Name 
and c1.Email = c2.Email 
and c1.CustomerID < c2.CustomerID)
select f.OrderID, f.Order_Date, f.Order_Amount, d.Original_ID, d.Duplicate_ID,
d.Customer_Name, d.Email
from fact_orders f
join DuplicateCustomers d
on f.CustomerID = d.Duplicate_ID
order by d.Duplicate_ID, f.OrderID;
























