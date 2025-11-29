-- Test 4226: INSERT columns - second column

return {
  number = 4226,
  description = "INSERT columns - second column",
  database = "vim_dadbod_test",
  query = "INSERT INTO Employees (FirstName, █",
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
