-- Test 4742: Complex - UNION with different column counts (error)

return {
  number = 4742,
  description = "Complex - UNION with different column counts (error)",
  database = "vim_dadbod_test",
  query = "SELECT EmployeeID, FirstName FROM Employees UNION SELECT DepartmentID FROM Department█s",
  expected = {
    type = "error",
  },
}
