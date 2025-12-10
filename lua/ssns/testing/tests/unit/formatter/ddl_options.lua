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
}
