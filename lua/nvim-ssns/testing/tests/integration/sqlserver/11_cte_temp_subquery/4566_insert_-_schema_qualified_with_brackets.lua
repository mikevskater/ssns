-- Test 4566: INSERT - schema qualified with brackets

return {
  number = 4566,
  description = "INSERT - schema qualified with brackets",
  database = "vim_dadbod_test",
  query = "INSERT INTO [dbo].[█] (Col1) VALUES (1)",
  expected = {
    items = {
      includes = {
        "Employees",
      },
    },
    type = "table",
  },
}
