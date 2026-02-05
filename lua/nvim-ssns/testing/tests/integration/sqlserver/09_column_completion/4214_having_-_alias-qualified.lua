-- Test 4214: HAVING - alias-qualified

return {
  number = 4214,
  description = "HAVING - alias-qualified",
  database = "vim_dadbod_test",
  query = "SELECT e.DepartmentID, COUNT(*) FROM Employees e GROUP BY e.DepartmentID HAVING e█.",
  expected = {
    items = {
      includes = {
        "DepartmentID",
      },
    },
    type = "column",
  },
}
