-- Test 4436: CTE - CTE with computed column

return {
  number = 4436,
  description = "CTE - CTE with computed column",
  database = "vim_dadbod_test",
  query = [[WITH EmpFull AS (SELECT EmployeeID, FirstName + ' ' + LastName AS FullName FROM Employees)
SELECT █ FROM EmpFull]],
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
