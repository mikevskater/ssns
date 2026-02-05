-- Test 4325: FK chain - chain from middle table

return {
  number = 4325,
  description = "FK chain - chain from middle table",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Customers c JOIN █",
  expected = {
    items = {
      includes = {
        "Countries",
        "Orders",
        "Regions",
      },
    },
    type = "join_suggestion",
  },
}
