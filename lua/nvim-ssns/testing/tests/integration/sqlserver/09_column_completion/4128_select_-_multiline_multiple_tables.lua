-- Test 4128: SELECT - multiline multiple tables

return {
  number = 4128,
  description = "SELECT - multiline multiple tables",
  database = "vim_dadbod_test",
  query = [[SELECT
  e.EmployeeID,
  d.█
FROM Employees e,
     Departments d]],
  expected = {
    items = {
      includes = {
        "DepartmentID",
        "DepartmentName",
      },
    },
    type = "column",
  },
}
