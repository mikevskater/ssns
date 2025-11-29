-- Test 4150: WHERE - BETWEEN operator

return {
  number = 4150,
  description = "WHERE - BETWEEN operator",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees WHERE  █BETWEEN 1 AND 10",
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "Salary",
      },
    },
    type = "column",
  },
}
