-- Test 4586: UPDATE - WITH CTE

return {
  number = 4586,
  description = "UPDATE - WITH CTE",
  database = "vim_dadbod_test",
  skip = false,
  query = [[WITH EmpCTE AS (SELECT * FROM Employees WHERE DepartmentID = 1)
UPDATE EmpCTE SET █ = 'Updated']],
  expected = {
    items = {
      includes = {
        "FirstName",
        "LastName",
      },
    },
    type = "column",
  },
}
