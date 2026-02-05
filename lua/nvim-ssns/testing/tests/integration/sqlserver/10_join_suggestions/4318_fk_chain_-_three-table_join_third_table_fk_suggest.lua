-- Test 4318: FK chain - three-table join, third table FK suggestions

return {
  number = 4318,
  description = "FK chain - three-table join, third table FK suggestions",
  database = "vim_dadbod_test",
  query = [[SELECT *
FROM Orders o
JOIN Customers c ON o.CustomerId = c.Id
JOIN Countries co ON c.CountryID = co.CountryID
JOIN █]],
  expected = {
    items = {
      includes = {
        "Regions",
        "Employees",
      },
    },
    type = "join_suggestion",
  },
}
