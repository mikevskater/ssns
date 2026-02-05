-- Test 4446: CTE - CTE with CROSS APPLY

return {
  number = 4446,
  description = "CTE - CTE with CROSS APPLY",
  database = "vim_dadbod_test",
  query = [[WITH DeptCTE AS (SELECT * FROM Departments)
SELECT * FROM DeptCTE d CROSS APPLY (SELECT * FROM Employees e WHERE e.DepartmentID = d.█) x]],
  expected = {
    items = {
      includes = {
        "DepartmentID",
      },
    },
    type = "column",
  },
}
