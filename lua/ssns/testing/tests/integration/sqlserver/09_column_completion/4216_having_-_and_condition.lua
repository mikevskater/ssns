-- Test 4216: HAVING - AND condition

return {
  number = 4216,
  description = "HAVING - AND condition",
  database = "vim_dadbod_test",
  query = "SELECT DepartmentID, COUNT(*) FROM Employees GROUP BY DepartmentID HAVING COUNT(*) > 5 AND █",
  expected = {
    items = {
      includes = {
        "DepartmentID",
      },
    },
    type = "column",
  },
}
