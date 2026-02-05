-- Test 4324: FK chain - multiline complex join chain

return {
  number = 4324,
  description = "FK chain - multiline complex join chain",
  database = "vim_dadbod_test",
  query = [[SELECT
  o.Id,
  c.Name,
  co.CountryName
FROM Orders o
INNER JOIN Customers c ON o.CustomerId = c.Id
LEFT JOIN Countries co ON c.CountryID = co.CountryID
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
