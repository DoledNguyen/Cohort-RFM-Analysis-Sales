-- Kiểm tra dữ liệu
SELECT * FROM dbo.customers
SELECT * FROM dbo.orders
SELECT * FROM dbo.products
SELECT * FROM dbo.sales
-- Kiểm tra giá trị duy nhất 
SELECT DISTINCT gender FROM dbo.customers -- 8 unique
SELECT DISTINCT [state] FROM dbo.customers -- 8 unique
SELECT DISTINCT product_type FROM dbo.products --3 unique
SELECT DISTINCT size FROM dbo.products -- 5 unique
SELECT DISTINCT colour FROM dbo.products -- 7 unique

---- ANALYSIS
-- Tạo bảng fact từ 2 bảng customers và products, tạo cột sales 
DROP TABLE IF EXISTS #fact_table
;WITH fact_table as 
(	
	SELECT dbo.customers.[customer_id],customer_name,gender,age,home_address
	,zip_code,city,state,country,order_id,payment,order_date,delivery_date,product_ID
	,product_type,product_name,size,colour,price,quantity,description
	,(price*quantity) sales

	FROM dbo.customers 
	JOIN dbo.orders ON dbo.orders.customer_id = dbo.customers.[customer_id]
	JOIN dbo.products ON dbo.products.[product_id] = dbo.customers.[customer_id]
)
SELECT * 
INTO #fact_table
FROM fact_table

--Doanh số bán hàng theo từng tuần
SELECT MONTH(order_date) [month]
,DATEPART(week,order_date) [week]
,SUM(sales) sales
FROM #fact_table
GROUP BY MONTH(order_date),DATEPART(week,order_date)
ORDER BY MONTH(order_date),DATEPART(week,order_date)

--Doanh số bán hàng theo từng tháng 
SELECT MONTH(order_date) [month]
,SUM(sales) Revenue
FROM #fact_table
GROUP BY MONTH(order_date)
ORDER BY 1

--Time Series Analysis
--Doanh số của Jacket,Shirt,Trousers dóng góp theo từng tháng 
SELECT MONTH(order_date) [month],product_type,COUNT(order_id) number_purchases
FROM #fact_table
GROUP BY MONTH(order_date),product_type
ORDER BY MONTH(order_date),product_type
--Tỉ lệ 3 sản phẩm Jacket,Shirt,Trousers. Chiếm bao nhiêu trong tổng số doanh thu mỗi tháng
WITH purchase_table as (
SELECT MONTH(order_date) [month]
,product_type
,COUNT(order_id) number_purchases
FROM #fact_table
GROUP BY MONTH(order_date),product_type
--ORDER BY MONTH(order_date),product_type
)
,Pivot_table as (
SELECT 
[month], Jacket as Jacket_trans, Shirt as Shirt_trans,Trousers as Trousers_trans
FROM (
  SELECT
   [month]
   ,product_type
   ,number_purchases
  FROM purchase_table
) StudentResults
PIVOT (
  SUM(number_purchases)
  FOR product_type
  IN (Jacket,Shirt,Trousers)
) AS PivotTable
)
SELECT *
,Jacket_trans + Shirt_trans + Trousers_trans as total_trans
,FORMAT(Jacket_trans*1.0 /(Jacket_trans + Shirt_trans + Trousers_trans),'p') Jacket_pct
,FORMAT(Shirt_trans*1.0 /(Jacket_trans + Shirt_trans + Trousers_trans),'p') Shirt_pct
,FORMAT(Trousers_trans*1.0 /(Jacket_trans + Shirt_trans + Trousers_trans),'p') Trousers_pct
FROM Pivot_table

--Doanh số bán hàng theo từng loại sản phẩm
SELECT product_type 
,SUM(sales) Revenue
FROM  #fact_table
GROUP BY product_type
ORDER BY 2 DESC

--Doanh số bán hàng theo giới tính  
SELECT gender 
,SUM(sales) Revenue
FROM  #fact_table
GROUP BY gender
ORDER BY 2 DESC

