-- Test file: production_queries.lua
-- IDs: 2701-2800
-- Tests: Production-style SQL queries that mirror real-world patterns

return {
    -- =========================================================================
    -- IDs 2701-2710: RDL Report Query Patterns
    -- =========================================================================

    {
        id = 2701,
        type = "parser",
        name = "Report query with temp table creation and join",
        input = [[CREATE TABLE #ReportData (Id INT, Name VARCHAR(100))
INSERT INTO #ReportData SELECT Id, Name FROM Employees
SELECT * FROM #ReportData rd INNER JOIN Departments d ON rd.DeptId = d.Id]],
        expected = {
            chunks = {
                { statement_type = "OTHER" },
                {
                    statement_type = "INSERT",
                    tables = {
                        { name = "#ReportData", is_temp = true },
                        { name = "Employees" }
                    }
                }
            }
        }
    },

    {
        id = 2702,
        type = "parser",
        name = "Report with NOLOCK hints and aggregations",
        input = [[SELECT
    d.DepartmentName,
    COUNT(*) AS EmployeeCount,
    AVG(e.Salary) AS AvgSalary,
    SUM(e.Salary) AS TotalSalary
FROM Employees e WITH (NOLOCK)
INNER JOIN Departments d WITH (NOLOCK) ON e.DeptId = d.Id
GROUP BY d.DepartmentName
HAVING COUNT(*) > 5]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Employees", alias = "e" },
                        { name = "Departments", alias = "d" }
                    }
                }
            }
        }
    },

    {
        id = 2703,
        type = "parser",
        name = "Multi-result set report query",
        input = [[SELECT COUNT(*) AS TotalCustomers FROM Customers WITH (NOLOCK)
SELECT COUNT(*) AS TotalOrders FROM Orders WITH (NOLOCK)
SELECT TOP 10 * FROM Customers WITH (NOLOCK) ORDER BY CreatedDate DESC]],
        expected = {
            chunks = {
                { statement_type = "SELECT", tables = { { name = "Customers" } } },
                { statement_type = "SELECT", tables = { { name = "Orders" } } },
                { statement_type = "SELECT", tables = { { name = "Customers" } } }
            }
        }
    },

    {
        id = 2704,
        type = "parser",
        name = "Report with date range filtering and temp table",
        input = [[DECLARE @StartDate DATE = '2024-01-01'
DECLARE @EndDate DATE = '2024-12-31'

SELECT * INTO #SalesData
FROM Sales WITH (NOLOCK)
WHERE SaleDate BETWEEN @StartDate AND @EndDate

SELECT
    Region,
    SUM(Amount) AS TotalSales,
    COUNT(*) AS TransactionCount
FROM #SalesData
GROUP BY Region]],
        expected = {
            chunks = {
                { statement_type = "DECLARE" },
                { statement_type = "DECLARE" },
                { statement_type = "SELECT", temp_table_name = "#SalesData", tables = { { name = "Sales" } } },
                { statement_type = "SELECT", tables = { { name = "#SalesData", is_temp = true } } }
            }
        }
    },

    {
        id = 2705,
        type = "parser",
        name = "Report with UNION ALL combining multiple sources",
        input = [[SELECT 'Current' AS Source, * FROM CurrentSales WITH (NOLOCK)
UNION ALL
SELECT 'Archive' AS Source, * FROM ArchivedSales WITH (NOLOCK)
ORDER BY SaleDate DESC]],
        expected = {
            chunks = {
                { statement_type = "SELECT", tables = { { name = "CurrentSales" } } },
                { statement_type = "SELECT", tables = { { name = "ArchivedSales" } } }
            }
        }
    },

    {
        id = 2706,
        type = "parser",
        name = "Report with LEFT JOIN and null handling",
        input = [[SELECT
    o.OrderId,
    o.OrderDate,
    ISNULL(c.CustomerName, 'Unknown') AS CustomerName,
    ISNULL(SUM(oi.Quantity * oi.UnitPrice), 0) AS TotalAmount
FROM Orders o WITH (NOLOCK)
LEFT JOIN Customers c WITH (NOLOCK) ON o.CustomerId = c.Id
LEFT JOIN OrderItems oi WITH (NOLOCK) ON o.OrderId = oi.OrderId
GROUP BY o.OrderId, o.OrderDate, c.CustomerName]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Orders", alias = "o" },
                        { name = "Customers", alias = "c" },
                        { name = "OrderItems", alias = "oi" }
                    }
                }
            }
        }
    },

    {
        id = 2707,
        type = "parser",
        name = "Report with global temp table and multiple selects",
        input = [[CREATE TABLE ##ReportCache (Id INT, Data VARCHAR(MAX))
INSERT INTO ##ReportCache SELECT Id, Data FROM LargeTable WITH (NOLOCK)
SELECT COUNT(*) FROM ##ReportCache
SELECT * FROM ##ReportCache WHERE Id > 100]],
        expected = {
            chunks = {
                { statement_type = "OTHER" },
                {
                    statement_type = "INSERT",
                    tables = {
                        { name = "##ReportCache", is_temp = true },
                        { name = "LargeTable" }
                    }
                }
            }
        }
    },

    {
        id = 2708,
        type = "parser",
        name = "Report with CASE expressions and pivoting logic",
        input = [[SELECT
    Region,
    SUM(CASE WHEN MONTH(OrderDate) = 1 THEN Amount ELSE 0 END) AS Jan,
    SUM(CASE WHEN MONTH(OrderDate) = 2 THEN Amount ELSE 0 END) AS Feb,
    SUM(CASE WHEN MONTH(OrderDate) = 3 THEN Amount ELSE 0 END) AS Mar
FROM Sales WITH (NOLOCK)
WHERE YEAR(OrderDate) = 2024
GROUP BY Region]],
        expected = {
            chunks = {
                { statement_type = "SELECT", tables = { { name = "Sales" } } }
            }
        }
    },

    {
        id = 2709,
        type = "parser",
        name = "Report with schema-qualified tables and multiple joins",
        input = [[SELECT
    s.StudentName,
    c.CourseName,
    e.Grade,
    d.DepartmentName
FROM dbo.Students s WITH (NOLOCK)
INNER JOIN dbo.Enrollments e WITH (NOLOCK) ON s.StudentId = e.StudentId
INNER JOIN dbo.Courses c WITH (NOLOCK) ON e.CourseId = c.CourseId
INNER JOIN dbo.Departments d WITH (NOLOCK) ON c.DeptId = d.DeptId
WHERE e.EnrollmentYear = 2024]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Students", alias = "s", schema = "dbo" },
                        { name = "Enrollments", alias = "e", schema = "dbo" },
                        { name = "Courses", alias = "c", schema = "dbo" },
                        { name = "Departments", alias = "d", schema = "dbo" }
                    }
                }
            }
        }
    },

    {
        id = 2710,
        type = "parser",
        name = "Report with DISTINCT and HAVING clause",
        input = [[SELECT DISTINCT
    ProductCategory,
    COUNT(DISTINCT CustomerId) AS UniqueCustomers,
    SUM(OrderAmount) AS TotalRevenue
FROM OrderDetails od WITH (NOLOCK)
INNER JOIN Products p WITH (NOLOCK) ON od.ProductId = p.Id
GROUP BY ProductCategory
HAVING COUNT(DISTINCT CustomerId) >= 10]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "OrderDetails", alias = "od" },
                        { name = "Products", alias = "p" }
                    }
                }
            }
        }
    },

    -- =========================================================================
    -- IDs 2711-2720: Stored Procedure Patterns
    -- =========================================================================

    {
        id = 2711,
        type = "parser",
        name = "Stored proc with INSERT...EXEC pattern",
        input = [[CREATE TABLE #Results (Id INT, Name VARCHAR(100))
INSERT INTO #Results EXEC GetEmployeeData @DeptId = 5
SELECT * FROM #Results]],
        expected = {
            chunks = {
                { statement_type = "OTHER" },
                { statement_type = "INSERT" }
            }
        }
    },

    {
        id = 2712,
        type = "parser",
        name = "Stored proc with UPDATE FROM join",
        input = [[UPDATE e
SET e.DepartmentName = d.Name
FROM Employees e
INNER JOIN Departments d ON e.DeptId = d.Id
WHERE e.DepartmentName IS NULL]],
        expected = {
            chunks = {
                {
                    statement_type = "UPDATE",
                    tables = {
                        { name = "Employees", alias = "e" },
                        { name = "Departments", alias = "d" }
                    }
                }
            }
        }
    },

    {
        id = 2713,
        type = "parser",
        name = "Stored proc with DELETE using subquery",
        input = [[DELETE FROM Orders
WHERE CustomerId IN (
    SELECT CustomerId FROM Customers WHERE Inactive = 1
)]],
        expected = {
            chunks = {
                {
                    statement_type = "DELETE",
                    tables = { { name = "Orders" } },
                    subqueries = {
                        { tables = { { name = "Customers" } } }
                    }
                }
            }
        }
    },

    {
        id = 2714,
        type = "parser",
        name = "Stored proc with IF EXISTS check",
        input = [[IF EXISTS (SELECT 1 FROM Customers WHERE Email = @Email)
BEGIN
    SELECT * FROM Customers WHERE Email = @Email
END
ELSE
BEGIN
    INSERT INTO Customers (Email) VALUES (@Email)
END]],
        expected = {
            chunks = {
                { statement_type = "SELECT", tables = { { name = "Customers" } } }
            }
        }
    },

    {
        id = 2715,
        type = "parser",
        name = "Stored proc with OUTPUT parameters and RETURN",
        input = [[DECLARE @RecordCount INT
SELECT @RecordCount = COUNT(*) FROM Orders WHERE Status = 'Pending'
SELECT * FROM Orders WHERE Status = 'Pending'
RETURN @RecordCount]],
        expected = {
            chunks = {
                { statement_type = "DECLARE" },
                { statement_type = "SELECT", tables = { { name = "Orders" } } },
                { statement_type = "SELECT", tables = { { name = "Orders" } } }
            }
        }
    },

    {
        id = 2716,
        type = "parser",
        name = "Stored proc with transaction and error handling",
        input = [[BEGIN TRANSACTION
UPDATE Inventory SET Quantity = Quantity - 1 WHERE ProductId = @ProductId
INSERT INTO Orders (ProductId, Quantity) VALUES (@ProductId, 1)
COMMIT TRANSACTION]],
        expected = {
            chunks = {
                { statement_type = "UPDATE", tables = { { name = "Inventory" } } },
                { statement_type = "INSERT", tables = { { name = "Orders" } } }
            }
        }
    },

    {
        id = 2717,
        type = "parser",
        name = "Stored proc with WHILE loop",
        input = [[DECLARE @Counter INT = 0
WHILE @Counter < 10
BEGIN
    INSERT INTO ProcessLog (Message) VALUES ('Iteration ' + CAST(@Counter AS VARCHAR))
    SELECT * FROM ProcessQueue WHERE ProcessId = @Counter
    SET @Counter = @Counter + 1
END]],
        expected = {
            chunks = {
                { statement_type = "DECLARE" },
                { statement_type = "INSERT", tables = { { name = "ProcessLog" } } },
                { statement_type = "SET" }
            }
        }
    },

    {
        id = 2718,
        type = "parser",
        name = "Stored proc with MERGE statement",
        input = [[MERGE INTO Inventory AS target
USING StockUpdates AS source
ON target.ProductId = source.ProductId
WHEN MATCHED THEN
    UPDATE SET target.Quantity = source.Quantity
WHEN NOT MATCHED THEN
    INSERT (ProductId, Quantity) VALUES (source.ProductId, source.Quantity);]],
        expected = {
            chunks = {
                {
                    statement_type = "MERGE",
                    tables = {
                        { name = "Inventory", alias = "target" },
                        { name = "StockUpdates", alias = "source" }
                    }
                }
            }
        }
    },

    {
        id = 2719,
        type = "parser",
        name = "Stored proc with OUTPUT clause",
        input = [[DELETE FROM ArchivedOrders
OUTPUT DELETED.OrderId, DELETED.OrderDate INTO #DeletedOrders
WHERE OrderDate < DATEADD(YEAR, -2, GETDATE())

SELECT * FROM #DeletedOrders]],
        expected = {
            chunks = {
                { statement_type = "DELETE", tables = { { name = "ArchivedOrders" } } },
                { statement_type = "SELECT", tables = { { name = "#DeletedOrders", is_temp = true } } }
            }
        }
    },

    {
        id = 2720,
        type = "parser",
        name = "Stored proc with dynamic SQL execution",
        input = [[DECLARE @SQL NVARCHAR(MAX)
SET @SQL = 'SELECT * FROM ' + @TableName + ' WHERE Active = 1'
EXEC sp_executesql @SQL]],
        expected = {
            chunks = {
                { statement_type = "DECLARE" },
                { statement_type = "SET" },
                { statement_type = "EXEC" }
            }
        }
    },

    -- =========================================================================
    -- IDs 2721-2735: Complex CTE Patterns
    -- =========================================================================

    {
        id = 2721,
        type = "parser",
        name = "Simple CTE with single table reference",
        input = [[WITH EmployeeCTE AS (
    SELECT * FROM Employees WHERE Active = 1
)
SELECT * FROM EmployeeCTE]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    ctes = {
                        { name = "EmployeeCTE", tables = { { name = "Employees" } } }
                    }
                }
            }
        }
    },

    {
        id = 2722,
        type = "parser",
        name = "CTE with join inside CTE definition",
        input = [[WITH OrderSummary AS (
    SELECT o.CustomerId, COUNT(*) AS OrderCount
    FROM Orders o
    INNER JOIN OrderItems oi ON o.OrderId = oi.OrderId
    GROUP BY o.CustomerId
)
SELECT * FROM OrderSummary WHERE OrderCount > 5]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    ctes = {
                        {
                            name = "OrderSummary",
                            tables = {
                                { name = "Orders", alias = "o" },
                                { name = "OrderItems", alias = "oi" }
                            }
                        }
                    }
                }
            }
        }
    },

    {
        id = 2723,
        type = "parser",
        name = "Multiple CTEs in sequence",
        input = [[WITH
ActiveCustomers AS (
    SELECT * FROM Customers WHERE Active = 1
),
RecentOrders AS (
    SELECT * FROM Orders WHERE OrderDate > '2024-01-01'
),
CustomerOrders AS (
    SELECT c.CustomerId, c.Name, o.OrderId
    FROM ActiveCustomers c
    INNER JOIN RecentOrders o ON c.CustomerId = o.CustomerId
)
SELECT * FROM CustomerOrders]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    ctes = {
                        { name = "ActiveCustomers", tables = { { name = "Customers" } } },
                        { name = "RecentOrders", tables = { { name = "Orders" } } },
                        { name = "CustomerOrders" }
                    }
                }
            }
        }
    },

    {
        id = 2724,
        type = "parser",
        name = "CTE with window function ROW_NUMBER",
        input = [[WITH RankedEmployees AS (
    SELECT
        EmployeeId,
        Name,
        Salary,
        ROW_NUMBER() OVER (PARTITION BY DeptId ORDER BY Salary DESC) AS SalaryRank
    FROM Employees
)
SELECT * FROM RankedEmployees WHERE SalaryRank = 1]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    ctes = {
                        { name = "RankedEmployees", tables = { { name = "Employees" } } }
                    }
                }
            }
        }
    },

    {
        id = 2725,
        type = "parser",
        name = "Recursive CTE for hierarchical data",
        input = [[WITH OrgHierarchy AS (
    SELECT EmployeeId, ManagerId, Name, 0 AS Level
    FROM Employees WHERE ManagerId IS NULL
    UNION ALL
    SELECT e.EmployeeId, e.ManagerId, e.Name, oh.Level + 1
    FROM Employees e
    INNER JOIN OrgHierarchy oh ON e.ManagerId = oh.EmployeeId
)
SELECT * FROM OrgHierarchy]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    ctes = {
                        {
                            name = "OrgHierarchy",
                            tables = {
                                { name = "Employees" },
                                { name = "Employees", alias = "e" }
                            }
                        }
                    }
                }
            }
        }
    },

    {
        id = 2726,
        type = "parser",
        name = "CTE with RANK and DENSE_RANK",
        input = [[WITH ProductRankings AS (
    SELECT
        ProductId,
        ProductName,
        Sales,
        RANK() OVER (ORDER BY Sales DESC) AS SalesRank,
        DENSE_RANK() OVER (ORDER BY Sales DESC) AS DenseSalesRank
    FROM Products
)
SELECT * FROM ProductRankings WHERE SalesRank <= 10]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    ctes = {
                        { name = "ProductRankings", tables = { { name = "Products" } } }
                    }
                }
            }
        }
    },

    {
        id = 2727,
        type = "parser",
        name = "CTE that joins with regular table",
        input = [[WITH ActiveOrders AS (
    SELECT * FROM Orders WHERE Status = 'Active'
)
SELECT ao.OrderId, c.CustomerName
FROM ActiveOrders ao
INNER JOIN Customers c ON ao.CustomerId = c.CustomerId]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    ctes = {
                        { name = "ActiveOrders", tables = { { name = "Orders" } } }
                    },
                    tables = {
                        { name = "Customers", alias = "c" }
                    }
                }
            }
        }
    },

    {
        id = 2728,
        type = "parser",
        name = "CTE with nested subquery inside CTE definition",
        input = [[WITH HighValueCustomers AS (
    SELECT CustomerId, TotalSpent
    FROM (
        SELECT CustomerId, SUM(Amount) AS TotalSpent
        FROM Orders
        GROUP BY CustomerId
    ) AS CustomerTotals
    WHERE TotalSpent > 10000
)
SELECT * FROM HighValueCustomers]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    ctes = {
                        {
                            name = "HighValueCustomers",
                            subqueries = {
                                { tables = { { name = "Orders" } } }
                            }
                        }
                    }
                }
            }
        }
    },

    {
        id = 2729,
        type = "parser",
        name = "CTE with UNION combining multiple sources",
        input = [[WITH AllTransactions AS (
    SELECT TransactionId, Amount, 'Sale' AS Type FROM Sales
    UNION ALL
    SELECT TransactionId, Amount, 'Refund' AS Type FROM Refunds
)
SELECT * FROM AllTransactions ORDER BY TransactionId]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    ctes = {
                        {
                            name = "AllTransactions",
                            tables = {
                                { name = "Sales" },
                                { name = "Refunds" }
                            }
                        }
                    }
                }
            }
        }
    },

    {
        id = 2730,
        type = "parser",
        name = "Multiple CTEs with dependencies between them",
        input = [[WITH
Customers2024 AS (
    SELECT * FROM Customers WHERE YEAR(CreatedDate) = 2024
),
CustomerOrders AS (
    SELECT c.CustomerId, COUNT(*) AS OrderCount
    FROM Customers2024 c
    INNER JOIN Orders o ON c.CustomerId = o.CustomerId
    GROUP BY c.CustomerId
),
HighValueCustomers AS (
    SELECT * FROM CustomerOrders WHERE OrderCount >= 10
)
SELECT * FROM HighValueCustomers]],
        expected = {
            chunks = {
                {
                    statement_type = "WITH",
                    ctes = {
                        { name = "Customers2024", tables = { { name = "Customers" } } },
                        { name = "CustomerOrders", tables = { { name = "Orders", alias = "o" } } },
                        { name = "HighValueCustomers" }
                    }
                }
            }
        }
    },

    {
        id = 2731,
        type = "parser",
        name = "CTE with LAG and LEAD window functions",
        input = [[WITH StockMovement AS (
    SELECT
        Date,
        Price,
        LAG(Price) OVER (ORDER BY Date) AS PrevPrice,
        LEAD(Price) OVER (ORDER BY Date) AS NextPrice
    FROM StockPrices
)
SELECT * FROM StockMovement WHERE Price > PrevPrice]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    ctes = {
                        { name = "StockMovement", tables = { { name = "StockPrices" } } }
                    }
                }
            }
        }
    },

    {
        id = 2732,
        type = "parser",
        name = "CTE with aggregate window functions",
        input = [[WITH SalesAnalysis AS (
    SELECT
        SaleDate,
        Amount,
        SUM(Amount) OVER (ORDER BY SaleDate ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS MovingAvg7Day
    FROM Sales
)
SELECT * FROM SalesAnalysis]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    ctes = {
                        { name = "SalesAnalysis", tables = { { name = "Sales" } } }
                    }
                }
            }
        }
    },

    {
        id = 2733,
        type = "parser",
        name = "CTE with NTILE for bucketing",
        input = [[WITH CustomerQuartiles AS (
    SELECT
        CustomerId,
        TotalSpent,
        NTILE(4) OVER (ORDER BY TotalSpent DESC) AS Quartile
    FROM CustomerSummary
)
SELECT * FROM CustomerQuartiles WHERE Quartile = 1]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    ctes = {
                        { name = "CustomerQuartiles", tables = { { name = "CustomerSummary" } } }
                    }
                }
            }
        }
    },

    {
        id = 2734,
        type = "parser",
        name = "CTE with multiple table joins and aggregation",
        input = [[WITH ProductSales AS (
    SELECT
        p.ProductId,
        p.ProductName,
        c.CategoryName,
        SUM(oi.Quantity) AS TotalQuantity,
        SUM(oi.Quantity * oi.UnitPrice) AS TotalRevenue
    FROM Products p
    INNER JOIN Categories c ON p.CategoryId = c.CategoryId
    INNER JOIN OrderItems oi ON p.ProductId = oi.ProductId
    GROUP BY p.ProductId, p.ProductName, c.CategoryName
)
SELECT * FROM ProductSales WHERE TotalRevenue > 10000]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    ctes = {
                        {
                            name = "ProductSales",
                            tables = {
                                { name = "Products", alias = "p" },
                                { name = "Categories", alias = "c" },
                                { name = "OrderItems", alias = "oi" }
                            }
                        }
                    }
                }
            }
        }
    },

    {
        id = 2735,
        type = "parser",
        name = "Recursive CTE with multiple levels of depth",
        input = [[WITH RECURSIVE CategoryHierarchy AS (
    SELECT CategoryId, ParentCategoryId, CategoryName, 1 AS Depth
    FROM Categories
    WHERE ParentCategoryId IS NULL
    UNION ALL
    SELECT c.CategoryId, c.ParentCategoryId, c.CategoryName, ch.Depth + 1
    FROM Categories c
    INNER JOIN CategoryHierarchy ch ON c.ParentCategoryId = ch.CategoryId
    WHERE ch.Depth < 5
)
SELECT * FROM CategoryHierarchy]],
        expected = {
            chunks = {
                { statement_type = "WITH" }
            }
        }
    },

    -- =========================================================================
    -- IDs 2736-2750: Nested Subquery Patterns
    -- =========================================================================

    {
        id = 2736,
        type = "parser",
        name = "Simple EXISTS subquery",
        input = [[SELECT * FROM Customers c
WHERE EXISTS (
    SELECT 1 FROM Orders o WHERE o.CustomerId = c.CustomerId
)]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = { { name = "Customers", alias = "c" } },
                    subqueries = {
                        { tables = { { name = "Orders", alias = "o" } } }
                    }
                }
            }
        }
    },

    {
        id = 2737,
        type = "parser",
        name = "NOT EXISTS subquery for finding missing records",
        input = [[SELECT * FROM Products p
WHERE NOT EXISTS (
    SELECT 1 FROM OrderItems oi WHERE oi.ProductId = p.ProductId
)]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = { { name = "Products", alias = "p" } },
                    subqueries = {
                        { tables = { { name = "OrderItems", alias = "oi" } } }
                    }
                }
            }
        }
    },

    {
        id = 2738,
        type = "parser",
        name = "IN subquery with simple list",
        input = [[SELECT * FROM Orders
WHERE CustomerId IN (
    SELECT CustomerId FROM Customers WHERE Country = 'USA'
)]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = { { name = "Orders" } },
                    subqueries = {
                        { tables = { { name = "Customers" } } }
                    }
                }
            }
        }
    },

    {
        id = 2739,
        type = "parser",
        name = "NOT IN subquery for exclusion",
        input = [[SELECT * FROM Employees
WHERE DepartmentId NOT IN (
    SELECT DepartmentId FROM Departments WHERE Active = 0
)]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = { { name = "Employees" } },
                    subqueries = {
                        { tables = { { name = "Departments" } } }
                    }
                }
            }
        }
    },

    {
        id = 2740,
        type = "parser",
        name = "Correlated subquery in WHERE clause",
        input = [[SELECT * FROM Employees e1
WHERE Salary > (
    SELECT AVG(Salary)
    FROM Employees e2
    WHERE e2.DepartmentId = e1.DepartmentId
)]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = { { name = "Employees", alias = "e1" } },
                    subqueries = {
                        { tables = { { name = "Employees", alias = "e2" } } }
                    }
                }
            }
        }
    },

    {
        id = 2741,
        type = "parser",
        name = "Subquery in SELECT clause (scalar subquery)",
        input = [[SELECT
    OrderId,
    OrderDate,
    (SELECT CustomerName FROM Customers WHERE CustomerId = Orders.CustomerId) AS CustomerName
FROM Orders]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = { { name = "Orders" } },
                    subqueries = {
                        { tables = { { name = "Customers" } } }
                    }
                }
            }
        }
    },

    {
        id = 2742,
        type = "parser",
        name = "Multiple scalar subqueries in SELECT",
        input = [[SELECT
    ProductId,
    (SELECT CategoryName FROM Categories WHERE CategoryId = Products.CategoryId) AS Category,
    (SELECT SupplierName FROM Suppliers WHERE SupplierId = Products.SupplierId) AS Supplier
FROM Products]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = { { name = "Products" } },
                    subqueries = {
                        { tables = { { name = "Categories" } } },
                        { tables = { { name = "Suppliers" } } }
                    }
                }
            }
        }
    },

    {
        id = 2743,
        type = "parser",
        name = "Subquery in FROM clause (derived table)",
        input = [[SELECT * FROM (
    SELECT CustomerId, COUNT(*) AS OrderCount
    FROM Orders
    GROUP BY CustomerId
) AS CustomerOrders
WHERE OrderCount > 5]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    subqueries = {
                        { tables = { { name = "Orders" } } }
                    }
                }
            }
        }
    },

    {
        id = 2744,
        type = "parser",
        name = "Nested subqueries 3 levels deep",
        input = [[SELECT * FROM Customers
WHERE CustomerId IN (
    SELECT CustomerId FROM Orders
    WHERE OrderId IN (
        SELECT OrderId FROM OrderItems WHERE ProductId IN (
            SELECT ProductId FROM Products WHERE Discontinued = 1
        )
    )
)]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = { { name = "Customers" } },
                    subqueries = {
                        {
                            tables = { { name = "Orders" } },
                            subqueries = {
                                {
                                    tables = { { name = "OrderItems" } },
                                    subqueries = {
                                        { tables = { { name = "Products" } } }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    },

    {
        id = 2745,
        type = "parser",
        name = "Subquery with JOIN inside",
        input = [[SELECT * FROM Customers
WHERE CustomerId IN (
    SELECT o.CustomerId
    FROM Orders o
    INNER JOIN OrderItems oi ON o.OrderId = oi.OrderId
    WHERE oi.Quantity > 100
)]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = { { name = "Customers" } },
                    subqueries = {
                        {
                            tables = {
                                { name = "Orders", alias = "o" },
                                { name = "OrderItems", alias = "oi" }
                            }
                        }
                    }
                }
            }
        }
    },

    {
        id = 2746,
        type = "parser",
        name = "Subquery in CASE expression",
        input = [[SELECT
    OrderId,
    CASE
        WHEN (SELECT COUNT(*) FROM OrderItems WHERE OrderId = Orders.OrderId) > 5
        THEN 'Large'
        ELSE 'Small'
    END AS OrderSize
FROM Orders]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = { { name = "Orders" } },
                    subqueries = {
                        { tables = { { name = "OrderItems" } } }
                    }
                }
            }
        }
    },

    {
        id = 2747,
        type = "parser",
        name = "Multiple subqueries in CASE expression",
        input = [[SELECT
    EmployeeId,
    CASE
        WHEN (SELECT COUNT(*) FROM Projects WHERE ManagerId = Employees.EmployeeId) > 0 THEN 'Manager'
        WHEN (SELECT COUNT(*) FROM Tasks WHERE AssignedTo = Employees.EmployeeId) > 10 THEN 'Busy'
        ELSE 'Available'
    END AS Status
FROM Employees]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = { { name = "Employees" } },
                    subqueries = {
                        { tables = { { name = "Projects" } } },
                        { tables = { { name = "Tasks" } } }
                    }
                }
            }
        }
    },

    {
        id = 2748,
        type = "parser",
        name = "Subquery with aggregate in HAVING clause",
        input = [[SELECT DepartmentId, COUNT(*) AS EmployeeCount
FROM Employees
GROUP BY DepartmentId
HAVING COUNT(*) > (
    SELECT AVG(DeptSize) FROM (
        SELECT COUNT(*) AS DeptSize FROM Employees GROUP BY DepartmentId
    ) AS DeptSizes
)]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = { { name = "Employees" } },
                    subqueries = {
                        {
                            subqueries = {
                                { tables = { { name = "Employees" } } }
                            }
                        }
                    }
                }
            }
        }
    },

    {
        id = 2749,
        type = "parser",
        name = "ANY and ALL subquery operators",
        input = [[SELECT * FROM Products
WHERE Price > ALL (
    SELECT Price FROM Products WHERE CategoryId = 5
)
AND Stock < ANY (
    SELECT MinStock FROM Warehouses
)]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = { { name = "Products" } },
                    subqueries = {
                        { tables = { { name = "Products" } } },
                        { tables = { { name = "Warehouses" } } }
                    }
                }
            }
        }
    },

    {
        id = 2750,
        type = "parser",
        name = "Subquery with UNION in WHERE clause",
        input = [[SELECT * FROM Orders
WHERE CustomerId IN (
    SELECT CustomerId FROM GoldCustomers
    UNION
    SELECT CustomerId FROM PlatinumCustomers
)]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = { { name = "Orders" } },
                    subqueries = {
                        {
                            tables = {
                                { name = "GoldCustomers" },
                                { name = "PlatinumCustomers" }
                            }
                        }
                    }
                }
            }
        }
    },

    -- =========================================================================
    -- IDs 2751-2765: Temp Table Workflows
    -- =========================================================================

    {
        id = 2751,
        type = "parser",
        name = "CREATE temp table with explicit columns",
        input = [[CREATE TABLE #CustomerSummary (
    CustomerId INT,
    CustomerName VARCHAR(100),
    TotalOrders INT,
    TotalSpent DECIMAL(10,2)
)]],
        expected = {
            chunks = {
                { statement_type = "OTHER" }
            }
        }
    },

    {
        id = 2752,
        type = "parser",
        name = "SELECT INTO temp table",
        input = [[SELECT * INTO #ActiveCustomers
FROM Customers
WHERE Active = 1]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    temp_table_name = "#ActiveCustomers",
                    tables = { { name = "Customers" } }
                }
            }
        }
    },

    {
        id = 2753,
        type = "parser",
        name = "INSERT INTO temp table from SELECT",
        input = [[CREATE TABLE #Results (Id INT, Name VARCHAR(100))
INSERT INTO #Results SELECT EmployeeId, EmployeeName FROM Employees WHERE Active = 1]],
        expected = {
            chunks = {
                { statement_type = "OTHER" },
                {
                    statement_type = "INSERT",
                    tables = {
                        { name = "#Results", is_temp = true },
                        { name = "Employees" }
                    }
                }
            }
        }
    },

    {
        id = 2754,
        type = "parser",
        name = "Multiple temp tables joined together",
        input = [[SELECT * INTO #Orders2024 FROM Orders WHERE YEAR(OrderDate) = 2024
SELECT * INTO #Customers2024 FROM Customers WHERE YEAR(CreatedDate) = 2024
SELECT c.Name, COUNT(*) AS OrderCount
FROM #Customers2024 c
INNER JOIN #Orders2024 o ON c.CustomerId = o.CustomerId
GROUP BY c.Name]],
        expected = {
            chunks = {
                { statement_type = "SELECT", temp_table_name = "#Orders2024", tables = { { name = "Orders" } } },
                { statement_type = "SELECT", temp_table_name = "#Customers2024", tables = { { name = "Customers" } } },
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "#Customers2024", alias = "c", is_temp = true },
                        { name = "#Orders2024", alias = "o", is_temp = true }
                    }
                }
            }
        }
    },

    {
        id = 2755,
        type = "parser",
        name = "Temp table with index creation",
        input = [[SELECT * INTO #LargeDataset FROM FactSales
CREATE CLUSTERED INDEX IX_Date ON #LargeDataset(SaleDate)
SELECT * FROM #LargeDataset WHERE SaleDate > '2024-01-01']],
        expected = {
            chunks = {
                { statement_type = "SELECT", temp_table_name = "#LargeDataset", tables = { { name = "FactSales" } } },
                { statement_type = "OTHER" },
                { statement_type = "SELECT", tables = { { name = "#LargeDataset", is_temp = true } } }
            }
        }
    },

    {
        id = 2756,
        type = "parser",
        name = "Global temp table shared across sessions",
        input = [[CREATE TABLE ##SharedData (SessionId INT, Data VARCHAR(MAX))
INSERT INTO ##SharedData VALUES (@@SPID, 'Some data')
SELECT * FROM ##SharedData]],
        expected = {
            chunks = {
                { statement_type = "OTHER" },
                { statement_type = "INSERT", tables = { { name = "##SharedData", is_temp = true } } },
                { statement_type = "SELECT", tables = { { name = "##SharedData", is_temp = true } } }
            }
        }
    },

    {
        id = 2757,
        type = "parser",
        name = "Temp table with UPDATE statement",
        input = [[SELECT * INTO #Products FROM Products
UPDATE #Products SET Price = Price * 1.1 WHERE CategoryId = 5
SELECT * FROM #Products]],
        expected = {
            chunks = {
                { statement_type = "SELECT", temp_table_name = "#Products", tables = { { name = "Products" } } },
                { statement_type = "UPDATE", tables = { { name = "#Products", is_temp = true } } },
                { statement_type = "SELECT", tables = { { name = "#Products", is_temp = true } } }
            }
        }
    },

    {
        id = 2758,
        type = "parser",
        name = "Temp table with DELETE statement",
        input = [[SELECT * INTO #OrdersToProcess FROM Orders WHERE Status = 'Pending'
DELETE FROM #OrdersToProcess WHERE OrderDate < '2023-01-01'
SELECT * FROM #OrdersToProcess]],
        expected = {
            chunks = {
                { statement_type = "SELECT", temp_table_name = "#OrdersToProcess", tables = { { name = "Orders" } } },
                { statement_type = "DELETE", tables = { { name = "#OrdersToProcess", is_temp = true } } },
                { statement_type = "SELECT", tables = { { name = "#OrdersToProcess", is_temp = true } } }
            }
        }
    },

    {
        id = 2759,
        type = "parser",
        name = "Temp table with complex JOIN and aggregation",
        input = [[SELECT
    c.CustomerId,
    c.CustomerName,
    COUNT(o.OrderId) AS OrderCount,
    SUM(o.TotalAmount) AS TotalSpent
INTO #CustomerMetrics
FROM Customers c
LEFT JOIN Orders o ON c.CustomerId = o.CustomerId
GROUP BY c.CustomerId, c.CustomerName

SELECT * FROM #CustomerMetrics WHERE TotalSpent > 10000]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    temp_table_name = "#CustomerMetrics",
                    tables = {
                        { name = "Customers", alias = "c" },
                        { name = "Orders", alias = "o" }
                    }
                },
                { statement_type = "SELECT", tables = { { name = "#CustomerMetrics", is_temp = true } } }
            }
        }
    },

    {
        id = 2760,
        type = "parser",
        name = "Temp table with DROP before CREATE pattern",
        input = [[IF OBJECT_ID('tempdb..#Results') IS NOT NULL DROP TABLE #Results
CREATE TABLE #Results (Id INT, Value VARCHAR(100))
INSERT INTO #Results VALUES (1, 'Test')]],
        expected = {
            chunks = {
                { statement_type = "OTHER" },
                { statement_type = "OTHER" },
                { statement_type = "INSERT", tables = { { name = "#Results", is_temp = true } } }
            }
        }
    },

    {
        id = 2761,
        type = "parser",
        name = "Temp table populated from CTE",
        input = [[WITH OrderSummary AS (
    SELECT CustomerId, COUNT(*) AS OrderCount
    FROM Orders
    GROUP BY CustomerId
)
SELECT * INTO #CustomerOrderCounts FROM OrderSummary]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    temp_table_name = "#CustomerOrderCounts",
                    ctes = {
                        { name = "OrderSummary", tables = { { name = "Orders" } } }
                    }
                }
            }
        }
    },

    {
        id = 2762,
        type = "parser",
        name = "Temp table with table variable comparison",
        input = [[DECLARE @TempVar TABLE (Id INT, Name VARCHAR(100))
INSERT INTO @TempVar VALUES (1, 'Test')
SELECT * INTO #TempTable FROM @TempVar]],
        expected = {
            chunks = {
                { statement_type = "DECLARE" },
                { statement_type = "INSERT" },
                { statement_type = "SELECT", temp_table_name = "#TempTable" }
            }
        }
    },

    {
        id = 2763,
        type = "parser",
        name = "Temp table used in subquery",
        input = [[SELECT * INTO #ActiveProducts FROM Products WHERE Active = 1
SELECT * FROM Orders
WHERE ProductId IN (SELECT ProductId FROM #ActiveProducts)]],
        expected = {
            chunks = {
                { statement_type = "SELECT", temp_table_name = "#ActiveProducts", tables = { { name = "Products" } } },
                {
                    statement_type = "SELECT",
                    tables = { { name = "Orders" } },
                    subqueries = {
                        { tables = { { name = "#ActiveProducts", is_temp = true } } }
                    }
                }
            }
        }
    },

    {
        id = 2764,
        type = "parser",
        name = "Temp table with ALTER statement",
        input = [[CREATE TABLE #Data (Id INT)
ALTER TABLE #Data ADD Name VARCHAR(100)
INSERT INTO #Data VALUES (1, 'Test')
SELECT * FROM #Data]],
        expected = {
            chunks = {
                { statement_type = "OTHER" },
                { statement_type = "OTHER" },
                { statement_type = "INSERT", tables = { { name = "#Data", is_temp = true } } },
                { statement_type = "SELECT", tables = { { name = "#Data", is_temp = true } } }
            }
        }
    },

    {
        id = 2765,
        type = "parser",
        name = "Temp table with TRUNCATE statement",
        input = [[SELECT * INTO #Cache FROM LargeTable
TRUNCATE TABLE #Cache
INSERT INTO #Cache SELECT * FROM LargeTable WHERE Active = 1
SELECT * FROM #Cache]],
        expected = {
            chunks = {
                { statement_type = "SELECT", temp_table_name = "#Cache", tables = { { name = "LargeTable" } } },
                { statement_type = "TRUNCATE" },
                {
                    statement_type = "INSERT",
                    tables = {
                        { name = "#Cache", is_temp = true },
                        { name = "LargeTable" }
                    }
                }
            }
        }
    },

    -- =========================================================================
    -- IDs 2766-2780: GO Batch Operations
    -- =========================================================================

    {
        id = 2766,
        type = "parser",
        name = "USE database with GO batch separator",
        input = [[USE Master
GO
SELECT * FROM sys.databases]],
        expected = {
            chunks = {
                { statement_type = "SELECT", go_batch_index = 1, tables = { { name = "databases", schema = "sys" } } }
            }
        }
    },

    {
        id = 2767,
        type = "parser",
        name = "Multiple batches with GO separators",
        input = [[CREATE TABLE TestTable (Id INT)
GO
INSERT INTO TestTable VALUES (1)
GO
SELECT * FROM TestTable
GO]],
        expected = {
            chunks = {
                { statement_type = "OTHER", go_batch_index = 0 },
                { statement_type = "INSERT", go_batch_index = 1 },
                { statement_type = "SELECT", go_batch_index = 2, tables = { { name = "TestTable" } } }
            }
        }
    },

    {
        id = 2768,
        type = "parser",
        name = "GO with batch count (GO 5)",
        input = [[INSERT INTO LogTable (Message) VALUES ('Test')
GO 5
SELECT COUNT(*) FROM LogTable]],
        expected = {
            chunks = {
                { statement_type = "INSERT", go_batch_index = 0 },
                { statement_type = "SELECT", go_batch_index = 1, tables = { { name = "LogTable" } } }
            }
        }
    },

    {
        id = 2769,
        type = "parser",
        name = "Mixed DDL and DML with GO batches",
        input = [[CREATE PROCEDURE GetCustomers AS SELECT * FROM Customers
GO
EXEC GetCustomers
GO
DROP PROCEDURE GetCustomers
GO]],
        expected = {
            chunks = {
                { statement_type = "OTHER", go_batch_index = 0 },
                { statement_type = "SELECT", go_batch_index = 0, tables = { { name = "Customers" } } },
                { statement_type = "EXEC", go_batch_index = 1 },
                { statement_type = "OTHER", go_batch_index = 2 }
            }
        }
    },

    {
        id = 2770,
        type = "parser",
        name = "GO batch with CREATE VIEW",
        input = [[CREATE VIEW CustomerOrders AS
SELECT c.Name, COUNT(*) AS OrderCount
FROM Customers c
INNER JOIN Orders o ON c.CustomerId = o.CustomerId
GROUP BY c.Name
GO
SELECT * FROM CustomerOrders]],
        expected = {
            chunks = {
                { statement_type = "OTHER", go_batch_index = 0 },
                {
                    statement_type = "SELECT",
                    go_batch_index = 0,
                    tables = {
                        { name = "Customers", alias = "c" },
                        { name = "Orders", alias = "o" }
                    }
                },
                { statement_type = "SELECT", go_batch_index = 1, tables = { { name = "CustomerOrders" } } }
            }
        }
    },

    {
        id = 2771,
        type = "parser",
        name = "GO batch with CREATE FUNCTION",
        input = [[CREATE FUNCTION dbo.GetOrderTotal(@OrderId INT)
RETURNS DECIMAL(10,2)
AS
BEGIN
    RETURN (SELECT SUM(Quantity * UnitPrice) FROM OrderItems WHERE OrderId = @OrderId)
END
GO
SELECT dbo.GetOrderTotal(100) AS Total]],
        expected = {
            chunks = {
                { statement_type = "OTHER", go_batch_index = 0 },
                { statement_type = "SELECT", go_batch_index = 1 }
            }
        }
    },

    {
        id = 2772,
        type = "parser",
        name = "GO batch with CREATE TRIGGER",
        input = [[CREATE TRIGGER trg_UpdateInventory
ON Orders
AFTER INSERT
AS
BEGIN
    UPDATE Inventory SET Quantity = Quantity - 1
    FROM Inventory i
    INNER JOIN inserted ins ON i.ProductId = ins.ProductId
END
GO
INSERT INTO Orders (ProductId, Quantity) VALUES (1, 1)]],
        expected = {
            chunks = {
                { statement_type = "OTHER", go_batch_index = 0 },
                { statement_type = "INSERT", go_batch_index = 0 }
            }
        }
    },

    {
        id = 2773,
        type = "parser",
        name = "GO batch with ALTER statements",
        input = [[ALTER TABLE Customers ADD Email VARCHAR(255)
GO
ALTER TABLE Customers ADD CONSTRAINT UQ_Email UNIQUE (Email)
GO
SELECT * FROM Customers]],
        expected = {
            chunks = {
                { statement_type = "OTHER", go_batch_index = 0 },
                { statement_type = "OTHER", go_batch_index = 1 },
                { statement_type = "SELECT", go_batch_index = 2, tables = { { name = "Customers" } } }
            }
        }
    },

    {
        id = 2774,
        type = "parser",
        name = "GO batch with temp table across batches",
        input = [[CREATE TABLE #TempData (Id INT)
GO
INSERT INTO #TempData VALUES (1)
GO
SELECT * FROM #TempData
GO]],
        expected = {
            chunks = {
                { statement_type = "OTHER", go_batch_index = 0 },
                { statement_type = "INSERT", go_batch_index = 1 },
                { statement_type = "SELECT", go_batch_index = 2, tables = { { name = "#TempData", is_temp = true } } }
            }
        }
    },

    {
        id = 2775,
        type = "parser",
        name = "GO batch with database switching",
        input = [[USE Database1
GO
SELECT * FROM Table1
GO
USE Database2
GO
SELECT * FROM Table2
GO]],
        expected = {
            chunks = {
                { statement_type = "SELECT", go_batch_index = 1, tables = { { name = "Table1" } } },
                { statement_type = "SELECT", go_batch_index = 3, tables = { { name = "Table2" } } }
            }
        }
    },

    {
        id = 2776,
        type = "parser",
        name = "GO batch with transaction boundaries",
        input = [[BEGIN TRANSACTION
GO
INSERT INTO Table1 VALUES (1)
GO
INSERT INTO Table2 VALUES (2)
GO
COMMIT TRANSACTION
GO]],
        expected = {
            chunks = {
                { statement_type = "INSERT", go_batch_index = 1, tables = { { name = "Table1" } } },
                { statement_type = "INSERT", go_batch_index = 2, tables = { { name = "Table2" } } }
            }
        }
    },

    {
        id = 2777,
        type = "parser",
        name = "GO batch with PRINT statements",
        input = [[PRINT 'Starting process'
GO
SELECT * FROM Customers
GO
PRINT 'Process complete'
GO]],
        expected = {
            chunks = {
                { statement_type = "SELECT", go_batch_index = 1, tables = { { name = "Customers" } } }
            }
        }
    },

    {
        id = 2778,
        type = "parser",
        name = "GO batch with variable declarations",
        input = [[DECLARE @Count INT
GO
SET @Count = (SELECT COUNT(*) FROM Customers)
GO
SELECT @Count
GO]],
        expected = {
            chunks = {
                { statement_type = "DECLARE", go_batch_index = 0 },
                { statement_type = "SET", go_batch_index = 1 },
                { statement_type = "SELECT", go_batch_index = 2 }
            }
        }
    },

    {
        id = 2779,
        type = "parser",
        name = "GO batch with GRANT permissions",
        input = [[CREATE TABLE SecureData (Id INT)
GO
GRANT SELECT ON SecureData TO PublicUser
GO
SELECT * FROM SecureData]],
        expected = {
            chunks = {
                { statement_type = "OTHER", go_batch_index = 0 },
                { statement_type = "SELECT", go_batch_index = 1, tables = { { name = "SecureData" } } }
            }
        }
    },

    {
        id = 2780,
        type = "parser",
        name = "GO batch with schema creation",
        input = [[CREATE SCHEMA Sales
GO
CREATE TABLE Sales.Orders (OrderId INT)
GO
SELECT * FROM Sales.Orders
GO]],
        expected = {
            chunks = {
                { statement_type = "OTHER", go_batch_index = 0 },
                { statement_type = "OTHER", go_batch_index = 1 },
                { statement_type = "SELECT", go_batch_index = 2, tables = { { name = "Orders", schema = "Sales" } } }
            }
        }
    },

    -- =========================================================================
    -- IDs 2781-2800: Advanced T-SQL Patterns
    -- =========================================================================

    {
        id = 2781,
        type = "parser",
        name = "MERGE statement with multiple conditions",
        input = [[MERGE INTO Inventory AS target
USING StockUpdates AS source
ON target.ProductId = source.ProductId
WHEN MATCHED AND source.Quantity > 0 THEN
    UPDATE SET target.Quantity = source.Quantity
WHEN MATCHED AND source.Quantity = 0 THEN
    DELETE
WHEN NOT MATCHED THEN
    INSERT (ProductId, Quantity) VALUES (source.ProductId, source.Quantity);]],
        expected = {
            chunks = {
                {
                    statement_type = "MERGE",
                    tables = {
                        { name = "Inventory", alias = "target" },
                        { name = "StockUpdates", alias = "source" }
                    }
                }
            }
        }
    },

    {
        id = 2782,
        type = "parser",
        name = "MERGE with OUTPUT clause",
        input = [[MERGE INTO Products AS target
USING NewProducts AS source
ON target.ProductId = source.ProductId
WHEN MATCHED THEN UPDATE SET target.Price = source.Price
WHEN NOT MATCHED THEN INSERT (ProductId, Price) VALUES (source.ProductId, source.Price)
OUTPUT $action, inserted.ProductId, deleted.Price;]],
        expected = {
            chunks = {
                {
                    statement_type = "MERGE",
                    tables = {
                        { name = "Products", alias = "target" },
                        { name = "NewProducts", alias = "source" }
                    }
                }
            }
        }
    },

    {
        id = 2783,
        type = "parser",
        name = "CROSS APPLY with inline table-valued function",
        input = [[SELECT o.OrderId, od.ProductName, od.Quantity
FROM Orders o
CROSS APPLY dbo.GetOrderDetails(o.OrderId) od]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = { { name = "Orders", alias = "o" } }
                }
            }
        }
    },

    {
        id = 2784,
        type = "parser",
        name = "OUTER APPLY for LEFT JOIN equivalent",
        input = [[SELECT c.CustomerId, c.Name, recent.OrderDate
FROM Customers c
OUTER APPLY (
    SELECT TOP 1 OrderDate
    FROM Orders
    WHERE CustomerId = c.CustomerId
    ORDER BY OrderDate DESC
) recent]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = { { name = "Customers", alias = "c" } },
                    subqueries = {
                        { tables = { { name = "Orders" } } }
                    }
                }
            }
        }
    },

    {
        id = 2785,
        type = "parser",
        name = "CROSS APPLY with VALUES constructor",
        input = [[SELECT p.ProductId, v.StatusCode
FROM Products p
CROSS APPLY (VALUES (1, 'Active'), (2, 'Inactive')) v(StatusId, StatusCode)
WHERE p.Status = v.StatusId]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = { { name = "Products", alias = "p" } }
                }
            }
        }
    },

    {
        id = 2786,
        type = "parser",
        name = "UNION combining multiple tables",
        input = [[SELECT CustomerId, Name FROM Customers
UNION
SELECT SupplierId, Name FROM Suppliers
UNION
SELECT EmployeeId, Name FROM Employees]],
        expected = {
            chunks = {
                { statement_type = "SELECT", tables = { { name = "Customers" } } },
                { statement_type = "SELECT", tables = { { name = "Suppliers" } } },
                { statement_type = "SELECT", tables = { { name = "Employees" } } }
            }
        }
    },

    {
        id = 2787,
        type = "parser",
        name = "INTERSECT for finding common records",
        input = [[SELECT ProductId FROM CurrentInventory
INTERSECT
SELECT ProductId FROM OrderedProducts]],
        expected = {
            chunks = {
                { statement_type = "SELECT", tables = { { name = "CurrentInventory" } } },
                { statement_type = "SELECT", tables = { { name = "OrderedProducts" } } }
            }
        }
    },

    {
        id = 2788,
        type = "parser",
        name = "EXCEPT for finding differences",
        input = [[SELECT ProductId FROM AllProducts
EXCEPT
SELECT ProductId FROM DiscontinuedProducts]],
        expected = {
            chunks = {
                { statement_type = "SELECT", tables = { { name = "AllProducts" } } },
                { statement_type = "SELECT", tables = { { name = "DiscontinuedProducts" } } }
            }
        }
    },

    {
        id = 2789,
        type = "parser",
        name = "PIVOT for rotating data",
        input = [[SELECT *
FROM (
    SELECT Year, Quarter, Sales
    FROM SalesData
) AS SourceTable
PIVOT (
    SUM(Sales)
    FOR Quarter IN ([Q1], [Q2], [Q3], [Q4])
) AS PivotTable]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    subqueries = {
                        { tables = { { name = "SalesData" } } }
                    }
                }
            }
        }
    },

    {
        id = 2790,
        type = "parser",
        name = "UNPIVOT for normalizing data",
        input = [[SELECT ProductId, Quarter, Sales
FROM (
    SELECT ProductId, Q1, Q2, Q3, Q4
    FROM QuarterlySales
) AS SourceTable
UNPIVOT (
    Sales FOR Quarter IN (Q1, Q2, Q3, Q4)
) AS UnpivotTable]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    subqueries = {
                        { tables = { { name = "QuarterlySales" } } }
                    }
                }
            }
        }
    },

    {
        id = 2791,
        type = "parser",
        name = "INSERT with OUTPUT clause",
        input = [[INSERT INTO Orders (CustomerId, OrderDate)
OUTPUT inserted.OrderId, inserted.CustomerId
VALUES (100, GETDATE())]],
        expected = {
            chunks = {
                { statement_type = "INSERT", tables = { { name = "Orders" } } }
            }
        }
    },

    {
        id = 2792,
        type = "parser",
        name = "UPDATE with OUTPUT clause capturing old and new values",
        input = [[UPDATE Products
SET Price = Price * 1.1
OUTPUT deleted.ProductId, deleted.Price AS OldPrice, inserted.Price AS NewPrice
WHERE CategoryId = 5]],
        expected = {
            chunks = {
                { statement_type = "UPDATE", tables = { { name = "Products" } } }
            }
        }
    },

    {
        id = 2793,
        type = "parser",
        name = "DELETE with OUTPUT INTO temp table",
        input = [[DELETE FROM ArchivedRecords
OUTPUT deleted.* INTO #DeletedRecords
WHERE ArchiveDate < DATEADD(YEAR, -5, GETDATE())]],
        expected = {
            chunks = {
                { statement_type = "DELETE", tables = { { name = "ArchivedRecords" } } }
            }
        }
    },

    {
        id = 2794,
        type = "parser",
        name = "Complex JOIN with multiple APPLY operators",
        input = [[SELECT c.CustomerId, o.OrderId, od.ProductName
FROM Customers c
CROSS APPLY (SELECT TOP 5 * FROM Orders WHERE CustomerId = c.CustomerId) o
OUTER APPLY (SELECT * FROM OrderDetails WHERE OrderId = o.OrderId) od]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = { { name = "Customers", alias = "c" } },
                    subqueries = {
                        { tables = { { name = "Orders" } } },
                        { tables = { { name = "OrderDetails" } } }
                    }
                }
            }
        }
    },

    {
        id = 2795,
        type = "parser",
        name = "XML PATH for string concatenation",
        input = [[SELECT CustomerId,
    STUFF((SELECT ', ' + ProductName
           FROM OrderItems
           WHERE OrderItems.CustomerId = Customers.CustomerId
           FOR XML PATH('')), 1, 2, '') AS Products
FROM Customers]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = { { name = "Customers" } },
                    subqueries = {
                        { tables = { { name = "OrderItems" } } }
                    }
                }
            }
        }
    },

    {
        id = 2796,
        type = "parser",
        name = "Table-valued function in FROM clause",
        input = [[SELECT *
FROM dbo.GetCustomerOrders(100) AS orders
WHERE orders.OrderDate > '2024-01-01']],
        expected = {
            chunks = {
                { statement_type = "SELECT" }
            }
        }
    },

    {
        id = 2797,
        type = "parser",
        name = "Multiple OUTER APPLY with aggregation",
        input = [[SELECT
    e.EmployeeId,
    e.Name,
    proj.ProjectCount,
    task.TaskCount
FROM Employees e
OUTER APPLY (
    SELECT COUNT(*) AS ProjectCount
    FROM Projects
    WHERE ManagerId = e.EmployeeId
) proj
OUTER APPLY (
    SELECT COUNT(*) AS TaskCount
    FROM Tasks
    WHERE AssignedTo = e.EmployeeId
) task]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = { { name = "Employees", alias = "e" } },
                    subqueries = {
                        { tables = { { name = "Projects" } } },
                        { tables = { { name = "Tasks" } } }
                    }
                }
            }
        }
    },

    {
        id = 2798,
        type = "parser",
        name = "GROUPING SETS for multiple grouping levels",
        input = [[SELECT
    Region,
    Category,
    SUM(Sales) AS TotalSales
FROM SalesData
GROUP BY GROUPING SETS (
    (Region, Category),
    (Region),
    (Category),
    ()
)]],
        expected = {
            chunks = {
                { statement_type = "SELECT", tables = { { name = "SalesData" } } }
            }
        }
    },

    {
        id = 2799,
        type = "parser",
        name = "Common Table Expression with MERGE",
        input = [[WITH UpdatedPrices AS (
    SELECT ProductId, Price * 1.1 AS NewPrice
    FROM Products
    WHERE CategoryId = 5
)
MERGE INTO Products AS target
USING UpdatedPrices AS source
ON target.ProductId = source.ProductId
WHEN MATCHED THEN
    UPDATE SET target.Price = source.NewPrice;]],
        expected = {
            chunks = {
                {
                    statement_type = "MERGE",
                    ctes = {
                        { name = "UpdatedPrices", tables = { { name = "Products" } } }
                    },
                    tables = {
                        { name = "Products", alias = "target" }
                    }
                }
            }
        }
    },

    {
        id = 2800,
        type = "parser",
        name = "Complex production query with CTEs, subqueries, and multiple joins",
        input = [[WITH
MonthlyOrders AS (
    SELECT
        CustomerId,
        YEAR(OrderDate) AS Year,
        MONTH(OrderDate) AS Month,
        COUNT(*) AS OrderCount,
        SUM(TotalAmount) AS MonthlyTotal
    FROM Orders
    GROUP BY CustomerId, YEAR(OrderDate), MONTH(OrderDate)
),
CustomerTiers AS (
    SELECT
        CustomerId,
        CASE
            WHEN SUM(MonthlyTotal) > 50000 THEN 'Platinum'
            WHEN SUM(MonthlyTotal) > 20000 THEN 'Gold'
            ELSE 'Silver'
        END AS Tier
    FROM MonthlyOrders
    GROUP BY CustomerId
)
SELECT
    c.CustomerId,
    c.CustomerName,
    ct.Tier,
    mo.Year,
    mo.Month,
    mo.OrderCount,
    mo.MonthlyTotal,
    (SELECT AVG(MonthlyTotal) FROM MonthlyOrders WHERE CustomerId = c.CustomerId) AS AvgMonthly
FROM Customers c
INNER JOIN CustomerTiers ct ON c.CustomerId = ct.CustomerId
INNER JOIN MonthlyOrders mo ON c.CustomerId = mo.CustomerId
WHERE c.Active = 1
    AND EXISTS (
        SELECT 1 FROM Orders o
        WHERE o.CustomerId = c.CustomerId
        AND o.OrderDate > DATEADD(MONTH, -6, GETDATE())
    )
ORDER BY ct.Tier, mo.MonthlyTotal DESC]],
        expected = {
            chunks = {
                {
                    statement_type = "WITH",
                    ctes = {
                        { name = "MonthlyOrders", tables = { { name = "Orders" } } },
                        { name = "CustomerTiers" }
                    },
                    tables = {
                        { name = "Customers", alias = "c" }
                    },
                    subqueries = {
                        {},
                        { tables = { { name = "Orders", alias = "o" } } }
                    }
                }
            }
        }
    }
}
