-- Test 4578: UPDATE - alias in SET
-- SKIPPED: Alias-qualified column completion in UPDATE SET not yet supported

return {
  number = 4578,
  description = "UPDATE - alias in SET",
  database = "vim_dadbod_test",
  skip = false,
  query = "UPDATE e SET e.█ = 'New' FROM Employees e",
  expected = {
    items = {
      includes = {
        "FirstName",
        "LastName",
      },
    },
    type = "column",
  },
}