--Doanh số bán hàng theo màu sắc sản phẩm
SELECT colour 
,SUM(sales) Revenue
FROM  #fact_table
GROUP BY colour
ORDER BY 2 DESC

--Ðộ tuổi khách hàng phổ biến 
SELECT AVG(age) avg_age
FROM #fact_table --> Ða số khách hàng đến từ độ tuổi thanh niên và trung niên

--Thời gian trung bình kể từ khi đặt hàng đến khi giao hàng 
SELECT 
AVG(DATEDIFF(DD,order_date,delivery_date)) avg_date
FROM #fact_table --> khoảng 14 ngày 

--Doanh số của từng sản phẩm trong 3 loại Jacket ,Shirt, Trousers.Từng sản phẩm đó đóng góp bao nhiêu phần trăm doanh số ?
WITH pro_table as (
SELECT product_name, SUM(sales) sales
FROM #fact_table
WHERE product_type = 'Jacket' -- Jacket/Shirt/Trousers
GROUP BY product_name 
)
SELECT product_name,sales
,SUM(sales)OVER() total_sales
,FORMAT(sales/SUM(Sales)OVER(),'p') pct_sales
FROM  pro_table

--Doanh số bán hàng phân loại theo nhóm tuổi 
WITH age_table as (
SELECT customer_name,gender,age,product_type,product_name,size,colour,sales,
case 
    when age between 18 and 45 then 'Thanh niên' 
	when age between 45 and 65 then 'Trung niên'
	when age > 65 then 'Cao tuôi'
  end age_segment
FROM #fact_table
)
SELECT age_segment
,SUM(sales) sales
FROM age_table
GROUP BY age_segment

--Doanh số của từng sản phẩm trong 3 loại Jacket ,Shirt, Trousers. Từng sản phẩm đó đóng góp bao nhiêu phần trăm doanh số? Phân chia theo từng nhóm tuổi.
WITH age_table as (
SELECT customer_name,gender,age,product_type,product_name,size,colour,sales,
case 
    when age between 18 and 45 then 'Thanh niên' 
	when age between 45 and 65 then 'Trung niên'
	when age > 65 then 'Cao tuôi'
  end age_segment
FROM #fact_table
),segment as (
SELECT age_segment,product_name,SUM(sales) sales
FROM age_table
WHERE product_type = 'Jacket' -- Jacket/Shirt/Trousers
GROUP BY age_segment,product_name
)
SELECT * 
,SUM(sales)OVER(PARTITION BY age_segment) total_sales
,FORMAT(sales/SUM(sales)OVER(PARTITION BY age_segment),'p') pct_sales
FROM segment

/*--> Từ số liệu phân tích ta thấy dòng sản phẩm Jacket và Shirt có doanh số bán hàng cao nhất 
      Doanh thu bán hàng cao nhất vào tháng 3
	  Khách hàng chủ yếu ở độ tuổi thanh niên trung niên */

-- Tháng bán hàng tốt nhất (3) và loại sản phẩm nào được bán nhiều trong tháng đó ?
SELECT MONTH(order_date) [month],product_type
,COUNT(order_id) Frequency
,SUM(sales) Revenue
FROM #fact_table
WHERE MONTH(order_date) = 3 
GROUP BY MONTH(order_date),product_type
ORDER BY 4 DESC 
--> Jacket có số luợng bán nhiều nhất trong tháng 3 

--Sản phẩm nào trong Jacket được bán chạy nhất
SELECT MONTH(order_date) [month],product_type,product_name
,SUM(quantity) quantity
,SUM(sales) Revenue
FROM #fact_table
WHERE MONTH(order_date) = 3 AND product_type = 'Jacket'
GROUP BY MONTH(order_date),product_type,product_name
ORDER BY 5 DESC 
--> Trench Coat có doanh số cao nhất

-- Tiểu bang có doanh số bán hàng cao nhất
SELECT state  
,COUNT(order_id) Frequency
,SUM(sales) Revenue
FROM  #fact_table
GROUP BY state
ORDER BY 2 DESC
--> South Australia có doanh số cao nhất

