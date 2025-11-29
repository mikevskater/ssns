-- Test 4229: INSERT multiline - column list

return {
  number = 4229,
  description = "INSERT multiline - column list",
  database = "vim_dadbod_test",
  query = [[INSERT INTO Employees
  (FirstName,
   █]],
  expected = {
    items = {
      includes = {
        "LastName",
        "DepartmentID",
      },
    },
    type = "column",
  },
}
