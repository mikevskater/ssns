-- Test 4419: CTE - columns in ON clause with CTE

return {
  number = 4419,
  description = "CTE - columns in ON clause with CTE",
  database = "vim_dadbod_test",
  query = [[WITH EmpCTE AS (SELECT * FROM Employees)
SELECT * FROM EmpCTE e JOIN Departments d ON e.█]],
  expected = {
    items = {
      includes = {
        "DepartmentID",
        "EmployeeID",
      },
    },
    type = "column",
  },
}
