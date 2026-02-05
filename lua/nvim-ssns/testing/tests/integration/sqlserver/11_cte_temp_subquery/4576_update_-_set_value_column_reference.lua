-- Test 4576: UPDATE - SET value column reference

return {
  number = 4576,
  description = "UPDATE - SET value column reference",
  database = "vim_dadbod_test",
  query = "UPDATE Employees SET Salary = Salary * 1.1 + █",
  expected = {
    items = {
      includes = {
        "DepartmentID",
        "EmployeeID",
      },
    },
    type = "column",
  },
}
