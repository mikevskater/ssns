-- Test 4397: ON clause - case sensitivity (lowercase)

return {
  number = 4397,
  description = "ON clause - case sensitivity (lowercase)",
  database = "vim_dadbod_test",
  query = "select * from employees e join departments d on e.█",
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "DepartmentID",
      },
    },
    type = "column",
  },
}
