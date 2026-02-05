-- Test 4315: FK suggestion - no FK still shows all tables

return {
  number = 4315,
  description = "FK suggestion - no FK still shows all tables",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Regions r JOIN █",
  expected = {
    items = {
      includes = {
        "Employees",
        "Departments",
        "Countries",
      },
    },
    type = "table",
  },
}
