-- Test 4582: UPDATE - OUTPUT clause
-- SKIPPED: OUTPUT clause column completion not yet supported

return {
  number = 4582,
  description = "UPDATE - OUTPUT clause",
  database = "vim_dadbod_test",
  skip = false,
  query = [[UPDATE Employees SET Salary = Salary * 1.1
OUTPUT deleted.█, inserted.Salary]],
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
