-- Test file: ddl_options.lua
-- IDs: 8916-8949
-- Tests: DDL options - CREATE TABLE constraints and column formatting

return {
    -- create_table_constraint_newline tests
    -- When true (default): Constraints start on new line
    -- When false: Constraints stay inline

    -- Basic CONSTRAINT keyword
    {
        id = 8916,
        type = "formatter",
        name = "create_table_constraint_newline true - PRIMARY KEY constraint",
        input = "CREATE TABLE users (id INT, name VARCHAR(100), CONSTRAINT pk_users PRIMARY KEY (id))",
        opts = { create_table_constraint_newline = true },
        expected = {
            -- CONSTRAINT should be on new line
            matches = { ",\n%s+CONSTRAINT pk_users PRIMARY KEY" }
        }
    },
    {
        id = 8917,
        type = "formatter",
        name = "create_table_constraint_newline false - PRIMARY KEY constraint inline",
        input = "CREATE TABLE users (id INT, name VARCHAR(100), CONSTRAINT pk_users PRIMARY KEY (id))",
        opts = { create_table_constraint_newline = false, create_table_column_newline = false },
        expected = {
            -- CONSTRAINT stays inline (both column and constraint newlines disabled)
            contains = { ", CONSTRAINT pk_users" }
        }
    },
    {
        id = 8918,
        type = "formatter",
        name = "create_table_constraint_newline true - FOREIGN KEY constraint",
        input = "CREATE TABLE orders (id INT, user_id INT, CONSTRAINT fk_user FOREIGN KEY (user_id) REFERENCES users(id))",
        opts = { create_table_constraint_newline = true },
        expected = {
            matches = { ",\n%s+CONSTRAINT fk_user FOREIGN KEY" }
        }
    },
    {
        id = 8919,
        type = "formatter",
        name = "create_table_constraint_newline true - UNIQUE constraint",
        input = "CREATE TABLE users (id INT, email VARCHAR(255), CONSTRAINT uq_email UNIQUE (email))",
        opts = { create_table_constraint_newline = true },
        expected = {
            matches = { ",\n%s+CONSTRAINT uq_email UNIQUE" }
        }
    },
    {
        id = 8920,
        type = "formatter",
        name = "create_table_constraint_newline true - CHECK constraint",
        input = "CREATE TABLE products (id INT, price DECIMAL(10,2), CONSTRAINT chk_price CHECK (price > 0))",
        opts = { create_table_constraint_newline = true },
        expected = {
            matches = { ",\n%s+CONSTRAINT chk_price CHECK" }
        }
    },
    {
        id = 8921,
        type = "formatter",
        name = "create_table_constraint_newline true - DEFAULT constraint",
        input = "CREATE TABLE logs (id INT, created_at DATETIME, CONSTRAINT df_created DEFAULT GETDATE() FOR created_at)",
        opts = { create_table_constraint_newline = true },
        expected = {
            matches = { ",\n%s+CONSTRAINT df_created DEFAULT" }
        }
    },

    -- Multiple constraints
    {
        id = 8922,
        type = "formatter",
        name = "create_table_constraint_newline true - multiple constraints",
        input = "CREATE TABLE orders (id INT, user_id INT, status VARCHAR(20), CONSTRAINT pk_orders PRIMARY KEY (id), CONSTRAINT fk_user FOREIGN KEY (user_id) REFERENCES users(id), CONSTRAINT chk_status CHECK (status IN ('pending', 'shipped')))",
        opts = { create_table_constraint_newline = true },
        expected = {
            -- Each constraint on new line
            matches = { ",\n%s+CONSTRAINT pk_orders", ",\n%s+CONSTRAINT fk_user", ",\n%s+CONSTRAINT chk_status" }
        }
    },

    -- Inline constraint keywords (without CONSTRAINT name)
    {
        id = 8923,
        type = "formatter",
        name = "create_table_constraint_newline true - inline PRIMARY KEY",
        input = "CREATE TABLE users (id INT PRIMARY KEY, name VARCHAR(100))",
        opts = { create_table_constraint_newline = true },
        expected = {
            -- Inline PRIMARY KEY (column-level) should stay with column, not newline
            contains = { "id INT PRIMARY KEY," }
        }
    },
    {
        id = 8924,
        type = "formatter",
        name = "create_table_constraint_newline true - table-level PRIMARY KEY without name",
        input = "CREATE TABLE users (id INT, name VARCHAR(100), PRIMARY KEY (id))",
        opts = { create_table_constraint_newline = true },
        expected = {
            -- Table-level PRIMARY KEY without CONSTRAINT keyword still gets newline
            matches = { ",\n%s+PRIMARY KEY %(" }
        }
    },
    {
        id = 8925,
        type = "formatter",
        name = "create_table_constraint_newline true - table-level FOREIGN KEY without name",
        input = "CREATE TABLE orders (id INT, user_id INT, FOREIGN KEY (user_id) REFERENCES users(id))",
        opts = { create_table_constraint_newline = true },
        expected = {
            matches = { ",\n%s+FOREIGN KEY %(" }
        }
    },
    {
        id = 8926,
        type = "formatter",
        name = "create_table_constraint_newline true - table-level UNIQUE without name",
        input = "CREATE TABLE users (id INT, email VARCHAR(255), UNIQUE (email))",
        opts = { create_table_constraint_newline = true },
        expected = {
            matches = { ",\n%s+UNIQUE %(" }
        }
    },
    {
        id = 8927,
        type = "formatter",
        name = "create_table_constraint_newline true - table-level CHECK without name",
        input = "CREATE TABLE products (id INT, price DECIMAL(10,2), CHECK (price > 0))",
        opts = { create_table_constraint_newline = true },
        expected = {
            matches = { ",\n%s+CHECK %(" }
        }
    },

    -- Combined with create_table_column_newline
    {
        id = 8928,
        type = "formatter",
        name = "create_table_constraint_newline with column_newline - both enabled",
        input = "CREATE TABLE users (id INT, name VARCHAR(100), email VARCHAR(255), CONSTRAINT pk_users PRIMARY KEY (id))",
        opts = { create_table_column_newline = true, create_table_constraint_newline = true },
        expected = {
            -- Each column on new line, constraint also on new line
            matches = { "id INT,\n%s+name", "name VARCHAR%(100%),\n%s+email", ",\n%s+CONSTRAINT pk_users" }
        }
    },
    {
        id = 8929,
        type = "formatter",
        name = "create_table_constraint_newline true with column_newline false",
        input = "CREATE TABLE users (id INT, name VARCHAR(100), CONSTRAINT pk_users PRIMARY KEY (id))",
        opts = { create_table_column_newline = false, create_table_constraint_newline = true },
        expected = {
            -- Columns inline, but CONSTRAINT on new line
            contains = { "id INT, name VARCHAR(100)" },
            matches = { ",\n%s+CONSTRAINT pk_users" }
        }
    },
    {
        id = 8930,
        type = "formatter",
        name = "create_table_constraint_newline false with column_newline true",
        input = "CREATE TABLE users (id INT, name VARCHAR(100), CONSTRAINT pk_users PRIMARY KEY (id))",
        opts = { create_table_column_newline = true, create_table_constraint_newline = false },
        expected = {
            -- Columns on new lines, CONSTRAINT treated as regular item
            matches = { "id INT,\n%s+name VARCHAR", "name VARCHAR%(100%),\n%s+CONSTRAINT" }
        }
    },

    -- Edge cases
    {
        id = 8931,
        type = "formatter",
        name = "create_table_constraint_newline - constraint is first item (unusual)",
        input = "CREATE TABLE constraint_first (CONSTRAINT pk PRIMARY KEY (id), id INT)",
        opts = { create_table_constraint_newline = true },
        expected = {
            -- First item doesn't get preceding newline, but comma after gets newline for next
            contains = { "CONSTRAINT pk PRIMARY KEY (id)" }
        }
    },
    {
        id = 8932,
        type = "formatter",
        name = "create_table_constraint_newline - mixed inline and table constraints",
        input = "CREATE TABLE products (id INT IDENTITY(1,1) PRIMARY KEY, name VARCHAR(100) NOT NULL UNIQUE, price DECIMAL(10,2) CHECK (price >= 0), CONSTRAINT chk_name CHECK (LEN(name) > 0))",
        opts = { create_table_constraint_newline = true },
        expected = {
            -- Inline constraints stay with column, table-level CONSTRAINT gets newline
            -- Note: IDENTITY(1,1) may be formatted as IDENTITY (1, 1) with spacing
            matches = { "INT IDENTITY ?%(1,? ?1%) PRIMARY KEY,", "NOT NULL UNIQUE,", ",\n%s+CONSTRAINT chk_name" }
        }
    },

    -- INDEX as part of CREATE TABLE (SQL Server specific)
    {
        id = 8933,
        type = "formatter",
        name = "create_table_constraint_newline true - INDEX in CREATE TABLE",
        input = "CREATE TABLE users (id INT, name VARCHAR(100), INDEX ix_name (name))",
        opts = { create_table_constraint_newline = true },
        expected = {
            -- INDEX is treated like a table-level constraint
            matches = { ",\n%s+INDEX ix_name" }
        }
    },

    -- Composite constraints
    {
        id = 8934,
        type = "formatter",
        name = "create_table_constraint_newline true - composite PRIMARY KEY",
        input = "CREATE TABLE order_items (order_id INT, product_id INT, quantity INT, CONSTRAINT pk_order_items PRIMARY KEY (order_id, product_id))",
        opts = { create_table_constraint_newline = true },
        expected = {
            matches = { ",\n%s+CONSTRAINT pk_order_items PRIMARY KEY %(order_id, product_id%)" }
        }
    },
    {
        id = 8935,
        type = "formatter",
        name = "create_table_constraint_newline true - composite UNIQUE",
        input = "CREATE TABLE user_roles (user_id INT, role_id INT, CONSTRAINT uq_user_role UNIQUE (user_id, role_id))",
        opts = { create_table_constraint_newline = true },
        expected = {
            matches = { ",\n%s+CONSTRAINT uq_user_role UNIQUE %(user_id, role_id%)" }
        }
    },

    -- ==========================================================================
    -- index_column_style tests (IDs: 8936-8949)
    -- ==========================================================================

    -- CREATE INDEX basic tests
    {
        id = 8936,
        type = "formatter",
        name = "index_column_style inline (default) - single column",
        input = "CREATE INDEX ix_users_name ON users (name)",
        opts = { index_column_style = "inline" },
        expected = {
            -- ON gets newline as major clause, column list stays inline
            contains = { "CREATE INDEX ix_users_name", "ON users(name)" }
        }
    },
    {
        id = 8937,
        type = "formatter",
        name = "index_column_style inline - multiple columns",
        input = "CREATE INDEX ix_users_name_email ON users (name, email, created_at)",
        opts = { index_column_style = "inline" },
        expected = {
            contains = { "(name, email, created_at)" }
        }
    },
    {
        id = 8938,
        type = "formatter",
        name = "index_column_style stacked - multiple columns",
        input = "CREATE INDEX ix_users_name_email ON users (name, email, created_at)",
        opts = { index_column_style = "stacked" },
        expected = {
            -- Each column on new line after first
            matches = { "%(name,\n%s+email,\n%s+created_at%)" }
        }
    },
    {
        id = 8939,
        type = "formatter",
        name = "index_column_style stacked_indent - multiple columns",
        input = "CREATE INDEX ix_users_name_email ON users (name, email, created_at)",
        opts = { index_column_style = "stacked_indent" },
        expected = {
            -- First column on new line after paren
            matches = { "%(\n%s+name,\n%s+email,\n%s+created_at\n?%s*%)" }
        }
    },

    -- CREATE UNIQUE INDEX
    {
        id = 8940,
        type = "formatter",
        name = "index_column_style stacked - UNIQUE INDEX",
        input = "CREATE UNIQUE INDEX uix_users_email ON users (email, tenant_id)",
        opts = { index_column_style = "stacked" },
        expected = {
            matches = { "%(email,\n%s+tenant_id%)" }
        }
    },

    -- CREATE NONCLUSTERED INDEX (SQL Server)
    {
        id = 8941,
        type = "formatter",
        name = "index_column_style stacked - NONCLUSTERED INDEX",
        input = "CREATE NONCLUSTERED INDEX ix_orders_date ON orders (order_date, customer_id)",
        opts = { index_column_style = "stacked" },
        expected = {
            matches = { "%(order_date,\n%s+customer_id%)" }
        }
    },

    -- CREATE CLUSTERED INDEX
    {
        id = 8942,
        type = "formatter",
        name = "index_column_style stacked - CLUSTERED INDEX",
        input = "CREATE CLUSTERED INDEX cix_orders ON orders (id)",
        opts = { index_column_style = "stacked" },
        expected = {
            -- Single column stays inline even with stacked style
            contains = { "(id)" }
        }
    },

    -- Index with INCLUDE clause
    {
        id = 8943,
        type = "formatter",
        name = "index_column_style stacked - with INCLUDE clause",
        input = "CREATE INDEX ix_users ON users (name, email) INCLUDE (created_at, updated_at)",
        opts = { index_column_style = "stacked" },
        expected = {
            -- Both key columns and include columns should be stacked
            matches = { "%(name,\n%s+email%)", "INCLUDE %(created_at,\n%s+updated_at%)" }
        }
    },

    -- Index with ASC/DESC
    {
        id = 8944,
        type = "formatter",
        name = "index_column_style stacked - with ASC/DESC",
        input = "CREATE INDEX ix_orders ON orders (order_date DESC, customer_id ASC)",
        opts = { index_column_style = "stacked" },
        expected = {
            matches = { "%(order_date DESC,\n%s+customer_id ASC%)" }
        }
    },

    -- Index with WHERE clause (filtered index)
    {
        id = 8945,
        type = "formatter",
        name = "index_column_style stacked - filtered index with WHERE",
        input = "CREATE INDEX ix_active_users ON users (name, email) WHERE active = 1",
        opts = { index_column_style = "stacked" },
        expected = {
            matches = { "%(name,\n%s+email%)" },
            contains = { "WHERE active = 1" }
        }
    },

    -- DROP INDEX (no columns - just verify it doesn't break)
    {
        id = 8946,
        type = "formatter",
        name = "DROP INDEX basic formatting",
        input = "DROP INDEX ix_users_name ON users",
        opts = { index_column_style = "stacked" },
        expected = {
            -- ON gets newline as major clause
            contains = { "DROP INDEX ix_users_name", "ON users" }
        }
    },

    -- ALTER INDEX (no columns in basic form)
    {
        id = 8947,
        type = "formatter",
        name = "ALTER INDEX REBUILD",
        input = "ALTER INDEX ix_users_name ON users REBUILD",
        opts = { index_column_style = "stacked" },
        expected = {
            -- ON gets newline as major clause
            contains = { "ALTER INDEX ix_users_name", "ON users REBUILD" }
        }
    },

    -- Inline index in CREATE TABLE
    {
        id = 8948,
        type = "formatter",
        name = "index_column_style stacked - INDEX in CREATE TABLE",
        input = "CREATE TABLE users (id INT, name VARCHAR(100), INDEX ix_name (name, id))",
        opts = { index_column_style = "stacked", create_table_constraint_newline = true },
        expected = {
            -- INDEX columns should be stacked (no space before paren)
            matches = { "INDEX ix_name%(name,\n%s+id%)" }
        }
    },

    -- Multiple indexes - ensure each gets the style
    {
        id = 8949,
        type = "formatter",
        name = "index_column_style stacked - multiple CREATE INDEX statements",
        input = "CREATE INDEX ix1 ON t1 (a, b); CREATE INDEX ix2 ON t2 (c, d)",
        opts = { index_column_style = "stacked" },
        expected = {
            -- ON is on new line, columns are stacked
            matches = { "ON t1%(a,\n%s+b%)", "ON t2%(c,\n%s+d%)" }
        }
    },

    -- ==========================================================================
    -- procedure_param_style tests (IDs: 8990-9009)
    -- ==========================================================================

    -- CREATE PROCEDURE basic tests
    {
        id = 8990,
        type = "formatter",
        name = "procedure_param_style stacked (default) - multiple params",
        input = "CREATE PROCEDURE usp_GetUser @UserId INT, @IncludeDeleted BIT = 0, @MaxResults INT = 100 AS SELECT * FROM Users WHERE Id = @UserId",
        opts = { procedure_param_style = "stacked" },
        expected = {
            -- Parameters stacked on new lines
            matches = { "@UserId INT,\n%s+@IncludeDeleted BIT = 0,\n%s+@MaxResults INT = 100" }
        }
    },
    {
        id = 8991,
        type = "formatter",
        name = "procedure_param_style inline - multiple params",
        input = "CREATE PROCEDURE usp_GetUser @UserId INT, @IncludeDeleted BIT = 0 AS SELECT * FROM Users",
        opts = { procedure_param_style = "inline" },
        expected = {
            -- Parameters stay on same line
            contains = { "@UserId INT, @IncludeDeleted BIT = 0" }
        }
    },
    {
        id = 8992,
        type = "formatter",
        name = "procedure_param_style stacked_indent - first param on new line (with parens)",
        input = "CREATE PROCEDURE usp_GetUser (@UserId INT, @Name VARCHAR(100)) AS SELECT * FROM Users",
        opts = { procedure_param_style = "stacked_indent" },
        expected = {
            -- First param on new line after opening paren
            matches = { "usp_GetUser%(\n%s+@UserId INT,\n%s+@Name VARCHAR%(100%)%)" }
        }
    },

    -- CREATE OR ALTER PROCEDURE
    {
        id = 8993,
        type = "formatter",
        name = "procedure_param_style stacked - CREATE OR ALTER PROCEDURE",
        input = "CREATE OR ALTER PROCEDURE usp_UpdateUser @UserId INT, @Name VARCHAR(100), @Email VARCHAR(255) AS UPDATE Users SET Name = @Name, Email = @Email WHERE Id = @UserId",
        opts = { procedure_param_style = "stacked" },
        expected = {
            matches = { "@UserId INT,\n%s+@Name VARCHAR%(100%),\n%s+@Email VARCHAR%(255%)" }
        }
    },

    -- ALTER PROCEDURE
    {
        id = 8994,
        type = "formatter",
        name = "procedure_param_style stacked - ALTER PROCEDURE",
        input = "ALTER PROCEDURE usp_GetUser @UserId INT, @IncludeHistory BIT AS SELECT * FROM Users",
        opts = { procedure_param_style = "stacked" },
        expected = {
            matches = { "@UserId INT,\n%s+@IncludeHistory BIT" }
        }
    },

    -- Procedure with OUTPUT parameters
    {
        id = 8995,
        type = "formatter",
        name = "procedure_param_style stacked - OUTPUT parameters",
        input = "CREATE PROCEDURE usp_GetCount @TableName VARCHAR(100), @Count INT OUTPUT AS SELECT @Count = COUNT(*) FROM sys.tables WHERE name = @TableName",
        opts = { procedure_param_style = "stacked" },
        expected = {
            matches = { "@TableName VARCHAR%(100%),\n%s+@Count INT OUTPUT" }
        }
    },

    -- Procedure with no parameters
    {
        id = 8996,
        type = "formatter",
        name = "procedure_param_style stacked - no parameters",
        input = "CREATE PROCEDURE usp_GetAllUsers AS SELECT * FROM Users",
        opts = { procedure_param_style = "stacked" },
        expected = {
            contains = { "CREATE PROCEDURE usp_GetAllUsers", "AS" }
        }
    },

    -- Procedure with single parameter (should not add newlines)
    {
        id = 8997,
        type = "formatter",
        name = "procedure_param_style stacked - single parameter stays inline",
        input = "CREATE PROCEDURE usp_GetUser @UserId INT AS SELECT * FROM Users WHERE Id = @UserId",
        opts = { procedure_param_style = "stacked" },
        expected = {
            contains = { "usp_GetUser @UserId INT" }
        }
    },

    -- Procedure with parentheses around parameters
    {
        id = 8998,
        type = "formatter",
        name = "procedure_param_style stacked - with parentheses",
        input = "CREATE PROCEDURE usp_GetUser (@UserId INT, @Name VARCHAR(100)) AS SELECT * FROM Users",
        opts = { procedure_param_style = "stacked" },
        expected = {
            matches = { "%(@UserId INT,\n%s+@Name VARCHAR%(100%)%)" }
        }
    },

    -- ==========================================================================
    -- function_param_style tests (IDs: 9000-9009)
    -- ==========================================================================

    -- CREATE FUNCTION basic tests
    {
        id = 9000,
        type = "formatter",
        name = "function_param_style stacked (default) - scalar function",
        input = "CREATE FUNCTION fn_GetFullName (@FirstName VARCHAR(50), @LastName VARCHAR(50)) RETURNS VARCHAR(100) AS BEGIN RETURN @FirstName + ' ' + @LastName END",
        opts = { function_param_style = "stacked" },
        expected = {
            matches = { "%(@FirstName VARCHAR%(50%),\n%s+@LastName VARCHAR%(50%)%)" }
        }
    },
    {
        id = 9001,
        type = "formatter",
        name = "function_param_style inline - scalar function",
        input = "CREATE FUNCTION fn_GetFullName (@FirstName VARCHAR(50), @LastName VARCHAR(50)) RETURNS VARCHAR(100) AS BEGIN RETURN @FirstName + ' ' + @LastName END",
        opts = { function_param_style = "inline" },
        expected = {
            contains = { "(@FirstName VARCHAR(50), @LastName VARCHAR(50))" }
        }
    },
    {
        id = 9002,
        type = "formatter",
        name = "function_param_style stacked_indent - first param on new line",
        input = "CREATE FUNCTION fn_Add (@A INT, @B INT) RETURNS INT AS BEGIN RETURN @A + @B END",
        opts = { function_param_style = "stacked_indent" },
        expected = {
            matches = { "fn_Add%(\n%s+@A INT,\n%s+@B INT%)" }
        }
    },

    -- Table-valued function
    {
        id = 9003,
        type = "formatter",
        name = "function_param_style stacked - table-valued function",
        input = "CREATE FUNCTION fn_GetUsersByDept (@DeptId INT, @ActiveOnly BIT) RETURNS TABLE AS RETURN SELECT * FROM Users WHERE DeptId = @DeptId AND (@ActiveOnly = 0 OR Active = 1)",
        opts = { function_param_style = "stacked" },
        expected = {
            matches = { "%(@DeptId INT,\n%s+@ActiveOnly BIT%)" }
        }
    },

    -- ALTER FUNCTION
    {
        id = 9004,
        type = "formatter",
        name = "function_param_style stacked - ALTER FUNCTION",
        input = "ALTER FUNCTION fn_Calculate (@Value DECIMAL(18,2), @Rate DECIMAL(5,2)) RETURNS DECIMAL(18,2) AS BEGIN RETURN @Value * @Rate END",
        opts = { function_param_style = "stacked" },
        expected = {
            matches = { "%(@Value DECIMAL%(18, ?2%),\n%s+@Rate DECIMAL%(5, ?2%)%)" }
        }
    },

    -- Function with no parameters
    {
        id = 9005,
        type = "formatter",
        name = "function_param_style stacked - no parameters",
        input = "CREATE FUNCTION fn_GetCurrentDate () RETURNS DATE AS BEGIN RETURN GETDATE() END",
        opts = { function_param_style = "stacked" },
        expected = {
            contains = { "fn_GetCurrentDate()" }
        }
    },

    -- Function with single parameter
    {
        id = 9006,
        type = "formatter",
        name = "function_param_style stacked - single parameter stays inline",
        input = "CREATE FUNCTION fn_Double (@Value INT) RETURNS INT AS BEGIN RETURN @Value * 2 END",
        opts = { function_param_style = "stacked" },
        expected = {
            contains = { "(@Value INT)" }
        }
    },

    -- CREATE OR ALTER FUNCTION
    {
        id = 9007,
        type = "formatter",
        name = "function_param_style stacked - CREATE OR ALTER FUNCTION",
        input = "CREATE OR ALTER FUNCTION fn_Multiply (@A INT, @B INT, @C INT) RETURNS INT AS BEGIN RETURN @A * @B * @C END",
        opts = { function_param_style = "stacked" },
        expected = {
            matches = { "%(@A INT,\n%s+@B INT,\n%s+@C INT%)" }
        }
    },

    -- Multiple functions in same batch
    {
        id = 9008,
        type = "formatter",
        name = "function_param_style stacked - multiple functions",
        input = "CREATE FUNCTION fn_A (@X INT, @Y INT) RETURNS INT AS BEGIN RETURN @X END; CREATE FUNCTION fn_B (@P INT, @Q INT) RETURNS INT AS BEGIN RETURN @P END",
        opts = { function_param_style = "stacked" },
        expected = {
            matches = { "fn_A%(@X INT,\n%s+@Y INT%)", "fn_B%(@P INT,\n%s+@Q INT%)" }
        }
    },

    -- ==========================================================================
    -- alter_table_style tests (IDs: 9010-9025)
    -- ==========================================================================

    -- ALTER TABLE ADD COLUMN - expanded style (default)
    {
        id = 9010,
        type = "formatter",
        name = "alter_table_style expanded (default) - ADD COLUMN",
        input = "ALTER TABLE users ADD email VARCHAR(255)",
        opts = { alter_table_style = "expanded" },
        expected = {
            -- ADD on new line after table name
            matches = { "ALTER TABLE users\n%s*ADD email VARCHAR%(255%)" }
        }
    },
    {
        id = 9011,
        type = "formatter",
        name = "alter_table_style compact - ADD COLUMN",
        input = "ALTER TABLE users ADD email VARCHAR(255)",
        opts = { alter_table_style = "compact" },
        expected = {
            -- ADD stays inline
            contains = { "ALTER TABLE users ADD email VARCHAR(255)" }
        }
    },

    -- ALTER TABLE DROP COLUMN
    {
        id = 9012,
        type = "formatter",
        name = "alter_table_style expanded - DROP COLUMN",
        input = "ALTER TABLE users DROP COLUMN old_field",
        opts = { alter_table_style = "expanded" },
        expected = {
            matches = { "ALTER TABLE users\n%s*DROP COLUMN old_field" }
        }
    },
    {
        id = 9013,
        type = "formatter",
        name = "alter_table_style compact - DROP COLUMN",
        input = "ALTER TABLE users DROP COLUMN old_field",
        opts = { alter_table_style = "compact" },
        expected = {
            contains = { "ALTER TABLE users DROP COLUMN old_field" }
        }
    },

    -- ALTER TABLE ALTER COLUMN
    {
        id = 9014,
        type = "formatter",
        name = "alter_table_style expanded - ALTER COLUMN",
        input = "ALTER TABLE users ALTER COLUMN name VARCHAR(200)",
        opts = { alter_table_style = "expanded" },
        expected = {
            matches = { "ALTER TABLE users\n%s*ALTER COLUMN name VARCHAR%(200%)" }
        }
    },
    {
        id = 9015,
        type = "formatter",
        name = "alter_table_style compact - ALTER COLUMN",
        input = "ALTER TABLE users ALTER COLUMN name VARCHAR(200)",
        opts = { alter_table_style = "compact" },
        expected = {
            contains = { "ALTER TABLE users ALTER COLUMN name VARCHAR(200)" }
        }
    },

    -- ALTER TABLE ADD CONSTRAINT
    {
        id = 9016,
        type = "formatter",
        name = "alter_table_style expanded - ADD CONSTRAINT",
        input = "ALTER TABLE users ADD CONSTRAINT pk_users PRIMARY KEY (id)",
        opts = { alter_table_style = "expanded" },
        expected = {
            matches = { "ALTER TABLE users\n%s*ADD CONSTRAINT pk_users PRIMARY KEY" }
        }
    },
    {
        id = 9017,
        type = "formatter",
        name = "alter_table_style compact - ADD CONSTRAINT",
        input = "ALTER TABLE users ADD CONSTRAINT pk_users PRIMARY KEY (id)",
        opts = { alter_table_style = "compact" },
        expected = {
            contains = { "ALTER TABLE users ADD CONSTRAINT pk_users PRIMARY KEY (id)" }
        }
    },

    -- ALTER TABLE DROP CONSTRAINT
    {
        id = 9018,
        type = "formatter",
        name = "alter_table_style expanded - DROP CONSTRAINT",
        input = "ALTER TABLE users DROP CONSTRAINT pk_users",
        opts = { alter_table_style = "expanded" },
        expected = {
            matches = { "ALTER TABLE users\n%s*DROP CONSTRAINT pk_users" }
        }
    },
    {
        id = 9019,
        type = "formatter",
        name = "alter_table_style compact - DROP CONSTRAINT",
        input = "ALTER TABLE users DROP CONSTRAINT pk_users",
        opts = { alter_table_style = "compact" },
        expected = {
            contains = { "ALTER TABLE users DROP CONSTRAINT pk_users" }
        }
    },

    -- ALTER TABLE multiple operations (expanded style)
    {
        id = 9020,
        type = "formatter",
        name = "alter_table_style expanded - multiple ADD",
        input = "ALTER TABLE users ADD col1 INT, ADD col2 VARCHAR(100)",
        opts = { alter_table_style = "expanded" },
        expected = {
            -- Each ADD on new line
            matches = { "ALTER TABLE users\n%s*ADD col1 INT,\n%s*ADD col2 VARCHAR%(100%)" }
        }
    },
    {
        id = 9021,
        type = "formatter",
        name = "alter_table_style compact - multiple ADD",
        input = "ALTER TABLE users ADD col1 INT, ADD col2 VARCHAR(100)",
        opts = { alter_table_style = "compact" },
        expected = {
            contains = { "ALTER TABLE users ADD col1 INT, ADD col2 VARCHAR(100)" }
        }
    },

    -- ALTER TABLE with schema qualification
    {
        id = 9022,
        type = "formatter",
        name = "alter_table_style expanded - schema qualified table",
        input = "ALTER TABLE dbo.users ADD email VARCHAR(255)",
        opts = { alter_table_style = "expanded" },
        expected = {
            matches = { "ALTER TABLE dbo.users\n%s*ADD email VARCHAR%(255%)" }
        }
    },

    -- ALTER TABLE NOCHECK/CHECK CONSTRAINT
    {
        id = 9023,
        type = "formatter",
        name = "alter_table_style expanded - NOCHECK CONSTRAINT",
        input = "ALTER TABLE users NOCHECK CONSTRAINT fk_department",
        opts = { alter_table_style = "expanded" },
        expected = {
            matches = { "ALTER TABLE users\n%s*NOCHECK CONSTRAINT fk_department" }
        }
    },
    {
        id = 9024,
        type = "formatter",
        name = "alter_table_style compact - CHECK CONSTRAINT",
        input = "ALTER TABLE users CHECK CONSTRAINT fk_department",
        opts = { alter_table_style = "compact" },
        expected = {
            contains = { "ALTER TABLE users CHECK CONSTRAINT fk_department" }
        }
    },

    -- ALTER TABLE with IF EXISTS (SQL Server 2016+)
    {
        id = 9025,
        type = "formatter",
        name = "alter_table_style expanded - DROP IF EXISTS",
        input = "ALTER TABLE users DROP COLUMN IF EXISTS old_field",
        opts = { alter_table_style = "expanded" },
        expected = {
            matches = { "ALTER TABLE users\n%s*DROP COLUMN IF EXISTS old_field" }
        }
    },

    -- ==========================================================================
    -- drop_if_exists_style tests (IDs: 9030-9045)
    -- ==========================================================================

    -- DROP TABLE IF EXISTS - inline style (default)
    {
        id = 9030,
        type = "formatter",
        name = "drop_if_exists_style inline (default) - DROP TABLE",
        input = "DROP TABLE IF EXISTS users",
        opts = { drop_if_exists_style = "inline" },
        expected = {
            contains = { "DROP TABLE IF EXISTS users" }
        }
    },
    {
        id = 9031,
        type = "formatter",
        name = "drop_if_exists_style separate - DROP TABLE",
        input = "DROP TABLE IF EXISTS users",
        opts = { drop_if_exists_style = "separate" },
        expected = {
            -- IF EXISTS on new line
            matches = { "DROP TABLE\n%s*IF EXISTS users" }
        }
    },

    -- DROP PROCEDURE IF EXISTS
    {
        id = 9032,
        type = "formatter",
        name = "drop_if_exists_style inline - DROP PROCEDURE",
        input = "DROP PROCEDURE IF EXISTS usp_GetUser",
        opts = { drop_if_exists_style = "inline" },
        expected = {
            contains = { "DROP PROCEDURE IF EXISTS usp_GetUser" }
        }
    },
    {
        id = 9033,
        type = "formatter",
        name = "drop_if_exists_style separate - DROP PROCEDURE",
        input = "DROP PROCEDURE IF EXISTS usp_GetUser",
        opts = { drop_if_exists_style = "separate" },
        expected = {
            matches = { "DROP PROCEDURE\n%s*IF EXISTS usp_GetUser" }
        }
    },

    -- DROP FUNCTION IF EXISTS
    {
        id = 9034,
        type = "formatter",
        name = "drop_if_exists_style inline - DROP FUNCTION",
        input = "DROP FUNCTION IF EXISTS fn_GetValue",
        opts = { drop_if_exists_style = "inline" },
        expected = {
            contains = { "DROP FUNCTION IF EXISTS fn_GetValue" }
        }
    },
    {
        id = 9035,
        type = "formatter",
        name = "drop_if_exists_style separate - DROP FUNCTION",
        input = "DROP FUNCTION IF EXISTS fn_GetValue",
        opts = { drop_if_exists_style = "separate" },
        expected = {
            matches = { "DROP FUNCTION\n%s*IF EXISTS fn_GetValue" }
        }
    },

    -- DROP VIEW IF EXISTS
    {
        id = 9036,
        type = "formatter",
        name = "drop_if_exists_style inline - DROP VIEW",
        input = "DROP VIEW IF EXISTS vw_Users",
        opts = { drop_if_exists_style = "inline" },
        expected = {
            contains = { "DROP VIEW IF EXISTS vw_Users" }
        }
    },
    {
        id = 9037,
        type = "formatter",
        name = "drop_if_exists_style separate - DROP VIEW",
        input = "DROP VIEW IF EXISTS vw_Users",
        opts = { drop_if_exists_style = "separate" },
        expected = {
            matches = { "DROP VIEW\n%s*IF EXISTS vw_Users" }
        }
    },

    -- DROP INDEX IF EXISTS
    {
        id = 9038,
        type = "formatter",
        name = "drop_if_exists_style inline - DROP INDEX",
        input = "DROP INDEX IF EXISTS ix_users_name ON users",
        opts = { drop_if_exists_style = "inline" },
        expected = {
            contains = { "DROP INDEX IF EXISTS ix_users_name" }
        }
    },
    {
        id = 9039,
        type = "formatter",
        name = "drop_if_exists_style separate - DROP INDEX",
        input = "DROP INDEX IF EXISTS ix_users_name ON users",
        opts = { drop_if_exists_style = "separate" },
        expected = {
            matches = { "DROP INDEX\n%s*IF EXISTS ix_users_name" }
        }
    },

    -- DROP TRIGGER IF EXISTS
    {
        id = 9040,
        type = "formatter",
        name = "drop_if_exists_style inline - DROP TRIGGER",
        input = "DROP TRIGGER IF EXISTS tr_users_insert",
        opts = { drop_if_exists_style = "inline" },
        expected = {
            contains = { "DROP TRIGGER IF EXISTS tr_users_insert" }
        }
    },
    {
        id = 9041,
        type = "formatter",
        name = "drop_if_exists_style separate - DROP TRIGGER",
        input = "DROP TRIGGER IF EXISTS tr_users_insert",
        opts = { drop_if_exists_style = "separate" },
        expected = {
            matches = { "DROP TRIGGER\n%s*IF EXISTS tr_users_insert" }
        }
    },

    -- DROP with schema qualification
    {
        id = 9042,
        type = "formatter",
        name = "drop_if_exists_style separate - schema qualified",
        input = "DROP TABLE IF EXISTS dbo.users",
        opts = { drop_if_exists_style = "separate" },
        expected = {
            matches = { "DROP TABLE\n%s*IF EXISTS dbo.users" }
        }
    },

    -- Multiple DROP statements
    {
        id = 9043,
        type = "formatter",
        name = "drop_if_exists_style separate - multiple statements",
        input = "DROP TABLE IF EXISTS t1; DROP TABLE IF EXISTS t2",
        opts = { drop_if_exists_style = "separate" },
        expected = {
            matches = { "DROP TABLE\n%s*IF EXISTS t1;", "DROP TABLE\n%s*IF EXISTS t2" }
        }
    },

    -- DROP DATABASE IF EXISTS
    {
        id = 9044,
        type = "formatter",
        name = "drop_if_exists_style separate - DROP DATABASE",
        input = "DROP DATABASE IF EXISTS testdb",
        opts = { drop_if_exists_style = "separate" },
        expected = {
            matches = { "DROP DATABASE\n%s*IF EXISTS testdb" }
        }
    },

    -- DROP SCHEMA IF EXISTS
    {
        id = 9045,
        type = "formatter",
        name = "drop_if_exists_style separate - DROP SCHEMA",
        input = "DROP SCHEMA IF EXISTS staging",
        opts = { drop_if_exists_style = "separate" },
        expected = {
            matches = { "DROP SCHEMA\n%s*IF EXISTS staging" }
        }
    },

    -- ==========================================================================
    -- view_body_indent tests (IDs: 9050-9065)
    -- ==========================================================================

    -- Basic CREATE VIEW - indent level 0
    {
        id = 9050,
        type = "formatter",
        name = "view_body_indent 0 - no indentation",
        input = "CREATE VIEW vw_Users AS SELECT id, name FROM users",
        opts = { view_body_indent = 0 },
        expected = {
            -- SELECT at column 0 (no indent)
            matches = { "AS\nSELECT id," }
        }
    },
    {
        id = 9051,
        type = "formatter",
        name = "view_body_indent 1 (default) - one indent level",
        input = "CREATE VIEW vw_Users AS SELECT id, name FROM users",
        opts = { view_body_indent = 1 },
        expected = {
            -- SELECT indented by 1 level (4 spaces default)
            matches = { "AS\n    SELECT id," }
        }
    },
    {
        id = 9052,
        type = "formatter",
        name = "view_body_indent 2 - two indent levels",
        input = "CREATE VIEW vw_Users AS SELECT id, name FROM users",
        opts = { view_body_indent = 2 },
        expected = {
            -- SELECT indented by 2 levels (8 spaces)
            matches = { "AS\n        SELECT id," }
        }
    },

    -- CREATE OR ALTER VIEW
    {
        id = 9053,
        type = "formatter",
        name = "view_body_indent 1 - CREATE OR ALTER VIEW",
        input = "CREATE OR ALTER VIEW vw_Users AS SELECT id, name FROM users",
        opts = { view_body_indent = 1 },
        expected = {
            matches = { "AS\n    SELECT id," }
        }
    },

    -- ALTER VIEW
    {
        id = 9054,
        type = "formatter",
        name = "view_body_indent 1 - ALTER VIEW",
        input = "ALTER VIEW vw_Users AS SELECT id, name FROM users",
        opts = { view_body_indent = 1 },
        expected = {
            matches = { "AS\n    SELECT id," }
        }
    },

    -- View with column list
    {
        id = 9055,
        type = "formatter",
        name = "view_body_indent 1 - view with column list",
        input = "CREATE VIEW vw_Users (user_id, user_name) AS SELECT id, name FROM users",
        opts = { view_body_indent = 1 },
        expected = {
            matches = { "AS\n    SELECT id," }
        }
    },

    -- View with schema qualification
    {
        id = 9056,
        type = "formatter",
        name = "view_body_indent 1 - schema qualified view",
        input = "CREATE VIEW dbo.vw_Users AS SELECT id, name FROM users",
        opts = { view_body_indent = 1 },
        expected = {
            matches = { "AS\n    SELECT id," }
        }
    },

    -- View with WHERE clause - inner clauses also indented
    {
        id = 9057,
        type = "formatter",
        name = "view_body_indent 1 - view with WHERE",
        input = "CREATE VIEW vw_ActiveUsers AS SELECT id, name FROM users WHERE active = 1",
        opts = { view_body_indent = 1 },
        expected = {
            -- FROM and WHERE should be at view body indent level
            matches = { "AS\n    SELECT id,", "\n    FROM users", "\n    WHERE active = 1" }
        }
    },

    -- View with JOIN
    {
        id = 9058,
        type = "formatter",
        name = "view_body_indent 1 - view with JOIN",
        input = "CREATE VIEW vw_UserOrders AS SELECT u.name, o.order_id FROM users u INNER JOIN orders o ON u.id = o.user_id",
        opts = { view_body_indent = 1 },
        expected = {
            matches = { "AS\n    SELECT u.name,", "\n    FROM users u", "\n    INNER JOIN orders o" }
        }
    },

    -- View with UNION
    {
        id = 9059,
        type = "formatter",
        name = "view_body_indent 1 - view with UNION",
        input = "CREATE VIEW vw_AllPeople AS SELECT id, name FROM users UNION ALL SELECT id, name FROM contacts",
        opts = { view_body_indent = 1 },
        expected = {
            -- UNION should also be indented at view body level
            matches = { "AS\n    SELECT id,", "\n    UNION ALL\n    SELECT id," }
        }
    },

    -- View with WITH SCHEMABINDING
    {
        id = 9060,
        type = "formatter",
        name = "view_body_indent 1 - WITH SCHEMABINDING",
        input = "CREATE VIEW vw_Users WITH SCHEMABINDING AS SELECT id, name FROM dbo.users",
        opts = { view_body_indent = 1 },
        expected = {
            matches = { "AS\n    SELECT id," }
        }
    },

    -- View body indent with different base indent_size
    {
        id = 9061,
        type = "formatter",
        name = "view_body_indent 1 with indent_size 2",
        input = "CREATE VIEW vw_Users AS SELECT id FROM users",
        opts = { view_body_indent = 1, indent_size = 2 },
        expected = {
            -- 1 indent level * 2 spaces = 2 spaces
            matches = { "AS\n  SELECT id" }
        }
    },

    -- Multiple views in batch
    {
        id = 9062,
        type = "formatter",
        name = "view_body_indent 1 - multiple views",
        input = "CREATE VIEW vw_A AS SELECT 1 AS a; CREATE VIEW vw_B AS SELECT 2 AS b",
        opts = { view_body_indent = 1 },
        expected = {
            matches = { "vw_A AS\n    SELECT 1 AS a;", "vw_B AS\n    SELECT 2 AS b" }
        }
    },

    -- Nested subquery in view - subquery gets additional indent
    {
        id = 9063,
        type = "formatter",
        name = "view_body_indent 1 - nested subquery",
        input = "CREATE VIEW vw_UserCounts AS SELECT name, (SELECT COUNT(*) FROM orders WHERE orders.user_id = users.id) AS order_count FROM users",
        opts = { view_body_indent = 1 },
        expected = {
            -- SELECT starts at indent 1
            matches = { "AS\n    SELECT name," }
        }
    },

    -- View with CTE
    {
        id = 9064,
        type = "formatter",
        name = "view_body_indent 1 - view with CTE",
        input = "CREATE VIEW vw_TopUsers AS WITH UserCounts AS (SELECT user_id, COUNT(*) AS cnt FROM orders GROUP BY user_id) SELECT u.name, uc.cnt FROM users u INNER JOIN UserCounts uc ON u.id = uc.user_id",
        opts = { view_body_indent = 1 },
        expected = {
            -- WITH should start at view body indent
            matches = { "AS\n    WITH UserCounts AS" }
        }
    },

    -- View body indent 0 verification - no indentation at all
    {
        id = 9065,
        type = "formatter",
        name = "view_body_indent 0 - verification no indent",
        input = "CREATE VIEW vw_Test AS SELECT a, b FROM t WHERE a > 1",
        opts = { view_body_indent = 0 },
        expected = {
            -- All clauses at column 0
            matches = { "AS\nSELECT a,", "\nFROM t\n", "\nWHERE a > 1" }
        }
    },
}
