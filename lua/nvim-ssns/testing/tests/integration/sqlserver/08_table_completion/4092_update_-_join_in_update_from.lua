-- Test 4092: UPDATE - JOIN in UPDATE FROM

return {
  number = 4092,
  description = "UPDATE - JOIN in UPDATE FROM",
  database = "vim_dadbod_test",
  query = "UPDATE e SET Name = 'Test' FROM Employees e JOIN █",
  expected = {
    items = {
      includes = {
        "Departments",
      },
    },
    type = "table",
  },
}
