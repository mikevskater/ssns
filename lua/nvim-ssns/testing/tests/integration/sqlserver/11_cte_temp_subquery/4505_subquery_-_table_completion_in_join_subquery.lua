-- Test 4505: Subquery - table completion in JOIN subquery

return {
  number = 4505,
  description = "Subquery - table completion in JOIN subquery",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN (SELECT * FROM █) sub ON e.DepartmentID = sub.DepartmentID",
  expected = {
    items = {
      includes = {
        "Departments",
      },
    },
    type = "table",
  },
}
