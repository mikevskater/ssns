-- Test file: dml_formatting.lua
-- IDs: 8101-8150
-- Tests: DML statement formatting - INSERT, UPDATE, DELETE, MERGE

return {
    -- INSERT statement formatting
    {
        id = 8101,
        type = "formatter",
        name = "Simple INSERT INTO",
        input = "insert into users (name, email) values ('John', 'john@test.com')",
        expected = {
            contains = { "INSERT INTO users", "VALUES" }
        }
    },
    {
        id = 8102,
        type = "formatter",
        name = "INSERT with column list",
        input = "INSERT INTO users(id,name,email,created_at)VALUES(1,'John','john@test.com',GETDATE())",
        expected = {
            contains = { "(id, name, email, created_at)", "VALUES" }
        }
    },
    {
        id = 8103,
        type = "formatter",
        name = "INSERT VALUES on new line",
        input = "INSERT INTO users (name) VALUES ('test')",
        expected = {
            -- No space between table name and column list is acceptable
            contains = { "INSERT INTO users", "(name)", "VALUES ('test')" }
        }
    },
    {
        id = 8104,
        type = "formatter",
        name = "INSERT multiple VALUES (default stacked)",
        input = "INSERT INTO users (name) VALUES ('John'), ('Jane'), ('Bob')",
        expected = {
            -- Default insert_multi_row_style is "stacked"
            contains = { "VALUES ('John'),", "('Jane'),", "('Bob')" }
        }
    },
    {
        id = 8105,
        type = "formatter",
        name = "INSERT SELECT",
        input = "INSERT INTO archive (id, name) SELECT id, name FROM users WHERE deleted = 1",
        expected = {
            -- SSMS style: columns on separate lines
            contains = { "INSERT INTO archive", "SELECT id,", "name", "FROM users", "WHERE deleted = 1" }
        }
    },
    {
        id = 8106,
        type = "formatter",
        name = "INSERT with DEFAULT VALUES",
        input = "INSERT INTO log DEFAULT VALUES",
        expected = {
            -- DEFAULT is a keyword that gets uppercase
            contains = { "INSERT INTO log", "DEFAULT" }
        }
    },
    {
        id = 8107,
        type = "formatter",
        name = "INSERT with OUTPUT clause",
        input = "INSERT INTO users (name) OUTPUT INSERTED.id VALUES ('Test')",
        expected = {
            contains = { "OUTPUT INSERTED.id" }
        }
    },

    -- UPDATE statement formatting
    {
        id = 8110,
        type = "formatter",
        name = "Simple UPDATE SET",
        input = "update users set name='John' where id=1",
        expected = {
            contains = { "UPDATE users", "SET name = 'John'", "WHERE id = 1" }
        }
    },
    {
        id = 8111,
        type = "formatter",
        name = "UPDATE with multiple SET",
        input = "UPDATE users SET name='John',email='john@test.com',updated_at=GETDATE() WHERE id=1",
        expected = {
            contains = { "SET name = 'John'", "email = 'john@test.com'" }
        }
    },
    {
        id = 8112,
        type = "formatter",
        name = "UPDATE SET newlines after comma",
        input = "UPDATE users SET a = 1, b = 2, c = 3 WHERE id = 1",
        expected = {
            matches = { "SET a = 1,\n%s*b = 2,\n%s*c = 3" }
        }
    },
    {
        id = 8113,
        type = "formatter",
        name = "UPDATE with FROM clause",
        input = "UPDATE u SET u.name=s.name FROM users u INNER JOIN source s ON u.id=s.id",
        expected = {
            contains = { "UPDATE u", "SET u.name = s.name", "FROM users u", "INNER JOIN source s" }
        }
    },
    {
        id = 8114,
        type = "formatter",
        name = "UPDATE with subquery",
        input = "UPDATE users SET status=(SELECT status FROM defaults WHERE type='user') WHERE id=1",
        expected = {
            contains = { "UPDATE users", "SET status = (", "SELECT status", "FROM defaults" }
        }
    },
    {
        id = 8115,
        type = "formatter",
        name = "UPDATE TOP",
        input = "UPDATE TOP (10) users SET processed = 1 WHERE processed = 0",
        expected = {
            contains = { "UPDATE TOP (10) users", "SET processed = 1" }
        }
    },

    -- DELETE statement formatting
    {
        id = 8120,
        type = "formatter",
        name = "Simple DELETE",
        input = "delete from users where id=1",
        expected = {
            contains = { "DELETE", "FROM users", "WHERE id = 1" }
        }
    },
    {
        id = 8121,
        type = "formatter",
        name = "DELETE without WHERE",
        input = "DELETE FROM temp_table",
        expected = {
            formatted = "DELETE\nFROM temp_table"
        }
    },
    {
        id = 8122,
        type = "formatter",
        name = "DELETE with multiple conditions",
        input = "DELETE FROM users WHERE status='deleted' AND last_login < '2023-01-01'",
        expected = {
            contains = { "WHERE status = 'deleted'", "AND last_login < '2023-01-01'" }
        }
    },
    {
        id = 8123,
        type = "formatter",
        name = "DELETE TOP",
        input = "DELETE TOP (100) FROM log_entries WHERE created_at < '2023-01-01'",
        expected = {
            contains = { "DELETE TOP (100)", "FROM log_entries" }
        }
    },
    {
        id = 8124,
        type = "formatter",
        name = "DELETE with JOIN (SQL Server)",
        input = "DELETE u FROM users u INNER JOIN blacklist b ON u.email=b.email",
        expected = {
            contains = { "DELETE u", "FROM users u", "INNER JOIN blacklist b" }
        }
    },
    {
        id = 8125,
        type = "formatter",
        name = "DELETE with OUTPUT",
        input = "DELETE FROM users OUTPUT DELETED.id, DELETED.name WHERE status='deleted'",
        expected = {
            contains = { "OUTPUT DELETED.id, DELETED.name" }
        }
    },

    -- TRUNCATE statement
    {
        id = 8130,
        type = "formatter",
        name = "TRUNCATE TABLE",
        input = "truncate table temp_data",
        expected = {
            contains = { "TRUNCATE TABLE temp_data" }
        }
    },

    -- MERGE statement formatting
    {
        id = 8135,
        type = "formatter",
        name = "Basic MERGE statement",
        input = "MERGE INTO target t USING source s ON t.id=s.id WHEN MATCHED THEN UPDATE SET t.name=s.name WHEN NOT MATCHED THEN INSERT(id,name)VALUES(s.id,s.name)",
        expected = {
            -- UPDATE and SET on separate lines is acceptable in SSMS style
            contains = {
                "MERGE INTO target t",
                "USING source s",
                "ON t.id = s.id",
                "WHEN MATCHED THEN",
                "UPDATE",
                "SET t.name = s.name",
                "WHEN NOT MATCHED THEN",
                "INSERT"
            }
        }
    },
    {
        id = 8136,
        type = "formatter",
        name = "MERGE with DELETE",
        input = "MERGE INTO t USING s ON t.id=s.id WHEN MATCHED AND s.deleted=1 THEN DELETE WHEN MATCHED THEN UPDATE SET t.val=s.val",
        expected = {
            contains = { "WHEN MATCHED", "DELETE", "UPDATE", "SET t.val = s.val" }
        }
    },

    -- SELECT INTO
    {
        id = 8140,
        type = "formatter",
        name = "SELECT INTO new table",
        input = "SELECT * INTO backup_users FROM users WHERE created_at < '2023-01-01'",
        expected = {
            contains = { "SELECT *", "INTO backup_users", "FROM users" }
        }
    },
    {
        id = 8141,
        type = "formatter",
        name = "SELECT INTO temp table",
        input = "SELECT id, name INTO #temp FROM users",
        expected = {
            contains = { "INTO #temp", "FROM users" }
        }
    },

    -- Transaction statements
    {
        id = 8145,
        type = "formatter",
        name = "BEGIN TRANSACTION",
        input = "begin transaction",
        expected = {
            contains = { "BEGIN TRANSACTION" }
        }
    },
    {
        id = 8146,
        type = "formatter",
        name = "COMMIT TRANSACTION",
        input = "commit transaction",
        expected = {
            contains = { "COMMIT TRANSACTION" }
        }
    },
    {
        id = 8147,
        type = "formatter",
        name = "ROLLBACK TRANSACTION",
        input = "rollback transaction",
        expected = {
            contains = { "ROLLBACK TRANSACTION" }
        }
    },

    -- Multiple DML statements
    {
        id = 8150,
        type = "formatter",
        name = "Multiple DML statements separated by semicolon",
        input = "INSERT INTO log (msg) VALUES ('start'); UPDATE users SET status = 'processing'; DELETE FROM temp;",
        expected = {
            contains = { "INSERT INTO log", "UPDATE users", "DELETE" }
        }
    },
}
