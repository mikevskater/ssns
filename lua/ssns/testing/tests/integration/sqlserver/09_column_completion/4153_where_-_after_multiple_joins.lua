-- Test 4153: WHERE - after multiple JOINs

return {
  number = 4153,
  description = "WHERE - after multiple JOINs",
  database = "vim_dadbod_test",
  query = [[SELECT * FROM Employees e
JOIN Departments d ON e.DepartmentID = d.DepartmentID
JOIN Projects p ON d.DepartmentID = p.DepartmentID
WHERE █]],
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "DepartmentName",
        "ProjectName",
      },
    },
    type = "column",
  },
}
