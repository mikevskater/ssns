-- Test 4237: Derived table - JOIN with derived table

return {
  number = 4237,
  description = "Derived table - JOIN with derived table",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN (SELECT DepartmentID, DepartmentName FROM Departments) d ON e.DepartmentID = d.█",
  expected = {
    items = {
      includes = {
        "DepartmentID",
        "DepartmentName",
      },
    },
    type = "column",
  },
}
