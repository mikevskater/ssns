-- Test 4130: SELECT - partial alias match

return {
  number = 4130,
  description = "SELECT - partial alias match",
  database = "vim_dadbod_test",
  query = "SELECT emp.█ FROM Employees emp, Departments dept",
  expected = {
    items = {
      excludes = {
        "DepartmentName",
      },
      includes = {
        "EmployeeID",
        "FirstName",
      },
    },
    type = "column",
  },
}
