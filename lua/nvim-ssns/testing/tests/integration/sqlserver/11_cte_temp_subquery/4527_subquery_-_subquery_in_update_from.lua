-- Test 4527: Subquery - subquery in UPDATE FROM
-- SKIPPED: Derived table column completion not yet supported

return {
  number = 4527,
  description = "Subquery - subquery in UPDATE FROM",
  database = "vim_dadbod_test",
  skip = false,
  query = [[UPDATE e SET e.Salary = sub.NewSalary
FROM Employees e
JOIN (SELECT EmployeeID, Salary * 1.1 AS NewSalary FROM Employees WHERE DepartmentID = 1) sub
ON e.EmployeeID = sub.█]],
  expected = {
    items = {
      includes = {
        "EmployeeID",
      },
    },
    type = "column",
  },
}
