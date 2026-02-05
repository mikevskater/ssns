-- Test 4611: DELETE - OUTPUT clause
-- SKIPPED: OUTPUT clause column completion not yet supported

return {
  number = 4611,
  description = "DELETE - OUTPUT clause",
  database = "vim_dadbod_test",
  skip = false,
  query = [[DELETE FROM Employees
OUTPUT deleted.█]],
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "FirstName",
      },
    },
    type = "column",
  },
}
