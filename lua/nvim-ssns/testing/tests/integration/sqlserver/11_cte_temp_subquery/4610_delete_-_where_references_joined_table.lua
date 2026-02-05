-- Test 4610: DELETE - WHERE references joined table

return {
  number = 4610,
  description = "DELETE - WHERE references joined table",
  database = "vim_dadbod_test",
  skip = false,
  query = "DELETE e FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID WHERE d.█",
  expected = {
    items = {
      includes = {
        "DepartmentName",
        "Budget",
      },
    },
    type = "column",
  },
}
