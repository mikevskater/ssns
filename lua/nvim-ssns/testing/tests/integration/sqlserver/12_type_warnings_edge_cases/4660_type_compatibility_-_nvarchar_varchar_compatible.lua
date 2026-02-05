-- Test 4660: Type compatibility - nvarchar = varchar (compatible)

return {
  number = 4660,
  description = "Type compatibility - nvarchar = varchar (compatible)",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Departments d ON e.FirstName = d.DepartmentNam█e",
  expected = {
    items = {
      valid = true,
    },
    type = "no_warning",
  },
}
