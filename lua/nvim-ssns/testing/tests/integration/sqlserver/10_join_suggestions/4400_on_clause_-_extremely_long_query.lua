-- Test 4400: ON clause - extremely long query
-- Updated: Cursor position fixed to after dot

return {
  number = 4400,
  description = "ON clause - extremely long query",
  database = "vim_dadbod_test",
  query = "SELECT e.EmployeeID, e.FirstName, e.LastName, e.Email, e.HireDate, e.Salary, e.IsActive, d.DepartmentID, d.DepartmentName, d.Budget, d.ManagerID FROM Employees e JOIN Departments d ON e.DepartmentID = d.█",
  expected = {
    items = {
      includes = {
        "DepartmentID",
      },
    },
    type = "column",
  },
}
