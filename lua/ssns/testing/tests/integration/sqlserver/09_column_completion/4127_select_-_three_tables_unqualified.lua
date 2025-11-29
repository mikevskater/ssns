-- Test 4127: SELECT - three tables unqualified

return {
  number = 4127,
  description = "SELECT - three tables unqualified",
  database = "vim_dadbod_test",
  query = "SELECT █ FROM Employees, Departments, Projects",
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "DepartmentName",
        "ProjectName",
      },
    },
    type = "column",
  },
}
