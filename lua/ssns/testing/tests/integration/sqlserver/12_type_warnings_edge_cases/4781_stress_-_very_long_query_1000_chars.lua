-- Test 4781: Stress - very long query (1000+ chars)

return {
  number = 4781,
  description = "Stress - very long query (1000+ chars)",
  database = "vim_dadbod_test",
  query = "SELECT e.EmployeeID, e.FirstName, e.LastName, e.Email, e.HireDate, e.Salary, e.DepartmentID, e.IsActive, d.DepartmentID, d.DepartmentName, d.Budget, d.ManagerID, p.ProjectID, p.ProjectName, p.StartDate, p.EndDate, p.Budget, p.Status FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID JOIN Projects p ON d.DepartmentID █= p.ProjectID WHERE ",
  expected = {
    items = {
      includes_any = {
        "EmployeeID",
        "DepartmentID",
        "ProjectID",
      },
    },
    type = "column",
  },
}
