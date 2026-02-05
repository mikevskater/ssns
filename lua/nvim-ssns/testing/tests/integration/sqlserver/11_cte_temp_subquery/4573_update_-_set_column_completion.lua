-- Test 4573: UPDATE - SET column completion

return {
  number = 4573,
  description = "UPDATE - SET column completion",
  database = "vim_dadbod_test",
  query = "UPDATE Employees SET █",
  expected = {
    items = {
      includes = {
        "FirstName",
        "LastName",
        "Salary",
        "DepartmentID",
      },
    },
    type = "column",
  },
}
