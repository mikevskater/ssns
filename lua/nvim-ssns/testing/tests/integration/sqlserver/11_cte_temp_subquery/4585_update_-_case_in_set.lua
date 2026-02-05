-- Test 4585: UPDATE - CASE in SET

return {
  number = 4585,
  description = "UPDATE - CASE in SET",
  database = "vim_dadbod_test",
  query = "UPDATE Employees SET Status = CASE WHEN █ > 100000 THEN 'High' ELSE 'Normal' END",
  expected = {
    items = {
      includes = {
        "Salary",
      },
    },
    type = "column",
  },
}
