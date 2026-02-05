-- Test 4225: INSERT columns - column list

return {
  number = 4225,
  description = "INSERT columns - column list",
  database = "vim_dadbod_test",
  query = "INSERT INTO Employees (█",
  expected = {
    items = {
      includes = {
        "FirstName",
        "LastName",
        "DepartmentID",
      },
    },
    type = "column",
  },
}
