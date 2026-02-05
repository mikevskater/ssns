-- Test 4072: JOIN - FK suggestion from Orders (CustomerID, EmployeeID FKs)

return {
  number = 4072,
  description = "JOIN - FK suggestion from Orders (CustomerID, EmployeeID FKs)",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Orders o JOIN █",
  expected = {
    items = {
      includes = {
        "Customers",
        "Employees",
      },
    },
    type = "join_suggestion",
  },
}
