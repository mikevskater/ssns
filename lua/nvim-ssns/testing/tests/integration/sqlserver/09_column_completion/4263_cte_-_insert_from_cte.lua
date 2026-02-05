-- Test 4263: CTE - INSERT from CTE

return {
  number = 4263,
  description = "CTE - INSERT from CTE",
  database = "vim_dadbod_test",
  query = [[WITH NewEmps AS (SELECT FirstName, LastName FROM Employees WHERE DepartmentID = 1)
INSERT INTO Employees (FirstName, LastName) SELECT █ FROM NewEmps]],
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
