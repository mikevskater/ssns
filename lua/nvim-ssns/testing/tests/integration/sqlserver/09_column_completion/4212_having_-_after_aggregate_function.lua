-- Test 4212: HAVING - after aggregate function

return {
  number = 4212,
  description = "HAVING - after aggregate function",
  database = "vim_dadbod_test",
  query = "SELECT DepartmentID, COUNT(*) FROM Employees GROUP BY DepartmentID HAVING COUNT()█ > 5",
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
