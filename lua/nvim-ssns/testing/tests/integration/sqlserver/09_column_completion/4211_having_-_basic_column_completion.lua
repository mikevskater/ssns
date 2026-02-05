-- Test 4211: HAVING - basic column completion

return {
  number = 4211,
  description = "HAVING - basic column completion",
  database = "vim_dadbod_test",
  query = "SELECT DepartmentID, COUNT(*) FROM Employees GROUP BY DepartmentID HAVING █",
  expected = {
    items = {
      includes = {
        "DepartmentID",
      },
    },
    type = "column",
  },
}
