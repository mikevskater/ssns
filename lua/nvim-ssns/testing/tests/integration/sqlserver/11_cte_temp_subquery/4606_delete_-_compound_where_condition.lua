-- Test 4606: DELETE - compound WHERE condition

return {
  number = 4606,
  description = "DELETE - compound WHERE condition",
  database = "vim_dadbod_test",
  query = "DELETE FROM Employees WHERE DepartmentID = 1 AND █",
  expected = {
    items = {
      includes = {
        "IsActive",
        "Salary",
      },
    },
    type = "column",
  },
}
