-- Test 4328: FK chain - with different JOIN types in chain

return {
  number = 4328,
  description = "FK chain - with different JOIN types in chain",
  database = "vim_dadbod_test",
  query = [[SELECT *
FROM Orders o
INNER JOIN Customers c ON o.CustomerId = c.Id
LEFT JOIN Countries co ON c.CountryID = co.CountryID
RIGHT JOIN █]],
  expected = {
    items = {
      includes = {
        "Regions",
      },
    },
    type = "join_suggestion",
  },
}
