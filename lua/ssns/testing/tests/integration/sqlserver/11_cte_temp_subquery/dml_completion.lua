-- Integration Tests: DML Statement Completion
-- Test IDs: 4551-4650
-- Tests INSERT, UPDATE, DELETE, MERGE statement completion scenarios

return {
  -- ============================================================================
  -- 4551-4570: INSERT statement completion
  -- ============================================================================
  {
    number = 4551,
    description = "INSERT - table completion after INSERT INTO",
    database = "vim_dadbod_test",
    query = [[INSERT INTO ]],
    cursor = { line = 0, col = 12 },
    expected = {
      type = "table",
      items = {
        includes = {
          "Employees",
          "Departments",
          "Projects",
        },
      },
    },
  },
  {
    number = 4552,
    description = "INSERT - schema-qualified table",
    database = "vim_dadbod_test",
    query = [[INSERT INTO dbo.]],
    cursor = { line = 0, col = 16 },
    expected = {
      type = "table",
      items = {
        includes = {
          "Employees",
          "Departments",
        },
      },
    },
  },
  {
    number = 4553,
    description = "INSERT - column list completion",
    database = "vim_dadbod_test",
    query = [[INSERT INTO Employees () VALUES (1, 'John', 'Doe')]],
    cursor = { line = 0, col = 22 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "FirstName",
          "LastName",
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4554,
    description = "INSERT - column list with partial",
    database = "vim_dadbod_test",
    query = [[INSERT INTO Employees (EmployeeID, ) VALUES (1, 'John')]],
    cursor = { line = 0, col = 35 },
    expected = {
      type = "column",
      items = {
        includes = {
          "FirstName",
          "LastName",
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4555,
    description = "INSERT - column list with prefix filter",
    database = "vim_dadbod_test",
    query = [[INSERT INTO Employees (First) VALUES ('John')]],
    cursor = { line = 0, col = 28 },
    expected = {
      type = "column",
      items = {
        includes = {
          "FirstName",
        },
      },
    },
  },
  {
    number = 4556,
    description = "INSERT - SELECT column completion",
    database = "vim_dadbod_test",
    query = [[INSERT INTO Employees_Archive SELECT  FROM Employees]],
    cursor = { line = 0, col = 38 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "FirstName",
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4557,
    description = "INSERT - SELECT with explicit columns",
    database = "vim_dadbod_test",
    query = [[INSERT INTO Employees_Archive (ID, Name)
SELECT EmployeeID,  FROM Employees]],
    cursor = { line = 1, col = 19 },
    expected = {
      type = "column",
      items = {
        includes = {
          "FirstName",
          "LastName",
        },
      },
    },
  },
  {
    number = 4558,
    description = "INSERT - EXEC procedure completion",
    database = "vim_dadbod_test",
    query = [[INSERT INTO Employees_Archive EXEC ]],
    cursor = { line = 0, col = 35 },
    expected = {
      type = "procedure",
      items = {
        includes_any = {
          "sp_GetEmployees",
          "usp_GetActiveEmployees",
        },
      },
    },
  },
  {
    number = 4559,
    description = "INSERT - DEFAULT VALUES table",
    database = "vim_dadbod_test",
    query = [[INSERT INTO  DEFAULT VALUES]],
    cursor = { line = 0, col = 12 },
    expected = {
      type = "table",
      items = {
        includes = {
          "Employees",
          "AuditLog",
        },
      },
    },
  },
  {
    number = 4560,
    description = "INSERT - OUTPUT clause columns",
    database = "vim_dadbod_test",
    query = [[INSERT INTO Employees (FirstName, LastName)
OUTPUT inserted.
VALUES ('John', 'Doe')]],
    cursor = { line = 1, col = 16 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "FirstName",
          "LastName",
        },
      },
    },
  },
  {
    number = 4561,
    description = "INSERT - OUTPUT INTO table",
    database = "vim_dadbod_test",
    query = [[INSERT INTO Employees (FirstName)
OUTPUT inserted.EmployeeID INTO ]],
    cursor = { line = 1, col = 32 },
    expected = {
      type = "table",
      items = {
        includes = {
          "InsertLog",
          "#TempIDs",
        },
      },
    },
  },
  {
    number = 4562,
    description = "INSERT - temp table columns",
    database = "vim_dadbod_test",
    query = [[CREATE TABLE #TempEmp (ID INT, Name VARCHAR(100))
INSERT INTO #TempEmp () VALUES (1, 'Test')]],
    cursor = { line = 1, col = 22 },
    expected = {
      type = "column",
      items = {
        includes = {
          "ID",
          "Name",
        },
      },
    },
  },
  {
    number = 4563,
    description = "INSERT - CTE as source",
    database = "vim_dadbod_test",
    query = [[WITH EmpCTE AS (SELECT * FROM Employees WHERE DepartmentID = 1)
INSERT INTO Archive SELECT  FROM EmpCTE]],
    cursor = { line = 1, col = 28 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "FirstName",
        },
      },
    },
  },
  {
    number = 4564,
    description = "INSERT - multirow VALUES column context",
    database = "vim_dadbod_test",
    query = [[INSERT INTO Employees (EmployeeID, FirstName, LastName)
VALUES (1, 'John', 'Doe'),
       (2, 'Jane', 'Smith'),
       (3, , 'Johnson')]],
    cursor = { line = 3, col = 11 },
    expected = {
      -- In VALUES, we don't suggest columns - this should be a literal value
      type = "none",
    },
  },
  {
    number = 4565,
    description = "INSERT - TOP with SELECT",
    database = "vim_dadbod_test",
    query = [[INSERT TOP (100) INTO Archive SELECT  FROM Employees]],
    cursor = { line = 0, col = 38 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "FirstName",
        },
      },
    },
  },
  {
    number = 4566,
    description = "INSERT - schema qualified with brackets",
    database = "vim_dadbod_test",
    query = [[INSERT INTO [dbo].[] (Col1) VALUES (1)]],
    cursor = { line = 0, col = 19 },
    expected = {
      type = "table",
      items = {
        includes = {
          "Employees",
        },
      },
    },
  },
  {
    number = 4567,
    description = "INSERT - cross-database table",
    database = "vim_dadbod_test",
    query = [[INSERT INTO vim_dadbod_second.dbo. SELECT * FROM Employees]],
    cursor = { line = 0, col = 34 },
    expected = {
      type = "table",
      items = {
        includes_any = {
          "Archive",
          "ExtEmployees",
        },
      },
    },
  },
  {
    number = 4568,
    description = "INSERT - identity column excluded suggestion",
    database = "vim_dadbod_test",
    query = [[INSERT INTO Employees () VALUES ('John')]],
    cursor = { line = 0, col = 22 },
    expected = {
      type = "column",
      items = {
        includes = {
          "FirstName",
          "LastName",
        },
        -- IDENTITY columns might be suggested but would error on insert
      },
    },
  },
  {
    number = 4569,
    description = "INSERT - computed column excluded",
    database = "vim_dadbod_test",
    query = [[INSERT INTO EmployeesWithComputed () VALUES (1, 'John')]],
    cursor = { line = 0, col = 35 },
    expected = {
      type = "column",
      items = {
        includes_any = {
          "EmployeeID",
          "FirstName",
        },
        -- Computed columns should ideally be excluded
      },
    },
  },
  {
    number = 4570,
    description = "INSERT - OPENROWSET table hint",
    database = "vim_dadbod_test",
    query = [[INSERT INTO Employees WITH (TABLOCK) ()
VALUES (1, 'John')]],
    cursor = { line = 0, col = 39 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "FirstName",
        },
      },
    },
  },

  -- ============================================================================
  -- 4571-4600: UPDATE statement completion
  -- ============================================================================
  {
    number = 4571,
    description = "UPDATE - table completion after UPDATE",
    database = "vim_dadbod_test",
    query = [[UPDATE ]],
    cursor = { line = 0, col = 7 },
    expected = {
      type = "table",
      items = {
        includes = {
          "Employees",
          "Departments",
        },
      },
    },
  },
  {
    number = 4572,
    description = "UPDATE - schema-qualified table",
    database = "vim_dadbod_test",
    query = [[UPDATE dbo.]],
    cursor = { line = 0, col = 11 },
    expected = {
      type = "table",
      items = {
        includes = {
          "Employees",
          "Departments",
        },
      },
    },
  },
  {
    number = 4573,
    description = "UPDATE - SET column completion",
    database = "vim_dadbod_test",
    query = [[UPDATE Employees SET ]],
    cursor = { line = 0, col = 21 },
    expected = {
      type = "column",
      items = {
        includes = {
          "FirstName",
          "LastName",
          "Salary",
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4574,
    description = "UPDATE - SET column with prefix",
    database = "vim_dadbod_test",
    query = [[UPDATE Employees SET Sal]],
    cursor = { line = 0, col = 24 },
    expected = {
      type = "column",
      items = {
        includes = {
          "Salary",
        },
      },
    },
  },
  {
    number = 4575,
    description = "UPDATE - multiple SET columns",
    database = "vim_dadbod_test",
    query = [[UPDATE Employees SET FirstName = 'John', ]],
    cursor = { line = 0, col = 41 },
    expected = {
      type = "column",
      items = {
        includes = {
          "LastName",
          "Salary",
        },
      },
    },
  },
  {
    number = 4576,
    description = "UPDATE - SET value column reference",
    database = "vim_dadbod_test",
    query = [[UPDATE Employees SET Salary = Salary * 1.1 + ]],
    cursor = { line = 0, col = 45 },
    expected = {
      type = "column",
      items = {
        includes = {
          "Bonus",
          "Commission",
        },
      },
    },
  },
  {
    number = 4577,
    description = "UPDATE - WHERE clause columns",
    database = "vim_dadbod_test",
    query = [[UPDATE Employees SET Salary = 50000 WHERE ]],
    cursor = { line = 0, col = 42 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "DepartmentID",
          "IsActive",
        },
      },
    },
  },
  {
    number = 4578,
    description = "UPDATE - alias in SET",
    database = "vim_dadbod_test",
    query = [[UPDATE e SET e. = 'New' FROM Employees e]],
    cursor = { line = 0, col = 15 },
    expected = {
      type = "column",
      items = {
        includes = {
          "FirstName",
          "LastName",
        },
      },
    },
  },
  {
    number = 4579,
    description = "UPDATE - FROM clause table",
    database = "vim_dadbod_test",
    query = [[UPDATE e SET e.DepartmentID = d.DepartmentID FROM Employees e JOIN ]],
    cursor = { line = 0, col = 66 },
    expected = {
      type = "table",
      items = {
        includes = {
          "Departments",
        },
      },
    },
  },
  {
    number = 4580,
    description = "UPDATE - FROM join ON clause",
    database = "vim_dadbod_test",
    query = [[UPDATE e SET e.DepartmentID = d.DepartmentID FROM Employees e JOIN Departments d ON e.]],
    cursor = { line = 0, col = 83 },
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4581,
    description = "UPDATE - SET from joined table",
    database = "vim_dadbod_test",
    query = [[UPDATE e SET e.DeptName = d. FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID]],
    cursor = { line = 0, col = 28 },
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentName",
        },
      },
    },
  },
  {
    number = 4582,
    description = "UPDATE - OUTPUT clause",
    database = "vim_dadbod_test",
    query = [[UPDATE Employees SET Salary = Salary * 1.1
OUTPUT deleted., inserted.Salary]],
    cursor = { line = 1, col = 15 },
    expected = {
      type = "column",
      items = {
        includes = {
          "Salary",
          "EmployeeID",
        },
      },
    },
  },
  {
    number = 4583,
    description = "UPDATE - OUTPUT inserted columns",
    database = "vim_dadbod_test",
    query = [[UPDATE Employees SET Salary = Salary * 1.1
OUTPUT deleted.Salary, inserted.]],
    cursor = { line = 1, col = 32 },
    expected = {
      type = "column",
      items = {
        includes = {
          "Salary",
          "EmployeeID",
        },
      },
    },
  },
  {
    number = 4584,
    description = "UPDATE - subquery in SET",
    database = "vim_dadbod_test",
    query = [[UPDATE Employees SET DepartmentID = (SELECT  FROM Departments WHERE DepartmentName = 'IT')]],
    cursor = { line = 0, col = 44 },
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4585,
    description = "UPDATE - CASE in SET",
    database = "vim_dadbod_test",
    query = [[UPDATE Employees SET Status = CASE WHEN  > 100000 THEN 'High' ELSE 'Normal' END]],
    cursor = { line = 0, col = 40 },
    expected = {
      type = "column",
      items = {
        includes = {
          "Salary",
        },
      },
    },
  },
  {
    number = 4586,
    description = "UPDATE - WITH CTE",
    database = "vim_dadbod_test",
    query = [[WITH EmpCTE AS (SELECT * FROM Employees WHERE DepartmentID = 1)
UPDATE EmpCTE SET  = 'Updated']],
    cursor = { line = 1, col = 18 },
    expected = {
      type = "column",
      items = {
        includes = {
          "FirstName",
          "LastName",
        },
      },
    },
  },
  {
    number = 4587,
    description = "UPDATE - temp table",
    database = "vim_dadbod_test",
    query = [[CREATE TABLE #TempEmp (ID INT, Name VARCHAR(100), Salary DECIMAL)
UPDATE #TempEmp SET ]],
    cursor = { line = 1, col = 20 },
    expected = {
      type = "column",
      items = {
        includes = {
          "Name",
          "Salary",
        },
      },
    },
  },
  {
    number = 4588,
    description = "UPDATE - TOP clause",
    database = "vim_dadbod_test",
    query = [[UPDATE TOP (10) Employees SET  = 50000]],
    cursor = { line = 0, col = 31 },
    expected = {
      type = "column",
      items = {
        includes = {
          "Salary",
        },
      },
    },
  },
  {
    number = 4589,
    description = "UPDATE - table variable",
    database = "vim_dadbod_test",
    query = [[DECLARE @Emp TABLE (ID INT, Name VARCHAR(100))
UPDATE @Emp SET ]],
    cursor = { line = 1, col = 16 },
    expected = {
      type = "column",
      items = {
        includes = {
          "Name",
        },
      },
    },
  },
  {
    number = 4590,
    description = "UPDATE - multiline formatting",
    database = "vim_dadbod_test",
    query = [[UPDATE Employees
SET
  FirstName = 'John',
  LastName = 'Doe',
   = 50000
WHERE EmployeeID = 1]],
    cursor = { line = 4, col = 2 },
    expected = {
      type = "column",
      items = {
        includes = {
          "Salary",
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4591,
    description = "UPDATE - computed column excluded from SET",
    database = "vim_dadbod_test",
    query = [[UPDATE EmployeesWithComputed SET ]],
    cursor = { line = 0, col = 34 },
    expected = {
      type = "column",
      items = {
        includes = {
          "FirstName",
          "LastName",
        },
        -- Computed columns cannot be updated
      },
    },
  },
  {
    number = 4592,
    description = "UPDATE - WHERE with subquery",
    database = "vim_dadbod_test",
    query = [[UPDATE Employees SET Salary = Salary * 1.1
WHERE DepartmentID IN (SELECT  FROM Departments WHERE Budget > 100000)]],
    cursor = { line = 1, col = 36 },
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4593,
    description = "UPDATE - SET with scalar function",
    database = "vim_dadbod_test",
    query = [[UPDATE Employees SET FullName = dbo.fn_GetFullName()]],
    cursor = { line = 0, col = 47 },
    expected = {
      type = "column",
      items = {
        includes = {
          "FirstName",
          "LastName",
        },
      },
    },
  },
  {
    number = 4594,
    description = "UPDATE - multiple tables WHERE",
    database = "vim_dadbod_test",
    query = [[UPDATE e
SET e.DeptName = d.DepartmentName
FROM Employees e
JOIN Departments d ON e.DepartmentID = d.DepartmentID
WHERE d.]],
    cursor = { line = 4, col = 8 },
    expected = {
      type = "column",
      items = {
        includes = {
          "IsActive",
          "Budget",
        },
      },
    },
  },
  {
    number = 4595,
    description = "UPDATE - OUTPUT INTO",
    database = "vim_dadbod_test",
    query = [[UPDATE Employees SET Salary = Salary * 1.1
OUTPUT deleted.Salary, inserted.Salary INTO ]],
    cursor = { line = 1, col = 45 },
    expected = {
      type = "table",
      items = {
        includes_any = {
          "SalaryLog",
          "#SalaryChanges",
        },
      },
    },
  },
  {
    number = 4596,
    description = "UPDATE - SET compound assignment",
    database = "vim_dadbod_test",
    query = [[UPDATE Employees SET Salary +=  WHERE EmployeeID = 1]],
    cursor = { line = 0, col = 32 },
    expected = {
      type = "column",
      items = {
        includes = {
          "Bonus",
          "Commission",
        },
      },
    },
  },
  {
    number = 4597,
    description = "UPDATE - WRITE clause for large values",
    database = "vim_dadbod_test",
    query = [[UPDATE Documents SET Content.WRITE() WHERE DocID = 1]],
    cursor = { line = 0, col = 35 },
    expected = {
      -- Inside .WRITE() we need different context
      type = "none",
    },
  },
  {
    number = 4598,
    description = "UPDATE - SET NULL check",
    database = "vim_dadbod_test",
    query = [[UPDATE Employees SET  = NULL WHERE ManagerID IS NULL]],
    cursor = { line = 0, col = 21 },
    expected = {
      type = "column",
      items = {
        includes = {
          "ManagerID",
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4599,
    description = "UPDATE - table hint",
    database = "vim_dadbod_test",
    query = [[UPDATE Employees WITH (ROWLOCK) SET ]],
    cursor = { line = 0, col = 36 },
    expected = {
      type = "column",
      items = {
        includes = {
          "FirstName",
          "Salary",
        },
      },
    },
  },
  {
    number = 4600,
    description = "UPDATE - WHERE CURRENT OF cursor",
    database = "vim_dadbod_test",
    query = [[UPDATE Employees SET  = 'Updated' WHERE CURRENT OF emp_cursor]],
    cursor = { line = 0, col = 21 },
    expected = {
      type = "column",
      items = {
        includes = {
          "FirstName",
          "Status",
        },
      },
    },
  },

  -- ============================================================================
  -- 4601-4630: DELETE statement completion
  -- ============================================================================
  {
    number = 4601,
    description = "DELETE - table completion after DELETE FROM",
    database = "vim_dadbod_test",
    query = [[DELETE FROM ]],
    cursor = { line = 0, col = 12 },
    expected = {
      type = "table",
      items = {
        includes = {
          "Employees",
          "Departments",
        },
      },
    },
  },
  {
    number = 4602,
    description = "DELETE - table completion after DELETE (no FROM)",
    database = "vim_dadbod_test",
    query = [[DELETE ]],
    cursor = { line = 0, col = 7 },
    expected = {
      type = "table",
      items = {
        includes = {
          "Employees",
          "Departments",
        },
      },
    },
  },
  {
    number = 4603,
    description = "DELETE - schema-qualified table",
    database = "vim_dadbod_test",
    query = [[DELETE FROM dbo.]],
    cursor = { line = 0, col = 16 },
    expected = {
      type = "table",
      items = {
        includes = {
          "Employees",
        },
      },
    },
  },
  {
    number = 4604,
    description = "DELETE - WHERE clause columns",
    database = "vim_dadbod_test",
    query = [[DELETE FROM Employees WHERE ]],
    cursor = { line = 0, col = 28 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "DepartmentID",
          "IsActive",
        },
      },
    },
  },
  {
    number = 4605,
    description = "DELETE - WHERE with prefix",
    database = "vim_dadbod_test",
    query = [[DELETE FROM Employees WHERE Emp]],
    cursor = { line = 0, col = 31 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
        },
      },
    },
  },
  {
    number = 4606,
    description = "DELETE - compound WHERE condition",
    database = "vim_dadbod_test",
    query = [[DELETE FROM Employees WHERE DepartmentID = 1 AND ]],
    cursor = { line = 0, col = 49 },
    expected = {
      type = "column",
      items = {
        includes = {
          "IsActive",
          "Salary",
        },
      },
    },
  },
  {
    number = 4607,
    description = "DELETE - alias in WHERE",
    database = "vim_dadbod_test",
    query = [[DELETE e FROM Employees e WHERE e.]],
    cursor = { line = 0, col = 34 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4608,
    description = "DELETE - FROM with JOIN",
    database = "vim_dadbod_test",
    query = [[DELETE e FROM Employees e JOIN ]],
    cursor = { line = 0, col = 31 },
    expected = {
      type = "table",
      items = {
        includes = {
          "Departments",
        },
      },
    },
  },
  {
    number = 4609,
    description = "DELETE - JOIN ON clause",
    database = "vim_dadbod_test",
    query = [[DELETE e FROM Employees e JOIN Departments d ON e.]],
    cursor = { line = 0, col = 49 },
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4610,
    description = "DELETE - WHERE references joined table",
    database = "vim_dadbod_test",
    query = [[DELETE e FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID WHERE d.]],
    cursor = { line = 0, col = 86 },
    expected = {
      type = "column",
      items = {
        includes = {
          "IsActive",
          "Budget",
        },
      },
    },
  },
  {
    number = 4611,
    description = "DELETE - OUTPUT clause",
    database = "vim_dadbod_test",
    query = [[DELETE FROM Employees
OUTPUT deleted.]],
    cursor = { line = 1, col = 15 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "FirstName",
        },
      },
    },
  },
  {
    number = 4612,
    description = "DELETE - OUTPUT INTO",
    database = "vim_dadbod_test",
    query = [[DELETE FROM Employees
OUTPUT deleted.* INTO ]],
    cursor = { line = 1, col = 22 },
    expected = {
      type = "table",
      items = {
        includes_any = {
          "DeleteLog",
          "#Deleted",
        },
      },
    },
  },
  {
    number = 4613,
    description = "DELETE - WITH CTE",
    database = "vim_dadbod_test",
    query = [[WITH ToDelete AS (SELECT * FROM Employees WHERE IsActive = 0)
DELETE FROM ]],
    cursor = { line = 1, col = 12 },
    expected = {
      type = "table",
      items = {
        includes = {
          "ToDelete",
          "Employees",
        },
      },
    },
  },
  {
    number = 4614,
    description = "DELETE - CTE WHERE clause",
    database = "vim_dadbod_test",
    query = [[WITH ToDelete AS (SELECT EmployeeID FROM Employees WHERE IsActive = 0)
DELETE FROM Employees WHERE EmployeeID IN (SELECT  FROM ToDelete)]],
    cursor = { line = 1, col = 56 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
        },
      },
    },
  },
  {
    number = 4615,
    description = "DELETE - temp table",
    database = "vim_dadbod_test",
    query = [[CREATE TABLE #TempEmp (ID INT, Name VARCHAR(100))
DELETE FROM #TempEmp WHERE ]],
    cursor = { line = 1, col = 27 },
    expected = {
      type = "column",
      items = {
        includes = {
          "ID",
          "Name",
        },
      },
    },
  },
  {
    number = 4616,
    description = "DELETE - TOP clause",
    database = "vim_dadbod_test",
    query = [[DELETE TOP (100) FROM Employees WHERE ]],
    cursor = { line = 0, col = 38 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "IsActive",
        },
      },
    },
  },
  {
    number = 4617,
    description = "DELETE - subquery in WHERE",
    database = "vim_dadbod_test",
    query = [[DELETE FROM Employees
WHERE DepartmentID IN (SELECT  FROM Departments WHERE IsActive = 0)]],
    cursor = { line = 1, col = 36 },
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4618,
    description = "DELETE - EXISTS subquery",
    database = "vim_dadbod_test",
    query = [[DELETE FROM Departments d
WHERE NOT EXISTS (SELECT 1 FROM Employees e WHERE e.DepartmentID = d.)]],
    cursor = { line = 1, col = 68 },
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4619,
    description = "DELETE - table variable",
    database = "vim_dadbod_test",
    query = [[DECLARE @Emp TABLE (ID INT, Name VARCHAR(100))
DELETE FROM @Emp WHERE ]],
    cursor = { line = 1, col = 23 },
    expected = {
      type = "column",
      items = {
        includes = {
          "ID",
          "Name",
        },
      },
    },
  },
  {
    number = 4620,
    description = "DELETE - multiline formatting",
    database = "vim_dadbod_test",
    query = [[DELETE FROM Employees
WHERE
  DepartmentID = 1
  AND  IS NULL]],
    cursor = { line = 3, col = 6 },
    expected = {
      type = "column",
      items = {
        includes = {
          "ManagerID",
          "HireDate",
        },
      },
    },
  },
  {
    number = 4621,
    description = "DELETE - TRUNCATE TABLE completion",
    database = "vim_dadbod_test",
    query = [[TRUNCATE TABLE ]],
    cursor = { line = 0, col = 15 },
    expected = {
      type = "table",
      items = {
        includes = {
          "Employees",
          "AuditLog",
        },
      },
    },
  },
  {
    number = 4622,
    description = "DELETE - WHERE CURRENT OF",
    database = "vim_dadbod_test",
    query = [[DELETE FROM Employees WHERE  = 1]],
    cursor = { line = 0, col = 28 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4623,
    description = "DELETE - table hint",
    database = "vim_dadbod_test",
    query = [[DELETE FROM Employees WITH (ROWLOCK) WHERE ]],
    cursor = { line = 0, col = 43 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "IsActive",
        },
      },
    },
  },
  {
    number = 4624,
    description = "DELETE - cross-database",
    database = "vim_dadbod_test",
    query = [[DELETE FROM vim_dadbod_second.dbo.]],
    cursor = { line = 0, col = 34 },
    expected = {
      type = "table",
      items = {
        includes_any = {
          "Archive",
          "LogTable",
        },
      },
    },
  },
  {
    number = 4625,
    description = "DELETE - bracketed identifiers",
    database = "vim_dadbod_test",
    query = [[DELETE FROM [Employees] WHERE [].]],
    cursor = { line = 0, col = 31 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
        },
      },
    },
  },

  -- ============================================================================
  -- 4626-4650: MERGE statement completion
  -- ============================================================================
  {
    number = 4626,
    description = "MERGE - INTO table completion",
    database = "vim_dadbod_test",
    query = [[MERGE INTO ]],
    cursor = { line = 0, col = 11 },
    expected = {
      type = "table",
      items = {
        includes = {
          "Employees",
          "Departments",
        },
      },
    },
  },
  {
    number = 4627,
    description = "MERGE - USING table completion",
    database = "vim_dadbod_test",
    query = [[MERGE INTO Employees AS target
USING ]],
    cursor = { line = 1, col = 6 },
    expected = {
      type = "table",
      items = {
        includes = {
          "Employees_Staging",
          "Employees",
        },
      },
    },
  },
  {
    number = 4628,
    description = "MERGE - USING subquery table",
    database = "vim_dadbod_test",
    query = [[MERGE INTO Employees AS target
USING (SELECT * FROM ) AS source]],
    cursor = { line = 1, col = 21 },
    expected = {
      type = "table",
      items = {
        includes = {
          "Employees_Staging",
        },
      },
    },
  },
  {
    number = 4629,
    description = "MERGE - ON condition target columns",
    database = "vim_dadbod_test",
    query = [[MERGE INTO Employees AS target
USING Employees_Staging AS source
ON target.]],
    cursor = { line = 2, col = 10 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
        },
      },
    },
  },
  {
    number = 4630,
    description = "MERGE - ON condition source columns",
    database = "vim_dadbod_test",
    query = [[MERGE INTO Employees AS target
USING Employees_Staging AS source
ON target.EmployeeID = source.]],
    cursor = { line = 2, col = 30 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
        },
      },
    },
  },
  {
    number = 4631,
    description = "MERGE - WHEN MATCHED UPDATE SET",
    database = "vim_dadbod_test",
    query = [[MERGE INTO Employees AS target
USING Employees_Staging AS source
ON target.EmployeeID = source.EmployeeID
WHEN MATCHED THEN UPDATE SET target. = source.FirstName]],
    cursor = { line = 3, col = 37 },
    expected = {
      type = "column",
      items = {
        includes = {
          "FirstName",
          "LastName",
        },
      },
    },
  },
  {
    number = 4632,
    description = "MERGE - WHEN MATCHED UPDATE source column",
    database = "vim_dadbod_test",
    query = [[MERGE INTO Employees AS target
USING Employees_Staging AS source
ON target.EmployeeID = source.EmployeeID
WHEN MATCHED THEN UPDATE SET target.FirstName = source.]],
    cursor = { line = 3, col = 54 },
    expected = {
      type = "column",
      items = {
        includes = {
          "FirstName",
          "LastName",
        },
      },
    },
  },
  {
    number = 4633,
    description = "MERGE - WHEN NOT MATCHED INSERT columns",
    database = "vim_dadbod_test",
    query = [[MERGE INTO Employees AS target
USING Employees_Staging AS source
ON target.EmployeeID = source.EmployeeID
WHEN NOT MATCHED THEN INSERT () VALUES (source.EmployeeID)]],
    cursor = { line = 3, col = 31 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "FirstName",
        },
      },
    },
  },
  {
    number = 4634,
    description = "MERGE - WHEN NOT MATCHED INSERT VALUES",
    database = "vim_dadbod_test",
    query = [[MERGE INTO Employees AS target
USING Employees_Staging AS source
ON target.EmployeeID = source.EmployeeID
WHEN NOT MATCHED THEN INSERT (EmployeeID, FirstName) VALUES (source.EmployeeID, source.)]],
    cursor = { line = 3, col = 87 },
    expected = {
      type = "column",
      items = {
        includes = {
          "FirstName",
        },
      },
    },
  },
  {
    number = 4635,
    description = "MERGE - WHEN NOT MATCHED BY SOURCE DELETE",
    database = "vim_dadbod_test",
    query = [[MERGE INTO Employees AS target
USING Employees_Staging AS source
ON target.EmployeeID = source.EmployeeID
WHEN MATCHED THEN UPDATE SET target.FirstName = source.FirstName
WHEN NOT MATCHED BY SOURCE AND target. < GETDATE() THEN DELETE]],
    cursor = { line = 4, col = 38 },
    expected = {
      type = "column",
      items = {
        includes = {
          "LastUpdated",
          "HireDate",
        },
      },
    },
  },
  {
    number = 4636,
    description = "MERGE - OUTPUT clause",
    database = "vim_dadbod_test",
    query = [[MERGE INTO Employees AS target
USING Employees_Staging AS source
ON target.EmployeeID = source.EmployeeID
WHEN MATCHED THEN UPDATE SET target.FirstName = source.FirstName
OUTPUT $action, inserted., deleted.EmployeeID]],
    cursor = { line = 4, col = 26 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "FirstName",
        },
      },
    },
  },
  {
    number = 4637,
    description = "MERGE - WITH CTE source",
    database = "vim_dadbod_test",
    query = [[WITH StagingCTE AS (SELECT * FROM Employees_Staging WHERE IsNew = 1)
MERGE INTO Employees AS target
USING  AS source
ON target.EmployeeID = source.EmployeeID]],
    cursor = { line = 2, col = 6 },
    expected = {
      type = "table",
      items = {
        includes = {
          "StagingCTE",
        },
      },
    },
  },
  {
    number = 4638,
    description = "MERGE - complex ON condition",
    database = "vim_dadbod_test",
    query = [[MERGE INTO Employees AS target
USING Employees_Staging AS source
ON target.EmployeeID = source.EmployeeID AND target. = source.DepartmentID]],
    cursor = { line = 2, col = 52 },
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4639,
    description = "MERGE - multiple WHEN clauses",
    database = "vim_dadbod_test",
    query = [[MERGE INTO Employees AS target
USING Employees_Staging AS source
ON target.EmployeeID = source.EmployeeID
WHEN MATCHED AND source.IsDeleted = 1 THEN DELETE
WHEN MATCHED THEN UPDATE SET target. = source.FirstName
WHEN NOT MATCHED THEN INSERT (EmployeeID) VALUES (source.EmployeeID)]],
    cursor = { line = 4, col = 37 },
    expected = {
      type = "column",
      items = {
        includes = {
          "FirstName",
          "LastName",
        },
      },
    },
  },
  {
    number = 4640,
    description = "MERGE - USING derived table columns",
    database = "vim_dadbod_test",
    query = [[MERGE INTO Employees AS target
USING (SELECT EmployeeID AS ID, FirstName AS Name FROM Employees_Staging) AS source
ON target.EmployeeID = source.]],
    cursor = { line = 2, col = 30 },
    expected = {
      type = "column",
      items = {
        includes = {
          "ID",
        },
        excludes = {
          "EmployeeID",
        },
      },
    },
  },
  {
    number = 4641,
    description = "MERGE - temp table as source",
    database = "vim_dadbod_test",
    query = [[CREATE TABLE #Staging (ID INT, Name VARCHAR(100))
MERGE INTO Employees AS target
USING #Staging AS source
ON target.EmployeeID = source.]],
    cursor = { line = 3, col = 30 },
    expected = {
      type = "column",
      items = {
        includes = {
          "ID",
        },
      },
    },
  },
  {
    number = 4642,
    description = "MERGE - table variable as source",
    database = "vim_dadbod_test",
    query = [[DECLARE @Staging TABLE (ID INT, Name VARCHAR(100))
MERGE INTO Employees AS target
USING @Staging AS source
ON target.EmployeeID = source.]],
    cursor = { line = 3, col = 30 },
    expected = {
      type = "column",
      items = {
        includes = {
          "ID",
        },
      },
    },
  },
  {
    number = 4643,
    description = "MERGE - HOLDLOCK hint",
    database = "vim_dadbod_test",
    query = [[MERGE INTO Employees WITH (HOLDLOCK) AS target
USING Employees_Staging AS source
ON target. = source.EmployeeID]],
    cursor = { line = 2, col = 10 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
        },
      },
    },
  },
  {
    number = 4644,
    description = "MERGE - multiline formatting",
    database = "vim_dadbod_test",
    query = [[MERGE INTO Employees AS target
USING Employees_Staging AS source
ON target.EmployeeID = source.EmployeeID
WHEN MATCHED THEN
  UPDATE SET
    target.FirstName = source.FirstName,
    target. = source.LastName]],
    cursor = { line = 6, col = 11 },
    expected = {
      type = "column",
      items = {
        includes = {
          "LastName",
        },
      },
    },
  },
  {
    number = 4645,
    description = "MERGE - OUTPUT INTO table",
    database = "vim_dadbod_test",
    query = [[MERGE INTO Employees AS target
USING Employees_Staging AS source
ON target.EmployeeID = source.EmployeeID
WHEN MATCHED THEN UPDATE SET target.FirstName = source.FirstName
OUTPUT $action, inserted.EmployeeID INTO ]],
    cursor = { line = 4, col = 41 },
    expected = {
      type = "table",
      items = {
        includes_any = {
          "MergeLog",
          "#MergeOutput",
        },
      },
    },
  },
  {
    number = 4646,
    description = "MERGE - schema-qualified tables",
    database = "vim_dadbod_test",
    query = [[MERGE INTO dbo.Employees AS target
USING staging. AS source
ON target.EmployeeID = source.EmployeeID]],
    cursor = { line = 1, col = 14 },
    expected = {
      type = "table",
      items = {
        includes_any = {
          "Employees_Staging",
          "StagingTable",
        },
      },
    },
  },
  {
    number = 4647,
    description = "MERGE - cross-database",
    database = "vim_dadbod_test",
    query = [[MERGE INTO vim_dadbod_test.dbo.Employees AS target
USING vim_dadbod_second.dbo. AS source
ON target.EmployeeID = source.EmployeeID]],
    cursor = { line = 1, col = 28 },
    expected = {
      type = "table",
      items = {
        includes_any = {
          "Employees_Staging",
          "ExtEmployees",
        },
      },
    },
  },
  {
    number = 4648,
    description = "MERGE - DEFAULT VALUES in INSERT",
    database = "vim_dadbod_test",
    query = [[MERGE INTO Employees AS target
USING Employees_Staging AS source
ON target.EmployeeID = source.EmployeeID
WHEN NOT MATCHED THEN INSERT (EmployeeID, , LastName) VALUES (source.EmployeeID, DEFAULT, source.LastName)]],
    cursor = { line = 3, col = 43 },
    expected = {
      type = "column",
      items = {
        includes = {
          "FirstName",
        },
      },
    },
  },
  {
    number = 4649,
    description = "MERGE - WHEN clause with AND condition",
    database = "vim_dadbod_test",
    query = [[MERGE INTO Employees AS target
USING Employees_Staging AS source
ON target.EmployeeID = source.EmployeeID
WHEN MATCHED AND source. = 1 THEN DELETE]],
    cursor = { line = 3, col = 24 },
    expected = {
      type = "column",
      items = {
        includes = {
          "IsDeleted",
          "IsInactive",
        },
      },
    },
  },
  {
    number = 4650,
    description = "MERGE - complete statement column reference",
    database = "vim_dadbod_test",
    query = [[MERGE INTO Employees AS target
USING Employees_Staging AS source
ON target.EmployeeID = source.EmployeeID
WHEN MATCHED THEN
  UPDATE SET
    target.FirstName = source.FirstName,
    target.LastName = source.LastName,
    target.Salary = source.Salary,
    target.DepartmentID = source.
WHEN NOT MATCHED THEN
  INSERT (EmployeeID, FirstName, LastName)
  VALUES (source.EmployeeID, source.FirstName, source.LastName)]],
    cursor = { line = 8, col = 32 },
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentID",
        },
      },
    },
  },
}
