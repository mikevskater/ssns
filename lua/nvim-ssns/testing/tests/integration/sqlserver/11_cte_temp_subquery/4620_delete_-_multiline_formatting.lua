-- Test 4620: DELETE - multiline formatting

return {
  number = 4620,
  description = "DELETE - multiline formatting",
  database = "vim_dadbod_test",
  query = [[DELETE FROM Employees
WHERE
  DepartmentID = 1
  AND █ IS NULL]],
  expected = {
    items = {
      includes = {
        "DepartmentID",
        "HireDate",
      },
    },
    type = "column",
  },
}
