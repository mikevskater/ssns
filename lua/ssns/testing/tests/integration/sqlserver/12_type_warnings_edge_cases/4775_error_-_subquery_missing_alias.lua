-- Test 4775: Error - subquery missing alias

return {
  number = 4775,
  description = "Error - subquery missing alias",
  database = "vim_dadbod_test",
  query = "SELECT * FROM (SELECT * FROM Employees)█",
  expected = {
    type = "error",
  },
}
