-- Test 4251: CTE - JOIN with CTE

return {
  number = 4251,
  description = "CTE - JOIN with CTE",
  database = "vim_dadbod_test",
  query = [[WITH EmpCTE AS (SELECT EmployeeID, DepartmentID FROM Employees)
SELECT * FROM EmpCTE e JOIN Departments d ON e.DepartmentID = d.█]],
  expected = {
    items = {
      includes = {
        "DepartmentID",
      },
    },
    type = "column",
  },
}
