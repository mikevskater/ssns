-- Test 4219: HAVING - MIN/MAX function

return {
  number = 4219,
  description = "HAVING - MIN/MAX function",
  database = "vim_dadbod_test",
  query = "SELECT DepartmentID FROM Employees GROUP BY DepartmentID HAVING MAX() <█ '2020-01-01'",
  expected = {
    items = {
      includes = {
        "HireDate",
      },
    },
    type = "column",
  },
}
