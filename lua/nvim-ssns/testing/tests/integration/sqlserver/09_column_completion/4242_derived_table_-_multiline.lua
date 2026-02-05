-- Test 4242: Derived table - multiline

return {
  number = 4242,
  description = "Derived table - multiline",
  database = "vim_dadbod_test",
  query = [[SELECT sub.█
FROM (
  SELECT EmployeeID, FirstName
  FROM Employees
) AS sub]],
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "FirstName",
      },
    },
    type = "column",
  },
}
