-- Test 4411: CTE - columns from CTE (inherited from source)

return {
  number = 4411,
  description = "CTE - columns from CTE (inherited from source)",
  database = "vim_dadbod_test",
  skip = false,
  query = [[WITH EmpCTE AS (SELECT * FROM Employees)
SELECT █ FROM EmpCTE]],
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "FirstName",
        "LastName",
        "DepartmentID",
      },
    },
    type = "column",
  },
}
