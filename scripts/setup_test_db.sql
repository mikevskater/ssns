USE master;
GO

-- ============================================================================
-- SSNS Test Database Setup Script
-- Creates all database objects required for IntelliSense testing
-- ============================================================================

-- Create the test database if it doesn't exist
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = N'vim_dadbod_test')
BEGIN
    CREATE DATABASE vim_dadbod_test;
END
GO

USE vim_dadbod_test;
GO

-- ============================================================================
-- SCHEMAS
-- ============================================================================

-- Create hr schema
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = N'hr')
BEGIN
    EXEC('CREATE SCHEMA hr');
END
GO

-- Create Branch schema
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = N'Branch')
BEGIN
    EXEC('CREATE SCHEMA Branch');
END
GO

-- ============================================================================
-- TABLES - dbo schema
-- ============================================================================

-- Departments table (referenced by Employees)
IF OBJECT_ID('dbo.Departments', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Departments (
        DepartmentID INT PRIMARY KEY IDENTITY(1,1),
        DepartmentName NVARCHAR(100) NOT NULL,
        ManagerID INT NULL,
        Budget DECIMAL(18,2) NULL
    );
END
GO

-- Employees table (main table for testing)
IF OBJECT_ID('dbo.Employees', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Employees (
        EmployeeID INT PRIMARY KEY IDENTITY(1,1),
        FirstName NVARCHAR(50) NOT NULL,
        LastName NVARCHAR(50) NOT NULL,
        Email NVARCHAR(100) NULL,
        DepartmentID INT NULL REFERENCES dbo.Departments(DepartmentID),
        HireDate DATE NULL,
        Salary DECIMAL(18,2) NULL,
        IsActive BIT DEFAULT 1
    );
END
GO

-- Projects table
IF OBJECT_ID('dbo.Projects', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Projects (
        ProjectID INT PRIMARY KEY IDENTITY(1,1),
        ProjectName NVARCHAR(100) NOT NULL,
        StartDate DATE NULL,
        EndDate DATE NULL,
        DepartmentID INT NULL REFERENCES dbo.Departments(DepartmentID),
        Budget DECIMAL(18,2) NULL,
        IsActive BIT DEFAULT 1
    );
END
GO

-- newTable (simple test table)
IF OBJECT_ID('dbo.newTable', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.newTable (
        Id INT PRIMARY KEY IDENTITY(1,1),
        Name NVARCHAR(100) NULL,
        CreatedDate DATETIME DEFAULT GETDATE()
    );
END
GO

-- test_table (simple test table)
IF OBJECT_ID('dbo.test_table', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.test_table (
        Id INT PRIMARY KEY IDENTITY(1,1),
        Name NVARCHAR(100) NULL,
        Value INT NULL
    );
END
GO

-- ============================================================================
-- TABLES - hr schema
-- ============================================================================

-- Benefits table
IF OBJECT_ID('hr.Benefits', 'U') IS NULL
BEGIN
    CREATE TABLE hr.Benefits (
        BenefitID INT PRIMARY KEY IDENTITY(1,1),
        BenefitName NVARCHAR(100) NOT NULL,
        BenefitType NVARCHAR(50) NULL,
        Cost DECIMAL(18,2) NULL,
        EmployeeID INT NULL
    );
END
GO

-- ============================================================================
-- TABLES - Branch schema
-- ============================================================================

-- AllDivisions table
IF OBJECT_ID('Branch.AllDivisions', 'U') IS NULL
BEGIN
    CREATE TABLE Branch.AllDivisions (
        DivisionID INT PRIMARY KEY IDENTITY(1,1),
        DivisionName NVARCHAR(100) NOT NULL,
        Region NVARCHAR(50) NULL
    );
END
GO

-- CentralDivision table
IF OBJECT_ID('Branch.CentralDivision', 'U') IS NULL
BEGIN
    CREATE TABLE Branch.CentralDivision (
        Id INT PRIMARY KEY IDENTITY(1,1),
        Name NVARCHAR(100) NOT NULL,
        Location NVARCHAR(100) NULL
    );
END
GO

-- EasternDivision table
IF OBJECT_ID('Branch.EasternDivision', 'U') IS NULL
BEGIN
    CREATE TABLE Branch.EasternDivision (
        Id INT PRIMARY KEY IDENTITY(1,1),
        Name NVARCHAR(100) NOT NULL,
        Location NVARCHAR(100) NULL
    );
END
GO

-- WesternDivision table
IF OBJECT_ID('Branch.WesternDivision', 'U') IS NULL
BEGIN
    CREATE TABLE Branch.WesternDivision (
        Id INT PRIMARY KEY IDENTITY(1,1),
        Name NVARCHAR(100) NOT NULL,
        Location NVARCHAR(100) NULL
    );
END
GO

-- DivisionMetrics table
IF OBJECT_ID('Branch.DivisionMetrics', 'U') IS NULL
BEGIN
    CREATE TABLE Branch.DivisionMetrics (
        MetricID INT PRIMARY KEY IDENTITY(1,1),
        DivisionID INT NULL,
        MetricName NVARCHAR(100) NULL,
        MetricValue DECIMAL(18,2) NULL,
        RecordedDate DATE NULL
    );
END
GO

-- ============================================================================
-- VIEWS - dbo schema
-- ============================================================================

-- vw_ActiveEmployees
IF OBJECT_ID('dbo.vw_ActiveEmployees', 'V') IS NOT NULL
    DROP VIEW dbo.vw_ActiveEmployees;
GO
CREATE VIEW dbo.vw_ActiveEmployees AS
SELECT EmployeeID, FirstName, LastName, Email, DepartmentID, HireDate, Salary
FROM dbo.Employees
WHERE IsActive = 1;
GO

-- vw_DepartmentSummary
IF OBJECT_ID('dbo.vw_DepartmentSummary', 'V') IS NOT NULL
    DROP VIEW dbo.vw_DepartmentSummary;
GO
CREATE VIEW dbo.vw_DepartmentSummary AS
SELECT
    d.DepartmentID,
    d.DepartmentName,
    d.Budget,
    COUNT(e.EmployeeID) AS EmployeeCount,
    AVG(e.Salary) AS AvgSalary
FROM dbo.Departments d
LEFT JOIN dbo.Employees e ON d.DepartmentID = e.DepartmentID
GROUP BY d.DepartmentID, d.DepartmentName, d.Budget;
GO

-- vw_ProjectStatus
IF OBJECT_ID('dbo.vw_ProjectStatus', 'V') IS NOT NULL
    DROP VIEW dbo.vw_ProjectStatus;
GO
CREATE VIEW dbo.vw_ProjectStatus AS
SELECT
    ProjectID,
    ProjectName,
    StartDate,
    EndDate,
    Budget,
    CASE
        WHEN EndDate < GETDATE() THEN 'Completed'
        WHEN StartDate > GETDATE() THEN 'Not Started'
        ELSE 'In Progress'
    END AS Status
FROM dbo.Projects;
GO

-- ============================================================================
-- VIEWS - hr schema
-- ============================================================================

-- vw_EmployeeBenefits
IF OBJECT_ID('hr.vw_EmployeeBenefits', 'V') IS NOT NULL
    DROP VIEW hr.vw_EmployeeBenefits;
GO
CREATE VIEW hr.vw_EmployeeBenefits AS
SELECT
    e.EmployeeID,
    e.FirstName,
    e.LastName,
    b.BenefitName,
    b.BenefitType,
    b.Cost
FROM dbo.Employees e
LEFT JOIN hr.Benefits b ON e.EmployeeID = b.EmployeeID;
GO

-- ============================================================================
-- STORED PROCEDURES - dbo schema
-- ============================================================================

-- sp_SearchEmployees
IF OBJECT_ID('dbo.sp_SearchEmployees', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_SearchEmployees;
GO
CREATE PROCEDURE dbo.sp_SearchEmployees
    @SearchTerm NVARCHAR(100) = NULL
AS
BEGIN
    SELECT EmployeeID, FirstName, LastName, Email
    FROM dbo.Employees
    WHERE @SearchTerm IS NULL
       OR FirstName LIKE '%' + @SearchTerm + '%'
       OR LastName LIKE '%' + @SearchTerm + '%';
END
GO

-- usp_DepartmentBudgetReport
IF OBJECT_ID('dbo.usp_DepartmentBudgetReport', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_DepartmentBudgetReport;
GO
CREATE PROCEDURE dbo.usp_DepartmentBudgetReport
AS
BEGIN
    SELECT DepartmentName, Budget
    FROM dbo.Departments
    ORDER BY Budget DESC;
END
GO

-- usp_GetEmployeesByDepartment
IF OBJECT_ID('dbo.usp_GetEmployeesByDepartment', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_GetEmployeesByDepartment;
GO
CREATE PROCEDURE dbo.usp_GetEmployeesByDepartment
    @DepartmentID INT
AS
BEGIN
    SELECT EmployeeID, FirstName, LastName, Email, Salary
    FROM dbo.Employees
    WHERE DepartmentID = @DepartmentID;
END
GO

-- usp_InsertEmployee
IF OBJECT_ID('dbo.usp_InsertEmployee', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_InsertEmployee;
GO
CREATE PROCEDURE dbo.usp_InsertEmployee
    @FirstName NVARCHAR(50),
    @LastName NVARCHAR(50),
    @Email NVARCHAR(100) = NULL,
    @DepartmentID INT = NULL,
    @Salary DECIMAL(18,2) = NULL
AS
BEGIN
    INSERT INTO dbo.Employees (FirstName, LastName, Email, DepartmentID, HireDate, Salary)
    VALUES (@FirstName, @LastName, @Email, @DepartmentID, GETDATE(), @Salary);

    SELECT SCOPE_IDENTITY() AS NewEmployeeID;
END
GO

-- usp_test
IF OBJECT_ID('dbo.usp_test', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_test;
GO
CREATE PROCEDURE dbo.usp_test
AS
BEGIN
    SELECT 'Test procedure executed' AS Message;
END
GO

-- usp_UpdateEmployeeSalary
IF OBJECT_ID('dbo.usp_UpdateEmployeeSalary', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_UpdateEmployeeSalary;
GO
CREATE PROCEDURE dbo.usp_UpdateEmployeeSalary
    @EmployeeID INT,
    @NewSalary DECIMAL(18,2)
AS
BEGIN
    UPDATE dbo.Employees
    SET Salary = @NewSalary
    WHERE EmployeeID = @EmployeeID;
END
GO

-- ============================================================================
-- STORED PROCEDURES - hr schema
-- ============================================================================

-- usp_GetEmployeeBenefits
IF OBJECT_ID('hr.usp_GetEmployeeBenefits', 'P') IS NOT NULL
    DROP PROCEDURE hr.usp_GetEmployeeBenefits;
GO
CREATE PROCEDURE hr.usp_GetEmployeeBenefits
    @EmployeeID INT
AS
BEGIN
    SELECT b.BenefitID, b.BenefitName, b.BenefitType, b.Cost
    FROM hr.Benefits b
    WHERE b.EmployeeID = @EmployeeID;
END
GO

-- ============================================================================
-- FUNCTIONS - dbo schema (Scalar)
-- ============================================================================

-- fn_CalculateYearsOfService
IF OBJECT_ID('dbo.fn_CalculateYearsOfService', 'FN') IS NOT NULL
    DROP FUNCTION dbo.fn_CalculateYearsOfService;
GO
CREATE FUNCTION dbo.fn_CalculateYearsOfService(@EmployeeID INT)
RETURNS INT
AS
BEGIN
    DECLARE @Years INT;
    SELECT @Years = DATEDIFF(YEAR, HireDate, GETDATE())
    FROM dbo.Employees
    WHERE EmployeeID = @EmployeeID;
    RETURN ISNULL(@Years, 0);
END
GO

-- fn_GetEmployeeFullName
IF OBJECT_ID('dbo.fn_GetEmployeeFullName', 'FN') IS NOT NULL
    DROP FUNCTION dbo.fn_GetEmployeeFullName;
GO
CREATE FUNCTION dbo.fn_GetEmployeeFullName(@EmployeeID INT)
RETURNS NVARCHAR(100)
AS
BEGIN
    DECLARE @FullName NVARCHAR(100);
    SELECT @FullName = FirstName + ' ' + LastName
    FROM dbo.Employees
    WHERE EmployeeID = @EmployeeID;
    RETURN @FullName;
END
GO

-- ============================================================================
-- FUNCTIONS - dbo schema (Table-Valued)
-- ============================================================================

-- fn_GetActiveProjects
IF OBJECT_ID('dbo.fn_GetActiveProjects', 'IF') IS NOT NULL
    DROP FUNCTION dbo.fn_GetActiveProjects;
GO
CREATE FUNCTION dbo.fn_GetActiveProjects()
RETURNS TABLE
AS
RETURN (
    SELECT ProjectID, ProjectName, StartDate, EndDate, Budget
    FROM dbo.Projects
    WHERE IsActive = 1
);
GO

-- fn_GetEmployeesByDepartment (table-valued)
IF OBJECT_ID('dbo.fn_GetEmployeesByDepartment', 'IF') IS NOT NULL
    DROP FUNCTION dbo.fn_GetEmployeesByDepartment;
GO
CREATE FUNCTION dbo.fn_GetEmployeesByDepartment(@DepartmentID INT)
RETURNS TABLE
AS
RETURN (
    SELECT EmployeeID, FirstName, LastName, Email, Salary
    FROM dbo.Employees
    WHERE DepartmentID = @DepartmentID
);
GO

-- fn_GetEmployeesBySalaryRange
IF OBJECT_ID('dbo.fn_GetEmployeesBySalaryRange', 'IF') IS NOT NULL
    DROP FUNCTION dbo.fn_GetEmployeesBySalaryRange;
GO
CREATE FUNCTION dbo.fn_GetEmployeesBySalaryRange(@MinSalary DECIMAL(18,2), @MaxSalary DECIMAL(18,2))
RETURNS TABLE
AS
RETURN (
    SELECT EmployeeID, FirstName, LastName, Email, Salary
    FROM dbo.Employees
    WHERE Salary BETWEEN @MinSalary AND @MaxSalary
);
GO

-- ============================================================================
-- FUNCTIONS - hr schema
-- ============================================================================

-- fn_GetTotalBenefitCost
IF OBJECT_ID('hr.fn_GetTotalBenefitCost', 'FN') IS NOT NULL
    DROP FUNCTION hr.fn_GetTotalBenefitCost;
GO
CREATE FUNCTION hr.fn_GetTotalBenefitCost(@EmployeeID INT)
RETURNS DECIMAL(18,2)
AS
BEGIN
    DECLARE @Total DECIMAL(18,2);
    SELECT @Total = SUM(Cost)
    FROM hr.Benefits
    WHERE EmployeeID = @EmployeeID;
    RETURN ISNULL(@Total, 0);
END
GO

-- ============================================================================
-- FUNCTIONS - Branch schema
-- ============================================================================

-- GetDivisionMetrics (table-valued)
IF OBJECT_ID('Branch.GetDivisionMetrics', 'IF') IS NOT NULL
    DROP FUNCTION Branch.GetDivisionMetrics;
GO
CREATE FUNCTION Branch.GetDivisionMetrics(@DivisionID INT)
RETURNS TABLE
AS
RETURN (
    SELECT MetricID, MetricName, MetricValue, RecordedDate
    FROM Branch.DivisionMetrics
    WHERE DivisionID = @DivisionID
);
GO

-- ============================================================================
-- SYNONYMS - dbo schema
-- ============================================================================

-- syn_ActiveEmployees -> vw_ActiveEmployees
IF OBJECT_ID('dbo.syn_ActiveEmployees', 'SN') IS NOT NULL
    DROP SYNONYM dbo.syn_ActiveEmployees;
GO
CREATE SYNONYM dbo.syn_ActiveEmployees FOR dbo.vw_ActiveEmployees;
GO

-- syn_Depts -> Departments
IF OBJECT_ID('dbo.syn_Depts', 'SN') IS NOT NULL
    DROP SYNONYM dbo.syn_Depts;
GO
CREATE SYNONYM dbo.syn_Depts FOR dbo.Departments;
GO

-- syn_Employees -> Employees
IF OBJECT_ID('dbo.syn_Employees', 'SN') IS NOT NULL
    DROP SYNONYM dbo.syn_Employees;
GO
CREATE SYNONYM dbo.syn_Employees FOR dbo.Employees;
GO

-- syn_ExternalTable (placeholder - points to test_table)
IF OBJECT_ID('dbo.syn_ExternalTable', 'SN') IS NOT NULL
    DROP SYNONYM dbo.syn_ExternalTable;
GO
CREATE SYNONYM dbo.syn_ExternalTable FOR dbo.test_table;
GO

-- syn_HRBenefits -> hr.Benefits
IF OBJECT_ID('dbo.syn_HRBenefits', 'SN') IS NOT NULL
    DROP SYNONYM dbo.syn_HRBenefits;
GO
CREATE SYNONYM dbo.syn_HRBenefits FOR hr.Benefits;
GO

-- syn_Staff -> Employees
IF OBJECT_ID('dbo.syn_Staff', 'SN') IS NOT NULL
    DROP SYNONYM dbo.syn_Staff;
GO
CREATE SYNONYM dbo.syn_Staff FOR dbo.Employees;
GO

-- syn_TestRecords -> test_table
IF OBJECT_ID('dbo.syn_TestRecords', 'SN') IS NOT NULL
    DROP SYNONYM dbo.syn_TestRecords;
GO
CREATE SYNONYM dbo.syn_TestRecords FOR dbo.test_table;
GO

-- ============================================================================
-- LINKED SERVERS (placeholders - these would typically require admin setup)
-- ============================================================================
-- Note: Linked servers (TEST, Branch_Prod) cannot be created in a script
-- without proper server access. These are typically set up by DBAs.
-- The tests may need to skip linked server tests if not available.

-- ============================================================================
-- SAMPLE DATA
-- ============================================================================

-- Insert sample departments if empty
IF NOT EXISTS (SELECT 1 FROM dbo.Departments)
BEGIN
    INSERT INTO dbo.Departments (DepartmentName, Budget)
    VALUES
        ('Engineering', 500000.00),
        ('Sales', 300000.00),
        ('Marketing', 200000.00),
        ('HR', 150000.00),
        ('Finance', 250000.00);
END
GO

-- Insert sample employees if empty
IF NOT EXISTS (SELECT 1 FROM dbo.Employees)
BEGIN
    INSERT INTO dbo.Employees (FirstName, LastName, Email, DepartmentID, HireDate, Salary, IsActive)
    VALUES
        ('John', 'Doe', 'john.doe@company.com', 1, '2020-01-15', 75000.00, 1),
        ('Jane', 'Smith', 'jane.smith@company.com', 1, '2019-06-20', 85000.00, 1),
        ('Bob', 'Johnson', 'bob.johnson@company.com', 2, '2021-03-10', 65000.00, 1),
        ('Alice', 'Williams', 'alice.williams@company.com', 3, '2018-11-05', 70000.00, 1),
        ('Charlie', 'Brown', 'charlie.brown@company.com', 4, '2022-02-28', 55000.00, 1),
        ('Diana', 'Davis', 'diana.davis@company.com', 5, '2017-09-12', 90000.00, 1),
        ('Inactive', 'User', 'inactive@company.com', 1, '2015-01-01', 50000.00, 0);
END
GO

-- Insert sample projects if empty
IF NOT EXISTS (SELECT 1 FROM dbo.Projects)
BEGIN
    INSERT INTO dbo.Projects (ProjectName, StartDate, EndDate, DepartmentID, Budget, IsActive)
    VALUES
        ('Website Redesign', '2024-01-01', '2024-06-30', 1, 100000.00, 1),
        ('Sales Dashboard', '2024-03-01', '2024-09-30', 2, 50000.00, 1),
        ('Marketing Campaign', '2024-02-01', '2024-04-30', 3, 25000.00, 1),
        ('Legacy System Migration', '2023-06-01', '2023-12-31', 1, 200000.00, 0);
END
GO

-- Insert sample benefits if empty
IF NOT EXISTS (SELECT 1 FROM hr.Benefits)
BEGIN
    INSERT INTO hr.Benefits (BenefitName, BenefitType, Cost, EmployeeID)
    VALUES
        ('Health Insurance', 'Medical', 500.00, 1),
        ('Dental Insurance', 'Medical', 50.00, 1),
        ('401k Match', 'Retirement', 300.00, 1),
        ('Health Insurance', 'Medical', 500.00, 2),
        ('Vision Insurance', 'Medical', 25.00, 2);
END
GO

-- Insert sample division data if empty
IF NOT EXISTS (SELECT 1 FROM Branch.AllDivisions)
BEGIN
    INSERT INTO Branch.AllDivisions (DivisionName, Region)
    VALUES
        ('North Division', 'North'),
        ('South Division', 'South'),
        ('East Division', 'East'),
        ('West Division', 'West');
END
GO

-- ============================================================================
-- FK CHAIN TABLES - For IntelliSense JOIN testing
-- ============================================================================

-- Regions table (root of FK chain)
IF OBJECT_ID('dbo.Regions', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Regions (
        RegionID INT PRIMARY KEY IDENTITY(1,1),
        RegionName NVARCHAR(100) NOT NULL
    );

    INSERT INTO dbo.Regions (RegionName) VALUES
        ('North America'), ('Europe'), ('Asia'), ('South America');
END
GO

-- Countries table (references Regions)
IF OBJECT_ID('dbo.Countries', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Countries (
        CountryID INT PRIMARY KEY IDENTITY(1,1),
        CountryName NVARCHAR(100) NOT NULL,
        RegionID INT NULL
    );

    INSERT INTO dbo.Countries (CountryName, RegionID) VALUES
        ('USA', 1), ('Canada', 1), ('UK', 2), ('Germany', 2), ('Japan', 3), ('Brazil', 4);
END
GO

-- Customers table update - add CountryID if missing
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Customers') AND name = 'CountryID')
BEGIN
    ALTER TABLE dbo.Customers ADD CountryID INT NULL;
END
GO

-- Orders table update - add EmployeeID FK if missing
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Orders') AND name = 'EmployeeID')
BEGIN
    ALTER TABLE dbo.Orders ADD EmployeeID INT NULL;
END
GO

-- ============================================================================
-- FOREIGN KEY CONSTRAINTS - For FK chain testing
-- ============================================================================

-- FK: Employees -> Departments
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_Employees_Department')
AND EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Employees') AND name = 'DepartmentID')
BEGIN
    -- Check if constraint already exists with different name
    IF NOT EXISTS (
        SELECT 1 FROM sys.foreign_keys fk
        JOIN sys.foreign_key_columns fkc ON fk.object_id = fkc.constraint_object_id
        JOIN sys.columns c ON fkc.parent_column_id = c.column_id AND fkc.parent_object_id = c.object_id
        WHERE fk.parent_object_id = OBJECT_ID('dbo.Employees') AND c.name = 'DepartmentID'
    )
    BEGIN
        ALTER TABLE dbo.Employees
        ADD CONSTRAINT FK_Employees_Department
        FOREIGN KEY (DepartmentID) REFERENCES dbo.Departments(DepartmentID);
    END
END
GO

-- FK: Countries -> Regions
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_Countries_Regions')
BEGIN
    ALTER TABLE dbo.Countries
    ADD CONSTRAINT FK_Countries_Regions
    FOREIGN KEY (RegionID) REFERENCES dbo.Regions(RegionID);
END
GO

-- FK: Customers -> Countries (for 2-hop chain: Customers -> Countries -> Regions)
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_Customers_Countries')
AND EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Customers') AND name = 'CountryID')
BEGIN
    ALTER TABLE dbo.Customers
    ADD CONSTRAINT FK_Customers_Countries
    FOREIGN KEY (CountryID) REFERENCES dbo.Countries(CountryID);
END
GO

-- FK: Orders -> Customers (for 3-hop chain: Orders -> Customers -> Countries -> Regions)
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_Orders_Customers')
AND EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Orders') AND name = 'CustomerId')
BEGIN
    ALTER TABLE dbo.Orders
    ADD CONSTRAINT FK_Orders_Customers
    FOREIGN KEY (CustomerId) REFERENCES dbo.Customers(Id);
END
GO

-- FK: Orders -> Employees
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_Orders_Employees')
AND EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Orders') AND name = 'EmployeeID')
BEGIN
    ALTER TABLE dbo.Orders
    ADD CONSTRAINT FK_Orders_Employees
    FOREIGN KEY (EmployeeID) REFERENCES dbo.Employees(EmployeeID);
END
GO

-- FK: hr.Benefits -> Employees
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_Benefits_Employees')
BEGIN
    ALTER TABLE hr.Benefits
    ADD CONSTRAINT FK_Benefits_Employees
    FOREIGN KEY (EmployeeID) REFERENCES dbo.Employees(EmployeeID);
END
GO

-- FK: Projects -> Departments
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_Projects_Department')
AND EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Projects') AND name = 'DepartmentID')
BEGIN
    -- Check if constraint already exists with different name
    IF NOT EXISTS (
        SELECT 1 FROM sys.foreign_keys fk
        JOIN sys.foreign_key_columns fkc ON fk.object_id = fkc.constraint_object_id
        JOIN sys.columns c ON fkc.parent_column_id = c.column_id AND fkc.parent_object_id = c.object_id
        WHERE fk.parent_object_id = OBJECT_ID('dbo.Projects') AND c.name = 'DepartmentID'
    )
    BEGIN
        ALTER TABLE dbo.Projects
        ADD CONSTRAINT FK_Projects_Department
        FOREIGN KEY (DepartmentID) REFERENCES dbo.Departments(DepartmentID);
    END
END
GO

-- FK: Branch.DivisionMetrics -> Branch.AllDivisions
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_DivisionMetrics_AllDivisions')
BEGIN
    ALTER TABLE Branch.DivisionMetrics
    ADD CONSTRAINT FK_DivisionMetrics_AllDivisions
    FOREIGN KEY (DivisionID) REFERENCES Branch.AllDivisions(DivisionID);
END
GO

-- ============================================================================
-- VERIFY FK SETUP
-- ============================================================================

SELECT
    FK.name AS FK_Name,
    OBJECT_SCHEMA_NAME(FK.parent_object_id) AS ParentSchema,
    PT.name AS ParentTable,
    PC.name AS ParentColumn,
    OBJECT_SCHEMA_NAME(FK.referenced_object_id) AS RefSchema,
    RT.name AS ReferencedTable,
    RC.name AS ReferencedColumn
FROM sys.foreign_keys FK
JOIN sys.foreign_key_columns FKC ON FK.object_id = FKC.constraint_object_id
JOIN sys.tables PT ON FK.parent_object_id = PT.object_id
JOIN sys.columns PC ON FKC.parent_object_id = PC.object_id AND FKC.parent_column_id = PC.column_id
JOIN sys.tables RT ON FK.referenced_object_id = RT.object_id
JOIN sys.columns RC ON FKC.referenced_object_id = RC.object_id AND FKC.referenced_column_id = RC.column_id
ORDER BY ParentSchema, PT.name, FK.name;
GO

PRINT 'SSNS Test Database setup completed successfully!';
GO