SELECT state, product_type  
,COUNT(order_id) Frequency
,SUM(sales) Revenue
FROM  #fact_table
WHERE state = 'South Australia'
GROUP BY state, product_type 
ORDER BY 4 DESC
--> Như dự đoán Jacket là sản phẩm tạo ra nhiều doanh số nhất 

--South Australia có doanh số bán hàng cao nhất. Giả sử South Australia đại diện cho các nướcc còn lại 

--Size sản phẩm phổ biến ?
SELECT state ,size 
,SUM(order_id) quantity
,SUM(sales) Revenue
FROM  #fact_table
WHERE state = 'South Australia' AND product_type = 'Jacket' -- Jacket/Shirt/Trousers
GROUP BY state, size
ORDER BY 4 DESC
--> Size L và M có số lượng bán ra nhiều nhất đối với Jacket và Shirt. Trousers bán ra chủ yếu 2 size M và XL
/*==> Từ những phân tích trên ta thấy dáng vóc của khách hàng chủ yếu là vừa và nhỏ không quá to họ thường lựa chọn size áo là L và M. Còn đối với size quần là M và XL 
  có điều bất thường trong số lượng bán size quần có thể họ thường chọn kiểu quần bó hoặc rộng tùy theo style vì thế sự lựa chọn size quần với áo có sự khác nhau */
 

