-- Test 4266: CTE - expression column in CTE

return {
  number = 4266,
  description = "CTE - expression column in CTE",
  database = "vim_dadbod_test",
  query = [[WITH EmpNames AS (SELECT EmployeeID, FirstName + ' ' + LastName AS FullName FROM Employees)
SELECT █ FROM EmpNames]],
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "FullName",
      },
    },
    type = "column",
  },
}
