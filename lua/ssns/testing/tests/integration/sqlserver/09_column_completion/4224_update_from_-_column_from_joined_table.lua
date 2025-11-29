-- Test 4224: UPDATE FROM - column from joined table

return {
  number = 4224,
  description = "UPDATE FROM - column from joined table",
  database = "vim_dadbod_test",
  query = "UPDATE e SET e.Salary = d.█ FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID",
  expected = {
    items = {
      includes_any = {
        "Budget",
        "DepartmentID",
      },
    },
    type = "column",
  },
}