--Ai là khách hàng tốt nhất của chúng ta? Từ đó đưa ra các ưu đãi hợp lí cho khách hàng (sử dụng mô hình RFM)
DROP TABLE IF EXISTS #rfm
;WITH rfm as (
SELECT customer_name
,DATEDIFF(DD,max(order_date),(select max(order_date) from #fact_table)) Recency
,COUNT(order_id) Frequency
,SUM(sales) Monetary
FROM #fact_table
GROUP BY  customer_name
)
,rfm_calc as (
SELECT * 
,NTILE(4) OVER( ORDER BY Recency desc) rfm_recency
,NTILE(4) OVER( ORDER BY Frequency ) rfm_frequency
,NTILE(4) OVER( ORDER BY Monetary ) rfm_monetary
FROM rfm
)
SELECT *
,CONCAT(rfm_recency,rfm_frequency,rfm_monetary) rfm_rank
INTO #rfm
FROM rfm_calc

SELECT customer_name,rfm_recency,rfm_frequency,rfm_monetary,rfm_rank,
case 
        when rfm_rank in (111, 112, 113 , 121, 122, 123, 132, 211, 212, 114, 141) then 'lost_customers' 
		when rfm_rank in (133, 134, 143, 142, 213, 334, 343, 344, 144) then 'slipping away, cannot lose' -- (Big spenders who haven’t purchased lately) slipping away --> Nên tạo những ưu đãi mạnh mẽ để giữ chân khách hàng, đề xuất dựa trên các giao dịch mua trước đây
		when rfm_rank in (311, 411, 421, 331) then 'new customers' --> Sử dụng ưu đãi để thu hút và quan tâm đến họ
		when rfm_rank in (222, 221, 223, 233, 234, 244, 242,243, 322) then 'potential churners' --> Cung cấp các chương trình thành viên, giới thiệu sản phẩm khác
		when rfm_rank in (323, 333,321, 422, 431, 332, 432) then 'active' --(Customers who buy often & recently, but at low price points) --> Tạo nhận diện thương hiệu, cung cấp bản dùng thử free, upsell
		when rfm_rank in (433, 434, 443, 444) then 'loyal' --> Upsell các sản phẩm có giá trị cao hơn, yêu cầu đánh giá
	end rfm_segment 
FROM #rfm

--Top 3 KH chi nhiều tiền nhất trong mỗi tháng
WITH purchase as (
SELECT customer_name
,MONTH(order_date) [month]
,SUM(sales) total_sales
FROM #fact_table
GROUP BY MONTH(order_date), customer_name
)
,rank_table as (
SELECT * 
,RANK() OVER(PARTITION BY month ORDER BY total_sales desc) rank_month
FROM purchase
)
SELECT *
FROM rank_table
WHERE rank_month <4

--Tìm tỉ lệ ở lại của khách hàng sau từng tháng kể từ khi khách hàng dó mua hàng lần đầu tiên là tháng 1	
WITH table_first_month as (
SELECT customer_id,order_date
,MIN(MONTH(order_date)) OVER(PARTITION BY customer_name) first_month
FROM #fact_table
)
,table_sub_month as (
SELECT
 (MONTH(order_date) -1) supsequent_month
,COUNT(DISTINCT customer_id) number_retained_customers
FROM table_first_month
WHERE first_month = 1
GROUP BY MONTH(order_date) - 1
)
SELECT supsequent_month,number_retained_customers
,FIRST_VALUE(number_retained_customers) OVER(ORDER BY supsequent_month) original_users
,FORMAT(number_retained_customers*1.0/FIRST_VALUE(number_retained_customers) OVER(ORDER BY supsequent_month),'P') pct_retained
FROM table_sub_month
--> Khoảng 10% khách hàng quay lại mua hàng các tháng tiếp theo kể từ khi mua lần đầu tiên vào tháng 1

--Tìm tỉ lệ ở lại của khách hàng sau từng tháng kể từ khi khách hàng dó mua hàng lần đầu tiên ( sử dụng mô hình Cohort Anlysis )
WITH table_first_month as (
SELECT customer_id,order_date
,MIN(MONTH(order_date)) OVER(PARTITION BY customer_id) first_month
,(MONTH(order_date) - MIN(MONTH(order_date)) OVER(PARTITION BY customer_id)) subsequent_month
FROM #fact_table
)
,table_sub_month as (
SELECT
 first_month as acquisition_month
,subsequent_month
,COUNT(DISTINCT customer_id) number_retained_customers
FROM table_first_month
GROUP BY first_month, subsequent_month
)
SELECT  acquisition_month,subsequent_month,number_retained_customers
,FIRST_VALUE(number_retained_customers) OVER(PARTITION BY acquisition_month ORDER BY subsequent_month asc) original_users
,FORMAT(number_retained_customers*1.0/FIRST_VALUE(number_retained_customers) OVER(PARTITION BY acquisition_month ORDER BY subsequent_month asc),'P') pct_retained
FROM table_sub_month

--Dùng Pivot để chuyển sang dạng table heatmap
WITH table_first_month as (
SELECT customer_id,order_date
,MIN(MONTH(order_date)) OVER(PARTITION BY customer_id) first_month
,(MONTH(order_date) - MIN(MONTH(order_date)) OVER(PARTITION BY customer_id)) subsequent_month
FROM #fact_table
)
,table_sub_month as (
SELECT
 first_month as acquisition_month
,subsequent_month
,COUNT(DISTINCT customer_id) number_retained_customers
FROM table_first_month
GROUP BY first_month, subsequent_month
)
,table_retention as (
SELECT  acquisition_month,subsequent_month,number_retained_customers
,FIRST_VALUE(number_retained_customers) OVER(PARTITION BY acquisition_month ORDER BY subsequent_month asc) original_users
,FORMAT(number_retained_customers*1.0/FIRST_VALUE(number_retained_customers) OVER(PARTITION BY acquisition_month ORDER BY subsequent_month asc),'P') pct_retained
FROM table_sub_month
)
SELECT acquisition_month
   , original_users
   ,"0", "1", "2", "3", "4", "5", "6",  "7", "8", "9", "10"
FROM ( SELECT acquisition_month, subsequent_month, original_users, pct_retained
       FROM table_retention) AS source_table
PIVOT (
   MAX (pct_retained)
   FOR subsequent_month IN ("0", "1", "2", "3", "4", "5", "6",  "7", "8", "9", "10")
) AS pivot_logic
ORDER BY acquisition_month
