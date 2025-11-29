-- Test 4779: Error - CTE without SELECT

return {
  number = 4779,
  description = "Error - CTE without SELECT",
  database = "vim_dadbod_test",
  query = "WITH CTE AS (SELECT * FROM Employees)█",
  expected = {
    type = "error",
  },
}
