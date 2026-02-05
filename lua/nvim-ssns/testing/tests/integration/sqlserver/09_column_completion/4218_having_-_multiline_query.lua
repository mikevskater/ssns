-- Test 4218: HAVING - multiline query

return {
  number = 4218,
  description = "HAVING - multiline query",
  database = "vim_dadbod_test",
  query = [[SELECT DepartmentID, COUNT(*)
FROM Employees
GROUP BY DepartmentID
HAVING █]],
  expected = {
    items = {
      includes = {
        "DepartmentID",
      },
    },
    type = "column",
  },
}
