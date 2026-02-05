-- Test 4622: DELETE - WHERE CURRENT OF

return {
  number = 4622,
  description = "DELETE - WHERE CURRENT OF",
  database = "vim_dadbod_test",
  query = "DELETE FROM Employees WHERE █ = 1",
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
