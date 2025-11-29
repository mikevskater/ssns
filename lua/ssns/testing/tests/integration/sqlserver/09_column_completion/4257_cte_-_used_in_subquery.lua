-- Test 4257: CTE - used in subquery

return {
  number = 4257,
  description = "CTE - used in subquery",
  database = "vim_dadbod_test",
  query = [[WITH EmpCTE AS (SELECT EmployeeID, DepartmentID FROM Employees)
SELECT * FROM Departments d WHERE d.DepartmentID IN (SELECT  FR█OM EmpCTE)]],
  expected = {
    items = {
      includes = {
        "DepartmentID",
      },
    },
    type = "column",
  },
}
