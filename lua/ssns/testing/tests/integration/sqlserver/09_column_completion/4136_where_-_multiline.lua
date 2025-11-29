-- Test 4136: WHERE - multiline

return {
  number = 4136,
  description = "WHERE - multiline",
  database = "vim_dadbod_test",
  query = [[SELECT *
FROM Employees
WHERE █]],
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
