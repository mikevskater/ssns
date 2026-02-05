-- Test 4069: JOIN - second JOIN in chain

return {
  number = 4069,
  description = "JOIN - second JOIN in chain",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID JO█IN ",
  expected = {
    items = {
      includes = {
        "Projects",
      },
    },
    type = "table",
  },
}
