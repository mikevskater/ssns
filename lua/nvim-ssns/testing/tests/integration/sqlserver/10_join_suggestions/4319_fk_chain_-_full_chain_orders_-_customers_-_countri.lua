-- Test 4319: FK chain - full chain Orders -> Customers -> Countries -> Regions

return {
  number = 4319,
  description = "FK chain - full chain Orders -> Customers -> Countries -> Regions",
  database = "vim_dadbod_test",
  query = [[SELECT * FROM Orders o
JOIN Customers c ON o.CustomerId = c.Id
JOIN Countries co ON c.CountryID = co.CountryID
JOIN Regions r ON co.RegionID = r.RegionID
JOIN █]],
  expected = {
    items = {
      includes = {
        "Employees",
        "Departments",
      },
    },
    type = "table",
  },
}
