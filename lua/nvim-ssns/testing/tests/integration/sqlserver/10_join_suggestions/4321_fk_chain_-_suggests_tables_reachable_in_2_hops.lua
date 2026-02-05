-- Test 4321: FK chain - suggests tables reachable in 2 hops

return {
  number = 4321,
  description = "FK chain - suggests tables reachable in 2 hops",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Orders o JOIN █",
  expected = {
    items = {
      includes = {
        "Customers",
        "Employees",
        "Countries",
        "Departments",
      },
    },
    type = "join_suggestion",
  },
}
