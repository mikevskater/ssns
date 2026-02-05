-- Test 4230: DELETE WHERE - column completion

return {
  number = 4230,
  description = "DELETE WHERE - column completion",
  database = "vim_dadbod_test",
  query = "DELETE FROM Employees WHERE █",
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "DepartmentID",
      },
    },
    type = "column",
  },
}
