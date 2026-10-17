create database Cellphones_Information;
use Cellphones_Information;

select * from dim_customer;
select * from dim_date;
select * from dim_location;
select * from dim_manufacturer;
select * from dim_model;
select * from fact_transactions;

alter table dim_customer
rename column ï»¿IdCustomer to IdCustomer;
alter table dim_date
rename column ï»¿Date to Date;
alter table dim_location
rename column ï»¿IdLocation to IdLocation;
alter table dim_manufacturer
rename column ï»¿IdManufacturer to IdManufacturer;
alter table dim_model
rename column ï»¿IdModel to IdModel;
alter table fact_transactions
rename column ï»¿IdModel to IdModel;

alter table dim_customer
modify IdCustomer int auto_increment primary key;

set sql_safe_updates = 0;
update dim_date
set Date = str_to_date(Date, '%d-%m-%Y');
alter table dim_date
modify Date date primary key;
set sql_safe_updates = 1;

set sql_safe_updates = 0;
update fact_transactions
set Date = str_to_date(Date, '%d-%m-%Y');
set sql_safe_updates = 1;

alter table dim_location
modify IdLocation int auto_increment primary key;

alter table dim_manufacturer
modify IdManufacturer int primary key;

alter table dim_model
modify IdModel int primary key;

alter table fact_transactions
add constraint ft_model
foreign key(IdModel) references dim_model(IdModel);

alter table fact_transactions
add constraint ft_customer
foreign key(IdCustomer) references dim_customer(IdCustomer);

alter table fact_transactions
add constraint ft_location
foreign key(IdLocation) references dim_location(IdLocation);

select distinct l.State
from fact_transactions t
join dim_location l
on l.IdLocation = t.IdLocation
join dim_date d
on t.Date = d.Date
where year(d.Date) >= 2005;

select l.Country, l.State,
sum(t.Quantity) as Total_Units_Sold
from fact_transactions t
join dim_location l
on t.IdLocation = l.IdLocation
join dim_model m
on t.IdModel = m.IdModel
join dim_manufacturer man
on m.IdManufacturer = man.IdManufacturer
where man.Manufacturer_Name = 'Samsung' and
l.Country = 'US'
group by l.country, l.state
order by Total_Units_Sold desc limit 1;

select m.Model_Name, l.Zipcode, l.State,
count(*) as Number_Of_Transactions
from fact_transactions t
join dim_location l
on t.IdLocation = l.IdLocation
join dim_model m
on t.IdModel = m.IdModel
group by m.Model_Name, l.Zipcode, l.State
order by m.Model_Name, Number_Of_Transactions desc;

select Model_Name, Unit_Price
from dim_model
order by Unit_Price asc limit 1; 

with Top5Manufacturers as (
select man.IdManufacturer, man.Manufacturer_Name, sum(t.Quantity) as Total_Units_Sold
from fact_transactions t
join dim_model m
on t.IdModel = m.IdModel
join dim_manufacturer man
on m.IdManufacturer = man.IdManufacturer
group by man.IdManufacturer, man.Manufacturer_Name
order by Total_Units_Sold desc limit 5)
select tm.Manufacturer_Name, m.Model_Name,
avg(t.TotalPrice/t.Quantity) as Average_Selling_Price
from fact_transactions t
join dim_model m
on t.IdModel = m.IdModel
join Top5Manufacturers tm
on m.IdManufacturer = tm.IdManufacturer 
group by tm.Manufacturer_Name, m.Model_Name;

select c.Customer_Name, avg(t.TotalPrice) as Average_Spend
from fact_transactions t
join dim_customer c
on c.IdCustomer = t.IdCustomer
join dim_date d
on t.Date = d.Date
where year(d.Date) = 2009
group by c.Customer_Name
having Average_Spend > 500
order by Average_Spend desc;

with RankModels as (
select m.Model_Name, d.Year as Year_Of_Sale,
sum(t.Quantity) as Total_Units_Sold,
dense_rank() over(partition by d.Year
order by sum(t.Quantity) desc) as Model_Rank
from fact_transactions t
join dim_model m
on m.IdModel = t.IdModel
join dim_date d
on t.Date = d.Date
where d.Year in ('2008', '2009', '2010')
group by m.Model_Name, Year_Of_Sale)
select Model_Name from RankModels
where Model_Rank <= 5
group by Model_Name
having count(distinct Year_Of_Sale) = 3;

with RankedManufacturers as (
select d.Year as Year_Of_Sale, man.Manufacturer_Name,
sum(t.TotalPrice) as Total_Sale,
dense_rank() over(partition by d.Year 
order by sum(t.TotalPrice) desc) as Sales_Rank
from fact_transactions t
join dim_model m
on t.IdModel = m.IdModel
join dim_manufacturer man
on m.IdManufacturer = man.IdManufacturer
join dim_date d
on t.Date = d.Date
where d.Year in ('2009', '2010')
group by Year_Of_Sale, man.Manufacturer_Name)
select Year_Of_Sale, Manufacturer_Name, Total_Sale
from RankedManufacturers
where Sales_Rank = 2; 

select man.Manufacturer_Name
from fact_transactions t
join dim_model m
on t.IdModel = m.IdModel
join dim_manufacturer man
on m.IdManufacturer = man.IdManufacturer
join dim_date d
on t.Date = d.Date
where d.Year in ('2009', '2010')
group by man.Manufacturer_Name
having count(case when d.Year = 2010 then 1 end) > 0
and count(case when d.Year = 2009 then 1 end) = 0;

with Top100Customers as (
select c.IdCustomer, c.Customer_Name,
sum(t.TotalPrice) as Total_Spend
from fact_transactions t
join dim_customer c
on t.IdCustomer = c.IdCustomer
group by c.IdCustomer, c.Customer_Name
order by Total_Spend desc limit 100),
AnnualCustomers as (
select tc.Customer_Name, d.Year as Year_Of_Sale,
avg(t.TotalPrice) as Average_Spend,
avg(t.Quantity) as Average_Quantity
from fact_transactions t
join Top100Customers tc
on t.IdCustomer = tc.IdCustomer
join dim_date d
on t.Date = d.Date
group by tc.Customer_Name, Year_Of_Sale)
select Customer_Name, Year_Of_Sale, Average_Spend,
Average_Quantity,
lag(Average_Spend, 1) over(partition by Customer_Name
order by Year_Of_Sale) as Previous_Year_Average_Spend,
case
when lag(Average_Spend, 1) over(partition by Customer_Name
order by Year_Of_Sale) is null then null
else
((Average_Spend - lag(Average_Spend, 1) over(partition by Customer_Name
order by Year_Of_Sale)) /
lag(Average_Spend, 1) over(partition by Customer_Name
order by Year_Of_Sale)) * 100
end as Change_In_Percentage_Spend
from AnnualCustomers
order by Customer_Name, Year_Of_Sale;









