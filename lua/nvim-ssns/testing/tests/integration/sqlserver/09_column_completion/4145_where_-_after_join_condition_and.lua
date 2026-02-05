-- Test 4145: WHERE - after join condition AND

return {
  number = 4145,
  description = "WHERE - after join condition AND",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e, Departments d WHERE e.DepartmentID = d.DepartmentID AND e.█",
  expected = {
    items = {
      includes = {
        "FirstName",
        "Salary",
      },
    },
    type = "column",
  },
}
