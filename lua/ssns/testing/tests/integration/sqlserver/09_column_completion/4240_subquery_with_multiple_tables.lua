-- Test 4240: Subquery with multiple tables

return {
  number = 4240,
  description = "Subquery with multiple tables",
  database = "vim_dadbod_test",
  query = "SELECT * FROM (SELECT e.FirstName, d.DepartmentName FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID) sub WHERE sub.█",
  expected = {
    items = {
      includes = {
        "FirstName",
        "DepartmentName",
      },
    },
    type = "column",
  },
}
