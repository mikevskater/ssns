-- Test file: joins.lua
-- IDs: 2201-2250
-- Tests: JOIN parsing with various JOIN types and configurations

return {
    -- Simple JOINs
    {
        id = 2201,
        type = "parser",
        name = "Simple JOIN without type",
        input = "SELECT * FROM Orders JOIN Customers ON Orders.CustomerId = Customers.Id",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Orders" },
                        { name = "Customers" }
                    }
                }
            }
        }
    },
    {
        id = 2202,
        type = "parser",
        name = "Simple JOIN with aliases",
        input = "SELECT * FROM Orders o JOIN Customers c ON o.CustomerId = c.Id",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Orders", alias = "o" },
                        { name = "Customers", alias = "c" }
                    }
                }
            }
        }
    },

    -- INNER JOIN
    {
        id = 2203,
        type = "parser",
        name = "INNER JOIN",
        input = "SELECT * FROM Orders INNER JOIN Customers ON Orders.CustomerId = Customers.Id",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Orders" },
                        { name = "Customers" }
                    }
                }
            }
        }
    },
    {
        id = 2204,
        type = "parser",
        name = "INNER JOIN with aliases",
        input = "SELECT * FROM Orders o INNER JOIN Customers c ON o.CustomerId = c.Id",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Orders", alias = "o" },
                        { name = "Customers", alias = "c" }
                    }
                }
            }
        }
    },

    -- LEFT JOIN
    {
        id = 2205,
        type = "parser",
        name = "LEFT JOIN",
        input = "SELECT * FROM Orders LEFT JOIN Customers ON Orders.CustomerId = Customers.Id",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Orders" },
                        { name = "Customers" }
                    }
                }
            }
        }
    },
    {
        id = 2206,
        type = "parser",
        name = "LEFT OUTER JOIN",
        input = "SELECT * FROM Orders LEFT OUTER JOIN Customers ON Orders.CustomerId = Customers.Id",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Orders" },
                        { name = "Customers" }
                    }
                }
            }
        }
    },
    {
        id = 2207,
        type = "parser",
        name = "LEFT JOIN with aliases",
        input = "SELECT * FROM Orders o LEFT JOIN Customers c ON o.CustomerId = c.Id",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Orders", alias = "o" },
                        { name = "Customers", alias = "c" }
                    }
                }
            }
        }
    },

    -- RIGHT JOIN
    {
        id = 2208,
        type = "parser",
        name = "RIGHT JOIN",
        input = "SELECT * FROM Orders RIGHT JOIN Customers ON Orders.CustomerId = Customers.Id",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Orders" },
                        { name = "Customers" }
                    }
                }
            }
        }
    },
    {
        id = 2209,
        type = "parser",
        name = "RIGHT OUTER JOIN",
        input = "SELECT * FROM Orders RIGHT OUTER JOIN Customers ON Orders.CustomerId = Customers.Id",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Orders" },
                        { name = "Customers" }
                    }
                }
            }
        }
    },

    -- FULL OUTER JOIN
    {
        id = 2210,
        type = "parser",
        name = "FULL OUTER JOIN",
        input = "SELECT * FROM Orders FULL OUTER JOIN Customers ON Orders.CustomerId = Customers.Id",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Orders" },
                        { name = "Customers" }
                    }
                }
            }
        }
    },
    {
        id = 2211,
        type = "parser",
        name = "FULL JOIN",
        input = "SELECT * FROM Orders FULL JOIN Customers ON Orders.CustomerId = Customers.Id",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Orders" },
                        { name = "Customers" }
                    }
                }
            }
        }
    },

    -- CROSS JOIN
    {
        id = 2212,
        type = "parser",
        name = "CROSS JOIN",
        input = "SELECT * FROM Numbers CROSS JOIN Colors",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Numbers" },
                        { name = "Colors" }
                    }
                }
            }
        }
    },

    -- Multiple JOINs (3 tables)
    {
        id = 2213,
        type = "parser",
        name = "Three tables with JOINs",
        input = "SELECT * FROM Orders o JOIN Customers c ON o.CustomerId = c.Id JOIN Products p ON o.ProductId = p.Id",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Orders", alias = "o" },
                        { name = "Customers", alias = "c" },
                        { name = "Products", alias = "p" }
                    }
                }
            }
        }
    },
    {
        id = 2214,
        type = "parser",
        name = "Three tables with mixed JOIN types",
        input = "SELECT * FROM Orders o INNER JOIN Customers c ON o.CustomerId = c.Id LEFT JOIN Products p ON o.ProductId = p.Id",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Orders", alias = "o" },
                        { name = "Customers", alias = "c" },
                        { name = "Products", alias = "p" }
                    }
                }
            }
        }
    },

    -- Four or more tables
    {
        id = 2215,
        type = "parser",
        name = "Four tables with JOINs",
        input = [[SELECT *
FROM Orders o
JOIN Customers c ON o.CustomerId = c.Id
JOIN Products p ON o.ProductId = p.Id
JOIN Categories cat ON p.CategoryId = cat.Id]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Orders", alias = "o" },
                        { name = "Customers", alias = "c" },
                        { name = "Products", alias = "p" },
                        { name = "Categories", alias = "cat" }
                    }
                }
            }
        }
    },
    {
        id = 2216,
        type = "parser",
        name = "Five tables with mixed JOINs",
        input = [[SELECT *
FROM Orders o
INNER JOIN Customers c ON o.CustomerId = c.Id
LEFT JOIN Products p ON o.ProductId = p.Id
LEFT JOIN Categories cat ON p.CategoryId = cat.Id
INNER JOIN Suppliers s ON p.SupplierId = s.Id]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Orders", alias = "o" },
                        { name = "Customers", alias = "c" },
                        { name = "Products", alias = "p" },
                        { name = "Categories", alias = "cat" },
                        { name = "Suppliers", alias = "s" }
                    }
                }
            }
        }
    },

    -- JOINs with schema qualification
    {
        id = 2217,
        type = "parser",
        name = "JOIN with schema qualified tables",
        input = "SELECT * FROM dbo.Orders o JOIN dbo.Customers c ON o.CustomerId = c.Id",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Orders", schema = "dbo", alias = "o" },
                        { name = "Customers", schema = "dbo", alias = "c" }
                    }
                }
            }
        }
    },
    {
        id = 2218,
        type = "parser",
        name = "JOIN with different schemas",
        input = "SELECT * FROM sales.Orders o JOIN crm.Customers c ON o.CustomerId = c.Id",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Orders", schema = "sales", alias = "o" },
                        { name = "Customers", schema = "crm", alias = "c" }
                    }
                }
            }
        }
    },
    {
        id = 2219,
        type = "parser",
        name = "JOIN with database.schema.table",
        input = "SELECT * FROM db1.dbo.Orders o JOIN db2.dbo.Customers c ON o.CustomerId = c.Id",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Orders", schema = "dbo", database = "db1", alias = "o" },
                        { name = "Customers", schema = "dbo", database = "db2", alias = "c" }
                    }
                }
            }
        }
    },

    -- Self-joins
    {
        id = 2220,
        type = "parser",
        name = "Self-join with different aliases",
        input = "SELECT * FROM Employees e1 JOIN Employees e2 ON e1.ManagerId = e2.Id",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Employees", alias = "e1" },
                        { name = "Employees", alias = "e2" }
                    }
                }
            }
        }
    },
    {
        id = 2221,
        type = "parser",
        name = "Self-join with schema",
        input = "SELECT * FROM dbo.Employees e1 JOIN dbo.Employees e2 ON e1.ManagerId = e2.Id",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Employees", schema = "dbo", alias = "e1" },
                        { name = "Employees", schema = "dbo", alias = "e2" }
                    }
                }
            }
        }
    },
    {
        id = 2222,
        type = "parser",
        name = "Triple self-join",
        input = "SELECT * FROM Employees e1 JOIN Employees e2 ON e1.ManagerId = e2.Id JOIN Employees e3 ON e2.ManagerId = e3.Id",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Employees", alias = "e1" },
                        { name = "Employees", alias = "e2" },
                        { name = "Employees", alias = "e3" }
                    }
                }
            }
        }
    },

    -- JOINs with complex ON conditions
    {
        id = 2223,
        type = "parser",
        name = "JOIN with multiple ON conditions",
        input = "SELECT * FROM Orders o JOIN Customers c ON o.CustomerId = c.Id AND o.CompanyId = c.CompanyId",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Orders", alias = "o" },
                        { name = "Customers", alias = "c" }
                    }
                }
            }
        }
    },
    {
        id = 2224,
        type = "parser",
        name = "JOIN with OR in ON condition",
        input = "SELECT * FROM Orders o JOIN Customers c ON o.CustomerId = c.Id OR o.AltCustomerId = c.Id",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Orders", alias = "o" },
                        { name = "Customers", alias = "c" }
                    }
                }
            }
        }
    },

    -- JOINs with WHERE clause
    {
        id = 2225,
        type = "parser",
        name = "JOIN with WHERE clause",
        input = "SELECT * FROM Orders o JOIN Customers c ON o.CustomerId = c.Id WHERE o.Total > 100",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Orders", alias = "o" },
                        { name = "Customers", alias = "c" }
                    }
                }
            }
        }
    },
    {
        id = 2226,
        type = "parser",
        name = "Multiple JOINs with WHERE",
        input = "SELECT * FROM Orders o JOIN Customers c ON o.CustomerId = c.Id JOIN Products p ON o.ProductId = p.Id WHERE o.Total > 100 AND p.Active = 1",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Orders", alias = "o" },
                        { name = "Customers", alias = "c" },
                        { name = "Products", alias = "p" }
                    }
                }
            }
        }
    },

    -- JOINs with bracketed identifiers
    {
        id = 2227,
        type = "parser",
        name = "JOIN with bracketed table names",
        input = "SELECT * FROM [Order Details] od JOIN [Products] p ON od.ProductId = p.Id",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Order Details", alias = "od" },
                        { name = "Products", alias = "p" }
                    }
                }
            }
        }
    },
    {
        id = 2228,
        type = "parser",
        name = "JOIN with bracketed schema and table",
        input = "SELECT * FROM [dbo].[Order Details] od JOIN [dbo].[Products] p ON od.ProductId = p.Id",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Order Details", schema = "dbo", alias = "od" },
                        { name = "Products", schema = "dbo", alias = "p" }
                    }
                }
            }
        }
    },

    -- Multiline JOIN formatting
    {
        id = 2229,
        type = "parser",
        name = "Multiline formatted JOINs",
        input = [[SELECT *
FROM Orders o
    JOIN Customers c
        ON o.CustomerId = c.Id
    JOIN Products p
        ON o.ProductId = p.Id]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Orders", alias = "o" },
                        { name = "Customers", alias = "c" },
                        { name = "Products", alias = "p" }
                    }
                }
            }
        }
    },

    -- JOINs with temp tables
    {
        id = 2230,
        type = "parser",
        name = "JOIN with temp table",
        input = "SELECT * FROM Orders o JOIN #TempCustomers t ON o.CustomerId = t.Id",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Orders", alias = "o" },
                        { name = "#TempCustomers", alias = "t", is_temp = true }
                    }
                }
            }
        }
    },
    {
        id = 2231,
        type = "parser",
        name = "JOIN two temp tables",
        input = "SELECT * FROM #Temp1 t1 JOIN #Temp2 t2 ON t1.Id = t2.Id",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "#Temp1", alias = "t1", is_temp = true },
                        { name = "#Temp2", alias = "t2", is_temp = true }
                    }
                }
            }
        }
    },

    -- JOIN with AS keyword for alias
    {
        id = 2232,
        type = "parser",
        name = "JOIN with AS for aliases",
        input = "SELECT * FROM Orders AS o JOIN Customers AS c ON o.CustomerId = c.Id",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Orders", alias = "o" },
                        { name = "Customers", alias = "c" }
                    }
                }
            }
        }
    },

    -- JOIN with USING clause (PostgreSQL style - may not be supported)
    {
        id = 2233,
        type = "parser",
        name = "JOIN with USING clause",
        input = "SELECT * FROM Orders o JOIN Customers c USING (CustomerId)",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Orders", alias = "o" },
                        { name = "Customers", alias = "c" }
                    }
                }
            }
        }
    },

    -- Chained JOINs of same type
    {
        id = 2234,
        type = "parser",
        name = "All INNER JOINs",
        input = "SELECT * FROM A INNER JOIN B ON A.Id = B.AId INNER JOIN C ON B.Id = C.BId INNER JOIN D ON C.Id = D.CId",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "A" },
                        { name = "B" },
                        { name = "C" },
                        { name = "D" }
                    }
                }
            }
        }
    },
    {
        id = 2235,
        type = "parser",
        name = "All LEFT JOINs",
        input = "SELECT * FROM A LEFT JOIN B ON A.Id = B.AId LEFT JOIN C ON B.Id = C.BId LEFT JOIN D ON C.Id = D.CId",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "A" },
                        { name = "B" },
                        { name = "C" },
                        { name = "D" }
                    }
                }
            }
        }
    },
}
