-- Test 4583: UPDATE - OUTPUT inserted columns
-- SKIPPED: OUTPUT clause column completion not yet supported

return {
  number = 4583,
  description = "UPDATE - OUTPUT inserted columns",
  database = "vim_dadbod_test",
  skip = false,
  query = [[UPDATE Employees SET Salary = Salary * 1.1
OUTPUT deleted.Salary, inserted.█]],
  expected = {
    items = {
      includes = {
        "Salary",
        "EmployeeID",
      },
    },
    type = "column",
  },
}
