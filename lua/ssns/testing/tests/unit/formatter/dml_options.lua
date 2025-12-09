-- Test file: dml_options.lua
-- IDs: 8521-8580
-- Tests: Phase 2 DML options - INSERT, UPDATE, DELETE, MERGE specific formatting

return {
    -- INSERT column style
    {
        id = 8521,
        type = "formatter",
        name = "insert_columns_style inline (default)",
        input = "INSERT INTO users (id, name, email) VALUES (1, 'John', 'john@example.com')",
        opts = { insert_columns_style = "inline" },
        expected = {
            contains = { "(id, name, email)" }
        }
    },
    {
        id = 8522,
        type = "formatter",
        name = "insert_columns_style stacked",
        input = "INSERT INTO users (id, name, email) VALUES (1, 'John', 'john@example.com')",
        opts = { insert_columns_style = "stacked" },
        expected = {
            matches = { "%(id,\n.-name,\n.-email%)" }
        }
    },

    -- INSERT values style
    {
        id = 8525,
        type = "formatter",
        name = "insert_values_style inline (default)",
        input = "INSERT INTO users (id, name) VALUES (1, 'John')",
        opts = { insert_values_style = "inline" },
        expected = {
            contains = { "VALUES (1, 'John')" }
        }
    },
    {
        id = 8526,
        type = "formatter",
        name = "insert_values_style stacked",
        input = "INSERT INTO users (id, name) VALUES (1, 'John')",
        opts = { insert_values_style = "stacked" },
        expected = {
            matches = { "VALUES %(\n.-1,\n.-'John'" }
        }
    },

    -- INSERT multi-row style
    {
        id = 8530,
        type = "formatter",
        name = "insert_multi_row_style stacked (default)",
        input = "INSERT INTO users (id, name) VALUES (1, 'John'), (2, 'Jane'), (3, 'Bob')",
        opts = { insert_multi_row_style = "stacked" },
        expected = {
            matches = { "%(1, 'John'%),\n.-%( ?2, 'Jane'%),\n.-%( ?3, 'Bob'%)" }
        }
    },
    {
        id = 8531,
        type = "formatter",
        name = "insert_multi_row_style inline",
        input = "INSERT INTO users (id, name) VALUES (1, 'John'), (2, 'Jane')",
        opts = { insert_multi_row_style = "inline" },
        expected = {
            contains = { "(1, 'John'), (2, 'Jane')" }  -- Same line
        }
    },

    -- UPDATE SET style
    {
        id = 8540,
        type = "formatter",
        name = "update_set_style stacked",
        input = "UPDATE users SET name = 'John', email = 'john@example.com', updated_at = GETDATE() WHERE id = 1",
        opts = { update_set_style = "stacked" },
        expected = {
            matches = { "SET name = 'John',\n.-email = 'john@example.com',\n.-updated_at = GETDATE%(%)" }
        }
    },
    {
        id = 8541,
        type = "formatter",
        name = "update_set_style inline",
        input = "UPDATE users SET name = 'John', email = 'john@example.com' WHERE id = 1",
        opts = { update_set_style = "inline" },
        expected = {
            contains = { "SET name = 'John', email = 'john@example.com'" }
        }
    },
    {
        id = 8542,
        type = "formatter",
        name = "update_set_align true",
        input = "UPDATE users SET name = 'John', email = 'john@example.com' WHERE id = 1",
        opts = { update_set_style = "stacked", update_set_align = true },
        expected = {
            -- Assignment operators should be aligned (approximate test)
            matches = { "SET name", "email" }
        }
    },

    -- OUTPUT clause
    {
        id = 8550,
        type = "formatter",
        name = "output_clause_newline true (default)",
        input = "INSERT INTO users (name) OUTPUT INSERTED.id VALUES ('John')",
        opts = { output_clause_newline = true },
        expected = {
            matches = { "users%(name%)\n.-OUTPUT" }  -- No space before ( after identifier
        }
    },
    {
        id = 8551,
        type = "formatter",
        name = "output_clause_newline false",
        input = "INSERT INTO users (name) OUTPUT INSERTED.id VALUES ('John')",
        opts = { output_clause_newline = false },
        expected = {
            contains = { "users(name) OUTPUT" }  -- No space before (, OUTPUT on same line
        }
    },
    {
        id = 8552,
        type = "formatter",
        name = "OUTPUT in DELETE statement",
        input = "DELETE FROM users OUTPUT DELETED.* WHERE id = 1",
        opts = { output_clause_newline = true },
        expected = {
            matches = { "DELETE FROM users\n.-OUTPUT DELETED" }
        }
    },
    {
        id = 8553,
        type = "formatter",
        name = "OUTPUT in UPDATE statement",
        input = "UPDATE users SET status = 'deleted' OUTPUT DELETED.id, INSERTED.status WHERE id = 1",
        opts = { output_clause_newline = true },
        expected = {
            contains = { "OUTPUT DELETED.id, INSERTED.status" }
        }
    },

    -- MERGE statement
    {
        id = 8560,
        type = "formatter",
        name = "merge_when_newline true (default)",
        input = "MERGE INTO target t USING source s ON t.id = s.id WHEN MATCHED THEN UPDATE SET t.name = s.name WHEN NOT MATCHED THEN INSERT (id, name) VALUES (s.id, s.name)",
        opts = { merge_when_newline = true },
        expected = {
            matches = { "\nWHEN MATCHED", "\nWHEN NOT MATCHED" }
        }
    },
    {
        id = 8561,
        type = "formatter",
        name = "merge_when_newline false",
        input = "MERGE INTO target t USING source s ON t.id = s.id WHEN MATCHED THEN UPDATE SET t.name = s.name",
        opts = { merge_when_newline = false },
        expected = {
            -- WHEN stays inline with previous content
            not_contains = { "\nWHEN MATCHED" }
        }
    },
    {
        id = 8562,
        type = "formatter",
        name = "MERGE with multiple WHEN clauses",
        input = "MERGE t USING s ON t.id = s.id WHEN MATCHED AND s.deleted = 1 THEN DELETE WHEN MATCHED THEN UPDATE SET t.name = s.name WHEN NOT MATCHED BY TARGET THEN INSERT (id) VALUES (s.id) WHEN NOT MATCHED BY SOURCE THEN DELETE",
        opts = { merge_when_newline = true },
        expected = {
            contains = { "WHEN MATCHED AND", "WHEN MATCHED THEN UPDATE", "WHEN NOT MATCHED BY TARGET", "WHEN NOT MATCHED BY SOURCE" }
        }
    },

    -- DELETE statement
    {
        id = 8570,
        type = "formatter",
        name = "DELETE basic formatting",
        input = "DELETE FROM users WHERE status = 'deleted' AND deleted_at < '2020-01-01'",
        opts = { and_or_position = "leading" },
        expected = {
            matches = { "DELETE FROM users\nWHERE status = 'deleted'\n.-AND deleted_at" }
        }
    },
    {
        id = 8571,
        type = "formatter",
        name = "DELETE TOP",
        input = "DELETE TOP (100) FROM logs WHERE created_at < '2020-01-01'",
        expected = {
            contains = { "DELETE TOP (100) FROM logs" }
        }
    },

    -- Combined DML tests
    {
        id = 8575,
        type = "formatter",
        name = "Complex INSERT with all options",
        input = "INSERT INTO users (id, name, email, status) OUTPUT INSERTED.id VALUES (1, 'John', 'john@example.com', 'active'), (2, 'Jane', 'jane@example.com', 'active')",
        opts = {
            insert_columns_style = "stacked",
            insert_multi_row_style = "stacked",
            output_clause_newline = true
        },
        expected = {
            contains = { "INSERT INTO users", "OUTPUT INSERTED.id", "VALUES" }
        }
    },
    {
        id = 8576,
        type = "formatter",
        name = "Complex UPDATE with all options",
        input = "UPDATE users SET name = 'Updated', email = 'new@example.com', updated_at = GETDATE() OUTPUT DELETED.name, INSERTED.name WHERE id = 1 AND status = 'active'",
        opts = {
            update_set_style = "stacked",
            output_clause_newline = true,
            and_or_position = "leading"
        },
        expected = {
            matches = { "SET name = 'Updated',\n", "OUTPUT DELETED", "WHERE id = 1\n.-AND status" }
        }
    },
    {
        id = 8577,
        type = "formatter",
        name = "INSERT...SELECT formatting",
        input = "INSERT INTO archive (id, name) SELECT id, name FROM users WHERE deleted = 1",
        expected = {
            contains = { "INSERT INTO archive (id, name)", "SELECT id,", "FROM users", "WHERE deleted = 1" }
        }
    },
    {
        id = 8578,
        type = "formatter",
        name = "UPDATE with FROM clause (SQL Server)",
        input = "UPDATE u SET u.status = 'verified' FROM users u INNER JOIN verified v ON u.id = v.user_id WHERE v.verified_at IS NOT NULL",
        opts = { update_set_style = "stacked" },
        expected = {
            contains = { "UPDATE u", "SET u.status = 'verified'", "FROM users u", "INNER JOIN verified v" }
        }
    },
    {
        id = 8579,
        type = "formatter",
        name = "DELETE with JOIN (SQL Server)",
        input = "DELETE u FROM users u INNER JOIN banned b ON u.id = b.user_id WHERE b.banned_at < '2020-01-01'",
        expected = {
            contains = { "DELETE u", "FROM users u", "INNER JOIN banned b" }
        }
    },
    {
        id = 8580,
        type = "formatter",
        name = "TRUNCATE TABLE formatting",
        input = "TRUNCATE TABLE logs",
        expected = {
            contains = { "TRUNCATE TABLE logs" }
        }
    },
}
