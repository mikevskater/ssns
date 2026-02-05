-- Test 4435: CTE - CTE referenced multiple times

return {
  number = 4435,
  description = "CTE - CTE referenced multiple times",
  database = "vim_dadbod_test",
  query = [[WITH EmpCTE AS (SELECT * FROM Employees)
SELECT * FROM EmpCTE e1 JOIN EmpCTE e2 ON e1.DepartmentID = e2.█]],
  expected = {
    items = {
      includes = {
        "EmployeeID",
      },
    },
    type = "column",
  },
}
