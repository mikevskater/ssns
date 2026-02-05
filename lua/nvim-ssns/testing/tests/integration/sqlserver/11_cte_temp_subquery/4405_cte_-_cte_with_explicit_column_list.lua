-- Test 4405: CTE - CTE with explicit column list

return {
  number = 4405,
  description = "CTE - CTE with explicit column list",
  database = "vim_dadbod_test",
  query = [[WITH EmployeeCTE (ID, Name, Dept) AS (SELECT EmployeeID, FirstName, DepartmentID FROM Employees)
SELECT * FROM █]],
  expected = {
    items = {
      includes = {
        "EmployeeCTE",
      },
    },
    type = "table",
  },
}
