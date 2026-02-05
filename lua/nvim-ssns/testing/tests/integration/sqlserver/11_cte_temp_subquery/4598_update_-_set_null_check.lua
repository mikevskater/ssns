-- Test 4598: UPDATE - SET NULL check

return {
  number = 4598,
  description = "UPDATE - SET NULL check",
  database = "vim_dadbod_test",
  query = "UPDATE Employees SET █ = NULL WHERE DepartmentID IS NULL",
  expected = {
    items = {
      includes = {
        "DepartmentID",
        "Salary",
      },
    },
    type = "column",
  },
}
