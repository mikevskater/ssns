-- Test 4311: FK suggestion - multiple FKs from same table

return {
  number = 4311,
  description = "FK suggestion - multiple FKs from same table",
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
