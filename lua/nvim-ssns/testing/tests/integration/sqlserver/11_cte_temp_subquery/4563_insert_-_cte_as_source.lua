-- Test 4563: INSERT - CTE as source

return {
  number = 4563,
  description = "INSERT - CTE as source",
  database = "vim_dadbod_test",
  skip = false,
  query = [[WITH EmpCTE AS (SELECT * FROM Employees WHERE DepartmentID = 1)
INSERT INTO Archive SELECT █ FROM EmpCTE]],
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "FirstName",
      },
    },
    type = "column",
  },
}
