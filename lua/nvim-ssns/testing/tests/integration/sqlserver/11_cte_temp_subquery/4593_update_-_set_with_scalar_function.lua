-- Test 4593: UPDATE - SET with scalar function
-- Tests column completion as parameters to scalar function

return {
  number = 4593,
  description = "UPDATE - SET with scalar function",
  database = "vim_dadbod_test",
  skip = false,
  query = "UPDATE Employees SET FullName = dbo.fn_GetFullName(█)",
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
