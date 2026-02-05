-- Test 4579: UPDATE - FROM clause table

return {
  number = 4579,
  description = "UPDATE - FROM clause table",
  database = "vim_dadbod_test",
  query = "UPDATE e SET e.DepartmentID = d.DepartmentID FROM Employees e JOIN █",
  expected = {
    items = {
      includes = {
        "Departments",
      },
    },
    type = "table",
  },
}
