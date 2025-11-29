-- Test 4256: CTE - multiline complex

return {
  number = 4256,
  description = "CTE - multiline complex",
  database = "vim_dadbod_test",
  query = [[WITH EmpCTE AS (
  SELECT
    EmployeeID,
    FirstName,
    LastName
  FROM Employees
  WHERE DepartmentID = 1
)
SELECT
  c.█
FROM EmpCTE c]],
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "FirstName",
        "LastName",
      },
    },
    type = "column",
  },
}
